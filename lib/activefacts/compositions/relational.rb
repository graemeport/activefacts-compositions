#
# ActiveFacts Compositions, Relational Compositor.
#
#       Computes an Optimal Normal Form (close to 5NF) relational schema.
#
# Copyright (c) 2015 Clifford Heath. Read the LICENSE file.
#
require "activefacts/compositions"

module ActiveFacts
  module Compositions
    class Relational < Compositor
      MM = ActiveFacts::Metamodel unless const_defined?(:MM)

      def self.options
        {
          surrogates: ['Boolean', "Inject a surrogate key into each table whose primary key is not already suitable as a foreign key"]
        }
      end

      def initialize constellation, name, options = {}
        # Extract recognised options:
        @option_surrogates = options.delete('surrogates')
        super constellation, name, options
      end

      def generate
        super

        trace :relational_details!, "Generating relational composition" do
          # Make a data structure to help in computing the tables
          make_candidates

          # Apply any obvious table/non-table factors
          assign_default_tabulation

          # Figure out how best to absorb things to reduce the number of tables
          optimise_absorption

          # Actually make a Composite object for each table:
          make_composites

          # If a value type has been mapped to a table, add a column to hold its value
          inject_value_fields

          # Inject surrogate keys if the options ask for that
          inject_surrogates if @option_surrogates

          # Remove the un-used absorption paths
          delete_reverse_absorptions

          # Traverse the absorbed objects to build the path to each required column, including foreign keys:
          absorb_all_columns

          devolve_all

          # Populate the target fields of foreign keys
          complete_foreign_keys

          # Remove mappings for objects we have absorbed
          clean_unused_mappings
        end

        trace :relational!, "Full #{self.class.basename} composition" do
          @composition.all_composite.sort_by{|composite| composite.mapping.name}.each do |composite|
            composite.show_trace
          end
        end
      end

      def make_candidates
        @candidates = @binary_mappings.inject({}) do |hash, (absorption, mapping)|
          hash[mapping.object_type] = Candidate.new(self, mapping)
          hash
        end
      end

      def assign_default_tabulation
        trace :relational_defaults!, "Preparing relational composition by setting default assumptions" do
          @candidates.each do |object_type, candidate|
            candidate.assign_default(@composition)
          end
        end
      end

      def optimise_absorption
        trace :relational_optimiser!, "Optimise Relational Composition" do
          undecided = @candidates.keys.select{|object_type| @candidates[object_type].is_tentative}
          pass = 0
          finalised = []
          begin
            pass += 1
            trace :relational_optimiser, "Starting optimisation pass #{pass}" do
              finalised = optimise_absorption_pass(undecided)
            end
            trace :relational_optimiser, "Finalised #{finalised.size} on this pass: #{finalised.map{|f| f.name}*', '}"
            undecided -= finalised
          end while !finalised.empty?
        end
      end

      def optimise_absorption_pass undecided
        undecided.select do |object_type|
          candidate = @candidates[object_type]
          trace :relational_optimiser, "Considering possible status of #{object_type.name}" do

            # Rule 1: Always absorb an objectified unary into its role player (unless its forced to be separate)
            if !object_type.is_separate && (f = object_type.fact_type) && f.all_role.size == 1
              absorbing_ref = candidate.mapping.all_member.detect{|a| a.is_a?(MM::Absorption) and a.child_role.base_role == f.all_role.single}
              raise "REVISIT: Internal error" unless absorbing_ref.parent_role.object_type == object_type
              absorbing_ref = absorbing_ref.flip!
              candidate.full_absorption =
                @constellation.FullAbsorption(composition: @composition, absorption: absorbing_ref, object_type: object_type)
              trace :relational_optimiser, "Fully absorb objectified unary #{object_type.name} into #{f.all_role.single.object_type.name}"
              candidate.definitely_not_table
              next object_type
            end

            # Rule 2: If the preferred_identifier contains one role only, played by an entity type that can absorb us, do that:
            # (Leave pi_roles intact for further use below)
            absorbing_ref = nil
            pi_roles = []
            if object_type.is_a?(MM::EntityType) and              # We're an entity type
              pi_roles = object_type.preferred_identifier_roles and     # Our PI
              pi_roles.size == 1 and                                    # has one role
              single_pi_role = pi_roles[0] and                          # that role is
              single_pi_role.object_type.is_a?(MM::EntityType) and      # played by another Entity Type
              absorbing_ref =
                candidate.mapping.all_member.detect do |absorption|
                  absorption.is_a?(MM::Absorption) && absorption.child_role.base_role == single_pi_role
                end

              absorbing_ref = absorbing_ref.forward_absorption || absorbing_ref.flip!
              candidate.full_absorption =
                @constellation.FullAbsorption(composition: @composition, absorption: absorbing_ref, object_type: object_type)
              trace :relational_optimiser, "EntityType #{single_pi_role.object_type.name} identifies EntityType #{object_type.name}, so fully absorbs it via #{absorbing_ref.inspect}"
              candidate.definitely_not_table
              next object_type
            end

            # Rule 3: If there's more than one absorption path and any functional dependencies that can't absorb us, it's a table
