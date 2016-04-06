CREATE TABLE AcceptableSubstitution (
	-- Acceptable Substitution surrogate key
	AcceptableSubstitutionID                BIGINT IDENTITY NOT NULL,
	-- Acceptable Substitution involves Product
	ProductID                               BIGINT NOT NULL,
	-- Acceptable Substitution involves alternate-Product
	AlternateProductID                      BIGINT NOT NULL,
	-- Acceptable Substitution involves Season
	Season                                  VARCHAR(6) NOT NULL CHECK(Season = 'Autumn' OR Season = 'Spring' OR Season = 'Summer' OR Season = 'Winter'),
	-- Primary index to Acceptable Substitution
	PRIMARY KEY CLUSTERED(AcceptableSubstitutionID),
	-- Unique index to Acceptable Substitution over PresenceConstraint over (Product, Alternate Product, Season in "Product may be substituted by alternate-Product in Season") occurs at most one time
	UNIQUE NONCLUSTERED(ProductID, AlternateProductID, Season)
);


CREATE TABLE [Month] (
	-- Month surrogate key
	MonthID                                 BIGINT IDENTITY NOT NULL,
	-- Month has Month Nr
	MonthNr                                 INTEGER NOT NULL CHECK((MonthNr >= 1 AND MonthNr <= 12)),
	-- Month is in Season
	Season                                  VARCHAR(6) NOT NULL CHECK(Season = 'Autumn' OR Season = 'Spring' OR Season = 'Summer' OR Season = 'Winter'),
	-- Primary index to Month
	PRIMARY KEY CLUSTERED(MonthID),
	-- Unique index to Month over PresenceConstraint over (Month Nr in "Month has Month Nr") occurs at most one time
	UNIQUE NONCLUSTERED(MonthNr)
);


CREATE TABLE Product (
	-- Product surrogate key
	ProductID                               BIGINT IDENTITY NOT NULL,
	-- Product has Product Name
	ProductName                             VARCHAR NOT NULL,
	-- Primary index to Product
	PRIMARY KEY CLUSTERED(ProductID),
	-- Unique index to Product over PresenceConstraint over (Product Name in "Product has Product Name") occurs at most one time
	UNIQUE NONCLUSTERED(ProductName)
);


CREATE TABLE ProductionForecast (
	-- Production Forecast surrogate key
	ProductionForecastID                    BIGINT IDENTITY NOT NULL,
	-- Production Forecast involves Refinery
	RefineryID                              BIGINT NOT NULL,
	-- Production Forecast involves Supply Period
	SupplyPeriodID                          BIGINT NOT NULL,
	-- Production Forecast involves Product
	ProductID                               BIGINT NOT NULL,
	-- Production Forecast involves Quantity
	Quantity                                INTEGER NOT NULL,
	-- maybe Production Forecast predicts Cost
	Cost                                    DECIMAL NULL,
	-- Primary index to Production Forecast
	PRIMARY KEY CLUSTERED(ProductionForecastID),
	-- Unique index to Production Forecast over PresenceConstraint over (Refinery, Supply Period, Product in "Refinery in Supply Period will make Product in Quantity") occurs one time
	UNIQUE NONCLUSTERED(RefineryID, SupplyPeriodID, ProductID),
	FOREIGN KEY (ProductID) REFERENCES Product (ProductID)
);


CREATE TABLE Refinery (
	-- Refinery surrogate key
	RefineryID                              BIGINT IDENTITY NOT NULL,
	-- Refinery has Refinery Name
	RefineryName                            VARCHAR(80) NOT NULL,
	-- Primary index to Refinery
	PRIMARY KEY CLUSTERED(RefineryID),
	-- Unique index to Refinery over PresenceConstraint over (Refinery Name in "Refinery has Refinery Name") occurs at most one time
	UNIQUE NONCLUSTERED(RefineryName)
);


