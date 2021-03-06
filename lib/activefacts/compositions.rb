require "activefacts/metamodel"
require "activefacts/compositions/version"
require "activefacts/compositions/compositor"

module ActiveFacts
  module Compositions
    def self.compositors
      @@compositors ||= {}
    end

    def self.publish_compositor klass
      compositors[klass.name.sub(/^ActiveFacts::Compositions::/,'').gsub(/::/, '/').downcase] = klass
    end
  end
end