#            trace :relational_optimiser, "From-references for #{object_type.name}(#{pi_roles.map(&:object_type).map(&:name)*', '}) are #{references_from.map(&:inspect)*', '}"
            non_identifying_refs_from =
              candidate.references_from.reject do |member|
                case member
                when MM::Absorption
                  pi_roles.include?(member.child_role.base_role)
                when MM::Indicator
                  pi_roles.include?(member.role)
                else
                  false
                end
              end
            trace :relational_optimiser, "#{object_type.name} has #{non_identifying_refs_from.size} non-identifying functional roles" do
              non_identifying_refs_from.each do |a|
                trace :relational_optimiser, a.inspect
              end
            end

            trace :relational_optimiser, "#{object_type.name} has #{candidate.references_to.size} references to it" do
              candidate.references_to.each do |a|
                trace :relational_optimiser, a.inspect
              end
            end
            if candidate.references_to.size > 1 and       # More than one place wants us
                non_identifying_refs_from.size > 0        # And we carry dependent values so cannot be absorbed
              trace :relational_optimiser, "#{object_type.name} has #{non_identifying_refs_from.size} non-identifying functional dependencies and #{candidate.references_to.size} absorption paths so 3NF requires it be a table"
              candidate.definitely_table
              next object_type
            end

            # At this point, this object either has no functional dependencies or only one place it would be absorbed
            next false if !candidate.is_table   # We can't reduce the number of tables by absorbing this one

            absorption_paths =
              ( non_identifying_refs_from +   # But we should exclude any that are already involved in an absorption; pre-decided ET=>ET or supertype absorption!
                candidate.references_to       # These are our reverse absorptions that could absorb us
              ).select do |a|
                next false unless a.is_a?(MM::Absorption)   # Skip Indicators, we can't be absorbed there
                child_candidate = @candidates[a.child_role.object_type]

                # It's ok if we absorbed them already
                next true if a.full_absorption && child_candidate.full_absorption.absorption != a

                # If our counterpart is a full absorption, don't try to reverse that!
                next false if (a.forward_absorption || a.reverse_absorption).full_absorption

                # Otherwise the other end must already be a table or fully absorbed into one
                next false unless child_candidate.is_table || child_candidate.full_absorption

                next false unless a.child_role.is_unique && a.parent_role.is_unique   # Must be one-to-one

                # next true if pi_roles.size == 1 && pi_roles.include?(a.parent_role) # Allow the sole identifying role for this object
                next false unless a.parent_role.is_mandatory # Don't absorb an object along a non-mandatory role
                true
              end

            trace :relational_optimiser, "#{object_type.name} has #{absorption_paths.size} absorption paths"

            # Rule 4: If this object can be fully absorbed along non-identifying roles, do that (maybe flip some absorptions)
            if absorption_paths.size > 0
              trace :relational_optimiser, "#{object_type.name} is fully absorbed in #{absorption_paths.size} places" do
                absorption_paths.each do |a|
                  a = a.flip! if a.forward_absorption
                  trace :relational_optimiser, "#{object_type.name} is fully absorbed via #{a.inspect}"
                end
              end

              candidate.definitely_not_table
              next object_type
            end

            # Rule 5: If this object has no functional dependencies (only its identifier), it can be absorbed in multiple places
            # We don't create FullAbsorptions, because they're only used to resolve references to this object; and there are none here
            refs_to = candidate.references_to.reject{|a|a.parent_role.base_role.is_identifying}
            if !refs_to.empty? and non_identifying_refs_from.size == 0
              refs_to.map! do |a|
                a = a.flip! if a.reverse_absorption   # We were forward, but the other end must be
                a.forward_absorption
              end
              trace :relational_optimiser, "#{object_type.name} is fully absorbed in #{refs_to.size} places: #{refs_to.map{|ref| ref.inspect}*", "}"
              candidate.definitely_not_table
              next object_type
            end

            false   # Otherwise we failed to make a decision about this object type
          end
        end
      end

      # Remove the unused reverse absorptions:
      def delete_reverse_absorptions
        @binary_mappings.each do |object_type, mapping|
          mapping.all_member.to_a.              # Avoid problems with deletion from all_member
          each do |member|
            next unless member.is_a?(MM::Absorption)
            member.retract if member.forward_absorption # This is the reverse of some absorption
          end
          mapping.re_rank
        end
      end

      # After all table/non-table decisions are made, convert Mappings for tables into Composites and retract the rest:
      def make_composites
        @composites = {}
        @candidates.keys.to_a.each do |object_type|
          candidate = @candidates[object_type]

          if candidate.is_table
            make_composite candidate
          else
            @candidates.delete(object_type)
          end
        end
      end

      def make_composite candidate
        mapping = candidate.mapping
        @composites[mapping.object_type] =
          @constellation.Composite(mapping, composition: @composition)
      end

      # Inject a ValueField for each value type that's a table:
      def inject_value_fields
        @composition.all_composite.each do |composite|
          mapping = composite.mapping
          if mapping.object_type.is_a?(MM::ValueType) and               # Composite needs a ValueField
              !mapping.all_member.detect{|m| m.is_a?(MM::ValueField)}   # And don't already have one
            trace :relational_columns, "Adding value field for #{mapping.object_type.name}"
            @constellation.ValueField(
              :new,
              parent: mapping,
              name: mapping.object_type.name+" Value",
              object_type: mapping.object_type
            )
            mapping.re_rank
          end
        end
      end

      def inject_surrogates
        composites = @composition.all_composite.to_a
        return if composites.empty?

        trace :surrogates, "Injecting any required surrogates" do
          @composition.all_composite.each do |composite|
            next unless needs_surrogate(composite)
            inject_surrogate composite
          end
        end
      end

      def surrogate_type
        @surrogate_type ||= begin
          surrogate_type_name = [true, '', 'true', 'yes', nil].include?(t = @option_surrogates) ? 'Auto Counter' : t
          # REVISIT: Crappy: choose the first (currently always single)
          vocabulary = @composition.all_composite.to_a[0].mapping.object_type.vocabulary
          @constellation.ValueType(
            vocabulary: vocabulary,
            name: surrogate_type_name,
            concept: [:new, :implication_rule => "surrogate injection"]
          )
        end
      end

      def inject_surrogate composite, extension = ' ID'
        trace :surrogates, "Injecting surrogate for #{composite.inspect}" do
          surrogate_component =
            @constellation.SurrogateKey(
              :new,
              parent: composite.mapping,
              name: composite.mapping.name+extension,
              object_type: surrogate_type
            )
          index =
            @constellation.Index(:new, composite: composite, is_unique: true,
              presence_constraint: nil, composite_as_primary_index: composite)
          @constellation.IndexField(access_path: index, ordinal: 0, component: surrogate_component)
          composite.mapping.re_rank
          surrogate_component
        end
      end

      def needs_surrogate(composite)
        object_type = composite.mapping.object_type
        if MM::ValueType === object_type
          trace :surrogates, "#{composite.inspect} is a ValueType that #{object_type.is_auto_assigned ? "is auto-assigned already" : "requires a surrogate" }"
          return !object_type.is_auto_assigned
        end

        non_key_members, key_members = composite.mapping.all_member.reject do |member|
          member.is_a?(MM::Absorption) and member.forward_absorption
        end.partition do |member|
          member.rank_key[0] > MM::Component::RANK_IDENT
        end

        non_fk_surrogate =
          key_members.detect do |member|
            next true unless member.is_a?(MM::Absorption)
            next false if @composites[member.object_type] or @composition.all_full_absorption[member.object_type]       # It's a table or absorbed into one
            true
          end

        if key_members.size > 1
          # Multi-part identifiers are only allowed if:
          # * each part is a foreign key (i.e. it's a join table),
          # * there are no other columns (that might require updating) and
          # * the object is not the target of a foreign key:
          if non_fk_surrogate
            trace :surrogates, "#{composite.inspect} has non-FK identifiers so requires a surrogate"
            return true
          end

          if non_key_members.size > 0
            trace :surrogates, "#{composite.inspect} has non-identifying fields so requires a surrogate"
            return true
          end

          if @candidates[object_type].references_to.size > 0
            trace :surrogates, "#{composite.inspect} is the target of at least one foreign key so requires a surrogate"
            return true
          end

          trace :surrogates, "#{composite.inspect} is a join table that does NOT require a surrogate"
          return false
        end

        # A single-part PK is replaced by a surrogate unless the single part is a surrogate, an FK to a surrogate, or is an Absorbed auto-assigned VT

        key_member = key_members[0]
        if !non_fk_surrogate
          trace :surrogates, "#{composite.inspect} has an identifier that's an FK so does NOT require a surrogate"
          return false
        end

        if key_member.is_a?(MM::SurrogateKey)
          trace :surrogates, "#{composite.inspect} already has an injected SurrogateKey so does NOT require a surrogate"
          return false
        end
        unless key_member.is_a?(MM::Absorption)
          trace :surrogates, "#{composite.inspect} is identified by a non-Absorption so requires a surrogate"
          return true
        end
        if key_member.object_type.is_a?(MM::EntityType)
          trace :surrogates, "#{composite.inspect} is identified by another entity type so requires a surrogate"
          return true
        end
        if key_member.object_type.is_auto_assigned
          trace :surrogates, "#{composite.inspect} already has an auto-assigned key so does NOT require a surrogate"
          return false
        end
        trace :surrogates, "#{composite.inspect} requires a surrogate"
        return true
      end

      #
      # Datetime and recordsource functions defined here because they are used in both Staging and Datavault subclasses
      #
      def inject_datetime_recordsource mapping
        # Add a load DateTime value
        date_field = @constellation.ValidFrom(:new,
          parent: mapping,
          name: "Load"+datestamp_type_name,
          object_type: datestamp_type
        )

        # Add a load DateTime value
        recsrc_field = @constellation.ValueField(:new,
          parent: mapping,
          name: "RecordSource",
          object_type: recordsource_type
        )
        mapping.re_rank
        date_field
      end

      def datestamp_type_name
        @datestamp_type_name ||= begin
          [true, '', 'true', 'yes', nil].include?(t = @option_datestamp) ? 'DateTime' : t
        end
      end

      def datestamp_type
        @datestamp_type ||= begin
          vocabulary = @composition.all_composite.to_a[0].mapping.object_type.vocabulary
          @constellation.ObjectType[[[vocabulary.name], datestamp_type_name]] or
            @constellation.ValueType(
              vocabulary: vocabulary,
              name: datestamp_type_name,
              concept: [:new, :implication_rule => "datestamp injection"]
            )
        end
      end

      def recordsource_type_name
        @recordsource_type_name ||= begin
          [true, '', 'true', 'yes', nil].include?(t = @option_recordsource) ? 'String' : t
        end
      end

      def recordsource_type
        @recordsource_type ||= begin
          vocabulary = @composition.all_composite.to_a[0].mapping.object_type.vocabulary
          @constellation.ObjectType[[[vocabulary.name], recordsource_type_name]] or
            @constellation.ValueType(
              vocabulary: vocabulary,
              name: recordsource_type_name,
              concept: [:new]
            )
        end
      end


      def clean_unused_mappings
        @candidates.keys.to_a.each do |object_type|
          candidate = @candidates[object_type]
          next if candidate.is_table
          mapping = candidate.mapping
          mapping.retract
          @binary_mappings.delete(object_type)
        end
      end

      def is_empty_inheritance mapping
        # Cannot be an empty inheritance unless it's an TypeInheritance absorption
        return false if !mapping.is_a?(MM::Absorption) || !mapping.parent_role.fact_type.is_a?(MM::TypeInheritance)

        # It's empty if it's a TypeInheritance which has no non-empty members
        !mapping.all_member.to_a.any? do |member|
          !is_empty_inheritance(member)
        end
      end

      def elide_empty_inheritance mapping
        mapping.all_member.to_a.each do |member|
          if member.is_a?(MM::Absorption) && member.parent_role.fact_type.is_a?(MM::TypeInheritance)
            elide_empty_inheritance member
            if member.all_member.size == 0
              trace :relational, "Retracting empty inheritance #{member.inspect}"
              member.retract
            end
          end
        end
      end

      # Absorb all items which aren't tables (and keys to those which are) recursively
      def absorb_all_columns
        trace :relational_columns!, "Computing contents of all tables" do
          @composition.all_composite_by_name.each do |composite|
            trace :relational_columns, "Computing contents of #{composite.mapping.name}" do
              absorb_all composite.mapping, composite.mapping
            end
          end
        end
      end

      # This method duplicates part of the absorb_all process,
      # looking for foreign keys from this composite.
      # This must be done in a Data Vault mapping before we decide
      # what will be a hub and what will be a link, and that controls
      # whether we will absorb a foreign key or a copy of the natural
      # key while expanding a table's identifiers.
      # Hub tables never absorb a surrogate FK, only natural keys.
      def enumerate_foreign_keys mapping, from = nil, accumulator = [], path = []
        return if path.include?(mapping)
        path << mapping
        from ||= mapping

        # REVISIT: This corrects some instability (should not actually be order-dependent) but doesn't fix the underlying problem
        mapping.re_rank
        ordered = from.all_member.sort_by(&:ordinal)

        ordered.each do |member|
          # Only consider forward Absorptions:
          next if !member.is_a?(MM::Absorption)
          next if member.forward_absorption

          child_object_type = member.child_role.object_type
          child_mapping = @binary_mappings[child_object_type]
          if child_mapping.composite
            trace :fks, "FK to #{member.child_role.name} in #{member.inspect_reading}"
            accumulator << child_mapping.composite
            next
          end

          full_absorption = child_object_type.all_full_absorption[@composition]
          if full_absorption && full_absorption.absorption.parent_role.fact_type != member.parent_role.fact_type
            begin     # Follow transitive target absorption
              child_object_type = full_absorption.absorption.parent_role.object_type
            end while full_absorption = child_object_type.all_full_absorption[@composition]
            child_mapping = @binary_mappings[child_object_type]
            trace :fks, "FK to #{child_mapping.name} in #{member.inspect_reading} (for fully-absorbed #{member.child_role.name})"
            accumulator << child_mapping.composite
            next
          end

          trace :fks, "Descending all of #{member.child_role.name} in #{member.inspect_reading}" do
            enumerate_foreign_keys member, child_mapping, accumulator, path
          end
        end
        accumulator
      end

      # Overwritten by Staging and Datavault subclasses
      def devolve_all
      end

      #
      # Rename parents functions defined because they are used in both Staging and Datavault subclasses
      #
      def apply_name pattern, name
        pattern.sub(/\+/, name)
      end

      def rename_parents
        @composites.each do |key, composite|
          composite.mapping.name = apply_name(@option_stg_name, composite.mapping.name)
        end
      end

      # This member is an Absorption. Process it recursively, absorbing all its members or just a key
      # depending on whether the absorbed object is a Composite (or absorbed into one) or not.
      def absorb_nested mapping, member, paths
        # Should we absorb a foreign key or the whole contents?

        child_object_type = member.child_role.object_type
        child_mapping = @binary_mappings[child_object_type]
        if child_mapping.composite
          trace :relational_columns?, "Absorbing FK to #{member.child_role.name} in #{member.inspect_reading}" do
            paths[member] = @constellation.ForeignKey(:new, source_composite: mapping.root, composite: child_mapping.composite, absorption: member)
            absorb_key member, child_mapping, paths
            return
          end
        end

        # Is our target object_type fully absorbed (and not through this absorption)?
        full_absorption = child_object_type.all_full_absorption[@composition]
        # We can't use member.full_absorption here, as it's not populated on forked copies
        # if full_absorption && full_absorption != member.full_absorption
        if full_absorption && full_absorption.absorption.parent_role.fact_type != member.parent_role.fact_type

          # REVISIT: This should be done by recursing to absorb_key, not using a loop
          absorption = member   # Retain this for the ForeignKey
          begin     # Follow transitive target absorption
            member = mirror(full_absorption.absorption, member)
            child_object_type = full_absorption.absorption.parent_role.object_type
          end while full_absorption = child_object_type.all_full_absorption[@composition]
          child_mapping = @binary_mappings[child_object_type]

          trace :relational_columns?, "Absorbing FK to #{absorption.child_role.name} (fully absorbed into #{child_object_type.name}) in #{member.inspect_reading}" do
            paths[absorption] = @constellation.ForeignKey(:new, source_composite: mapping.root, composite: child_mapping.composite, absorption: absorption)
            absorb_key member, child_mapping, paths
          end
          return
        end

        trace :relational_columns?, "Absorbing all of #{member.child_role.name} in #{member.inspect_reading}" do
          absorb_all member, child_mapping, paths
        end
      end

      # May be overridden in subclasses
      def prefer_natural_key building_natural_key, source_composite, target_composite
        false
      end

      # Recursively add members to this component for the existential roles of
      # the composite mapping for the absorbed (child_role) object:
      def absorb_key mapping, target, paths
        building_natural_key = paths.detect{|k,i| i.is_a?(MM::Index) && i.composite_as_natural_index}
        prefer_natural = prefer_natural_key(building_natural_key, mapping.root, target.composite)
        prefer_natural = false unless !target.composite || target.composite.primary_index != target.composite.natural_index
        target.re_rank
        target.all_member.sort_by(&:ordinal).each do |member|
          rank = member.rank_key[0]
          next unless rank <= MM::Component::RANK_IDENT
          if rank == MM::Component::RANK_SURROGATE && prefer_natural
            next
          end
          member = member.fork_to_new_parent mapping
          augment_paths paths, member
          if rank == MM::Component::RANK_SURROGATE && !prefer_natural
            break   # Will always be first (higher rank), and usurps others
          elsif member.is_a?(MM::Absorption)
            object_type = member.child_role.object_type
            full_absorption = @composition.all_full_absorption[member.child_role.object_type]
            if full_absorption
              # The target object is fully absorbed. Absorb a key to where it was absorbed
              # We can't recurse here, because we must descend supertype absorptions
              while full_absorption
                trace :relational_columns?, "Absorbing key of fully absorbed #{member.child_role.name}" do
                  member = mirror full_absorption.absorption, member
                  augment_paths paths, member
                  # Descend so the key fields get fully populated
                  absorb_key member, full_absorption.absorption.parent, paths
                  full_absorption = @composition.all_full_absorption[member.child_role.object_type]
                end
              end
            else
              absorb_key member, @binary_mappings[member.child_role.object_type], paths
            end
          end
        end
        # mapping.re_rank
      end

      # Augment the mapping with copies of the children of the "from" mapping.
      # At the top level, no "from" is given and the children already exist
      def absorb_all mapping, from, paths = {}
        top_level = mapping == from

        pcs = []
        newpaths = {}
        if mapping.composite || mapping.full_absorption
          pcs = find_uniqueness_constraints(mapping)

          # Don't build an index from the same PresenceConstraint twice on the same composite (e.g. for a subtype)
          existing_pcs = mapping.root.all_access_path.select{|ap| MM::Index === ap}.map(&:presence_constraint)
          newpaths = make_new_paths mapping, paths.keys+existing_pcs, pcs
        end

        from.re_rank
        ordered = from.all_member.sort_by(&:ordinal)
        ordered.each do |member|
          trace :relational_columns, proc {"#{top_level ? 'Existing' : 'Absorbing'} #{member.inspect}"} do
            unless top_level    # Top-level members are already instantiated
              member = member.fork_to_new_parent mapping
            end
            rel = paths.merge(relevant_paths(newpaths, member))
            augment_paths rel, member

            if member.is_a?(MM::Absorption) && !member.forward_absorption
              # Only forward absorptions here please...
              absorb_nested mapping, member, rel
            end
          end
        end

        newpaths.values.select{|ix| ix.all_index_field.size == 0}.each(&:retract)
      end

      # Find all PresenceConstraints to index the object in this Mapping
      def find_uniqueness_constraints mapping
        return [] unless mapping.object_type.is_a?(MM::EntityType)

        start_roles =
            mapping.
            object_type.
            all_role_transitive.        # Includes objectification roles for objectified fact types
            select do |role|
              (role.is_unique ||                # Must be unique on near role
                role.fact_type.is_unary) &&     # Or be a unary role
              !(role.fact_type.is_a?(MM::TypeInheritance) && role == role.fact_type.supertype_role) # allow roles as subtype
            end.
            map(&:counterpart).         # (Same role if it's a unary)
            compact.                    # Ignore nil counterpart of a role in an n-ary
            map(&:base_role).           # In case it's a link fact type
            uniq

        pcs =
          start_roles.
          flat_map(&:all_role_ref).     # All role_refs
          map(&:role_sequence).         # The role_sequence
          uniq.
          flat_map(&:all_presence_constraint).
          uniq.
          reject do |pc|
            pc.max_frequency != 1 ||    # Must be unique
            pc.enforcement ||           # and alethic
            pc.role_sequence.all_role_ref.detect do |rr|
              !start_roles.include?(rr.role)    # and span only valid roles
            end ||                      # and not be the full absorption path
            (   # Reject a constraint that caused full absorption
              pc.role_sequence.all_role_ref.size == 1 and
              mapping.is_a?(MM::Absorption) and
              fa = mapping.full_absorption and
              pc.role_sequence.all_role_ref.single.role.base_role == fa.absorption.parent_role.base_role
            )
          end  # Alethic uniqueness constraint on far end

        non_absorption_pcs = pcs.reject do |pc|
          # An absorption PC is a PC that covers some role that is involved in a FullAbsorption
          full_absorptions =
            pc.
            role_sequence.
            all_role_ref.
            map(&:role).
            flat_map do |role|
              (role.all_absorption_as_parent_role.to_a + role.all_absorption_as_child_role.to_a).
                select do |abs|
                  abs.full_absorption && abs.full_absorption.composition == @composition
                end
            end
          full_absorptions.size > 0
        end
        pcs = non_absorption_pcs

        trace :relational_paths, "Uniqueness Constraints for #{mapping.object_type.name}" do
          pcs.each do |pc|
            trace :relational_paths, "#{pc.describe.inspect}#{pc.is_preferred_identifier ? ' (PI)' : ''}"
          end
        end

        pcs
      end

      def make_new_paths mapping, existing_pcs, pcs
        newpaths = {}
        new_pcs = pcs-existing_pcs
        trace :relational_paths?, "Adding #{new_pcs.size} new indices for presence constraints on #{mapping.inspect}" do
          new_pcs.each do |pc|
            newpaths[pc] = index = @constellation.Index(:new, composite: mapping.root, is_unique: true, presence_constraint: pc)
            if mapping.object_type.preferred_identifier == pc and
                !@composition.all_full_absorption[mapping.object_type] and
                !mapping.root.natural_index
              mapping.root.natural_index = index
              mapping.root.primary_index ||= index    # Not if we have a surrogate already
            end
            trace :relational_paths, "Added new index #{index.inspect} for #{pc.describe} on #{pc.role_sequence.all_role_ref.map(&:role).map(&:fact_type).map(&:default_reading).inspect}"
          end
        end
        newpaths
      end

      def relevant_paths path_hash, component
        rel = {}  # REVISIT: return a hash subset of path_hash containing paths relevant to this component
        case component
        when MM::Absorption
          role = component.child_role.base_role
        when MM::Indicator
          role = component.role
        else
          return rel  # Can't participate in an AccessPath
        end

        path_hash.each do |pc, path|
          next unless pc.role_sequence.all_role_ref.detect{|rr| rr.role == role}
          rel[pc] = path
        end
        rel
      end

      def augment_paths paths, mapping
        return unless MM::Indicator === mapping || MM::ValueType === mapping.object_type

        if MM::ValueField === mapping && mapping.parent.composite   # ValueType that's a composite (table) by itself
          # This AccessPath has exactly one field and no presence constraint, so just make the index.
          composite = mapping.parent.composite
          paths[nil] =
            index = @constellation.Index(:new, composite: mapping.root, is_unique: true, presence_constraint: nil, composite_as_natural_index: composite)
          composite.primary_index ||= index
        end

        paths.each do |pc, path|
          trace :relational_paths, "Adding #{mapping.inspect} to #{path.inspect}" do
            case path
            when MM::Index
              @constellation.IndexField(access_path: path, ordinal: path.all_index_field.size, component: mapping)
            when MM::ForeignKey
              @constellation.ForeignKeyField(foreign_key: path, ordinal: path.all_foreign_key_field.size, component: mapping)
            end
          end
        end
      end

      def complete_foreign_keys
        trace :relational_paths, "Completing foreign keys" do
          @composition.all_composite.each do |composite|
            composite.all_access_path.each do |path|
              next if MM::Index === path

              next if path.all_foreign_key_field.size == path.all_index_field.size
              target_object_type = path.absorption.child_role.object_type
              while fa = target_object_type.all_full_absorption[@composition]
                target_object_type = fa.absorption.parent_role.object_type
              end
              target = @composites[target_object_type]
              prefer_natural = prefer_natural_key(false, composite, target)
              trace :relational_paths, "Completing #{path.inspect} to #{target.mapping.inspect}"
              index = (prefer_natural && target.natural_index) || target.primary_index
              if index
                index.all_index_field.each do |index_field|
                  @constellation.IndexField access_path: path, ordinal: index_field.ordinal, component: index_field.component
                end
              else
                raise "Foreign key from #{path.source_composite.mapping.name} references target table #{target.mapping.name} which has no primary index"
              end
            end
          end
        end
      end

      # Make a new Absorption in the reverse direction from the one given
      def mirror absorption, parent
        @constellation.fork(
          absorption,
          guid: :new,
          object_type: absorption.parent_role.object_type,
          parent: parent,
          parent_role: absorption.child_role,
          child_role: absorption.parent_role,
          ordinal: 0,
          name: role_name(absorption.parent_role)
        )
      end

      # A candidate is a Mapping of an object type which may become a Composition (a table, in relational-speak)
      class Candidate
        attr_reader :mapping, :is_table, :is_tentative
        attr_accessor :full_absorption

        def initialize compositor, mapping
          @compositor = compositor
          @mapping = mapping
        end

        def object_type
          @mapping.object_type
        end

        # References from us are things we can own (non-Mappings) or have a unique forward absorption for
        def references_from
          @mapping.all_member.select{|m| !m.is_a?(MM::Absorption) or !m.forward_absorption && m.parent_role.is_unique }
        end
        alias_method :rf, :references_from

        # References to us are reverse absorptions where the forward absorption can absorb us
        def references_to
          @mapping.all_member.select{|m| m.is_a?(MM::Absorption) and f = m.forward_absorption and f.parent_role.is_unique}
        end
        alias_method :rt, :references_to

        def has_references
          @mapping.all_member.select{|m| m.is_a?(MM::Absorption) }
        end

        def definitely_not_table
          @is_tentative = @is_table = false
        end

        def definitely_table
          @is_tentative = false
          @is_table = true
        end

        def probably_not_table
          @is_tentative = true
          @is_table = false
        end

        def probably_table
          @is_tentative = @is_table = true
        end

        def assign_default composition
          o = object_type
          if o.is_separate
            trace :relational_defaults, "#{o.name} is a table because it's declared independent or separate"
            definitely_table
            return
          end

          case o
          when MM::ValueType
            if o.is_auto_assigned
              trace :relational_defaults, "#{o.name} is not a table because it is auto assigned"
              definitely_not_table
            elsif references_from.size > 0
              trace :relational_defaults, "#{o.name} is a table because it has references to absorb"
              definitely_table
            else
              trace :relational_defaults, "#{o.name} is not a table because it will be absorbed wherever needed"
              definitely_not_table
            end

          when MM::EntityType
            if references_to.empty? and
                !references_from.detect do |absorption|   # detect whether anything can absorb this entity type
                  absorption.is_a?(MM::Mapping) && absorption.parent_role.is_unique && absorption.child_role.is_unique
                end
              trace :relational_defaults, "#{o.name} is a table because it has nothing to absorb it"
              definitely_table
              return
            end
            if !o.supertypes.empty?
              # We know that this entity type is not a separate or partitioned subtype, so a supertype that can absorb us does
              identifying_fact_type = o.all_type_inheritance_as_subtype.detect{|ti| ti.provides_identification}
              if identifying_fact_type
                fact_type = identifying_fact_type
              else
                if o.all_type_inheritance_as_subtype.size > 1
                  trace :relational_defaults, "REVISIT: #{o.name} cannot be absorbed into a supertype that doesn't also absorb all our other supertypes (or is absorbed into one of its supertypes that does)"
                end
                fact_type = o.all_type_inheritance_as_subtype.to_a[0]
              end

              absorbing_ref = mapping.all_member.detect{|m| m.is_a?(MM::Absorption) && m.child_role.fact_type == fact_type}

              absorbing_ref = absorbing_ref.flip! if absorbing_ref.reverse_absorption   # We were forward, but the other end must be
              absorbing_ref = absorbing_ref.forward_absorption
              self.full_absorption =
                o.constellation.FullAbsorption(composition: composition, absorption: absorbing_ref, object_type: o)
              trace :relational_defaults, "Supertype #{fact_type.supertype_role.name} fully absorbs subtype #{o.name} via #{absorbing_ref.inspect}"
              definitely_not_table
              return
            end # subtype

            # If the preferred_identifier consists of a ValueType that's auto-assigned ON COMMIT (like an SQL sequence),
            # that can only happen in one table, which controls the sequence.
            auto_assigned_identifying_role_player = nil
            pi_role_refs = o.preferred_identifier.role_sequence.all_role_ref
            if pi_role_refs.size == 1 and
                rr = pi_role_refs.single and
                (v = rr.role.object_type).is_a?(MM::ValueType) and
                v.is_auto_assigned == 'commit'
              auto_assigned_identifying_role_player = v
            end
            if (@compositor.options['single_sequence'] || references_to.size > 1) and auto_assigned_identifying_role_player   # Can be absorbed in more than one place
              trace :relational_defaults, "#{o.name} must be a table to support its auto-assigned identifier #{auto_assigned_identifying_role_player.name}"
              definitely_table
              return
            end

            trace :relational_defaults, "#{o.name} is initially presumed to be a table"
            probably_table

          end   # case
        end

      end

    end

    publish_compositor(Relational)
  end
end