CREATE TABLE Region (
	-- Region surrogate key
	RegionID                                BIGINT IDENTITY NOT NULL,
	-- Region has Region Name
	RegionName                              VARCHAR NOT NULL,
	-- Primary index to Region
	PRIMARY KEY CLUSTERED(RegionID),
	-- Unique index to Region over PresenceConstraint over (Region Name in "Region has Region Name") occurs at most one time
	UNIQUE NONCLUSTERED(RegionName)
);


CREATE TABLE RegionalDemand (
	-- Regional Demand surrogate key
	RegionalDemandID                        BIGINT IDENTITY NOT NULL,
	-- Regional Demand involves Region
	RegionID                                BIGINT NOT NULL,
	-- Regional Demand involves Supply Period
	SupplyPeriodID                          BIGINT NOT NULL,
	-- Regional Demand involves Product
	ProductID                               BIGINT NOT NULL,
	-- Regional Demand involves Quantity
	Quantity                                INTEGER NOT NULL,
	-- Primary index to Regional Demand
	PRIMARY KEY CLUSTERED(RegionalDemandID),
	-- Unique index to Regional Demand over PresenceConstraint over (Region, Supply Period, Product in "Region in Supply Period will need Product in Quantity") occurs one time
	UNIQUE NONCLUSTERED(RegionID, SupplyPeriodID, ProductID),
	FOREIGN KEY (ProductID) REFERENCES Product (ProductID),
	FOREIGN KEY (RegionID) REFERENCES Region (RegionID)
);


CREATE TABLE SupplyPeriod (
	-- Supply Period surrogate key
	SupplyPeriodID                          BIGINT IDENTITY NOT NULL,
	-- Supply Period is in Year that has Year Nr
	YearNr                                  INTEGER NOT NULL,
	-- Supply Period is in Month
	MonthID                                 BIGINT NOT NULL,
	-- Primary index to Supply Period
	PRIMARY KEY CLUSTERED(SupplyPeriodID),
	-- Unique index to Supply Period over PresenceConstraint over (Year, Month in "Supply Period is in Year", "Supply Period is in Month") occurs at most one time
	UNIQUE NONCLUSTERED(YearNr, MonthID),
	FOREIGN KEY (MonthID) REFERENCES [Month] (MonthID)
);


CREATE TABLE TransportRoute (
	-- Transport Route surrogate key
	TransportRouteID                        BIGINT IDENTITY NOT NULL,
	-- Transport Route involves Transport Method
	TransportMethod                         VARCHAR NOT NULL CHECK(TransportMethod = 'Rail' OR TransportMethod = 'Road' OR TransportMethod = 'Sea'),
	-- Transport Route involves Refinery
	RefineryID                              BIGINT NOT NULL,
	-- Transport Route involves Region
	RegionID                                BIGINT NOT NULL,
	-- maybe Transport Route incurs Cost per kl
	Cost                                    DECIMAL NULL,
	-- Primary index to Transport Route
	PRIMARY KEY CLUSTERED(TransportRouteID),
	-- Unique index to Transport Route over PresenceConstraint over (Transport Method, Refinery, Region in "Transport Method transportation is available from Refinery to Region") occurs at most one time
	UNIQUE NONCLUSTERED(TransportMethod, RefineryID, RegionID),
	FOREIGN KEY (RefineryID) REFERENCES Refinery (RefineryID),
	FOREIGN KEY (RegionID) REFERENCES Region (RegionID)
);


ALTER TABLE AcceptableSubstitution
	ADD FOREIGN KEY (AlternateProductID) REFERENCES Product (ProductID);


ALTER TABLE AcceptableSubstitution
	ADD FOREIGN KEY (ProductID) REFERENCES Product (ProductID);


ALTER TABLE ProductionForecast
	ADD FOREIGN KEY (RefineryID) REFERENCES Refinery (RefineryID);


ALTER TABLE ProductionForecast
	ADD FOREIGN KEY (SupplyPeriodID) REFERENCES SupplyPeriod (SupplyPeriodID);


ALTER TABLE RegionalDemand
	ADD FOREIGN KEY (SupplyPeriodID) REFERENCES SupplyPeriod (SupplyPeriodID);

