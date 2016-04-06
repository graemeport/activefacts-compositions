CREATE TABLE Country (
	-- Country surrogate key
	CountryID                               BIGINT IDENTITY NOT NULL,
	-- Country has ISO3166Code3
	ISO3166Code3                            VARCHAR(3) NOT NULL,
	-- Country is called Country Name
	CountryName                             VARCHAR(60) NOT NULL,
	-- Country has ISO3166Code2
	ISO3166Code2                            VARCHAR(2) NOT NULL,
	-- Country has ISO3166Numeric3
	ISO3166Numeric3                         INTEGER NOT NULL,
	-- Primary index to Country
	PRIMARY KEY CLUSTERED(CountryID),
	-- Unique index to Country over PresenceConstraint over (Country Name in "Country is called Country Name") occurs at most one time
	UNIQUE NONCLUSTERED(CountryName),
	-- Unique index to Country over PresenceConstraint over (ISO3166Code2 in "Country has ISO3166Code2") occurs one time
	UNIQUE NONCLUSTERED(ISO3166Code2),
	-- Unique index to Country over PresenceConstraint over (ISO3166Code3 in "Country has ISO3166Code3") occurs at most one time
	UNIQUE NONCLUSTERED(ISO3166Code3),
	-- Unique index to Country over PresenceConstraint over (ISO3166Numeric3 in "Country has ISO3166Numeric3") occurs one time
	UNIQUE NONCLUSTERED(ISO3166Numeric3)
);


