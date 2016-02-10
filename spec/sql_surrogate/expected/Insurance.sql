CREATE TABLE Asset (
	-- Asset has Asset ID
	AssetID                                 int NULL IDENTITY,
	-- maybe Asset is a Vehicle that has VIN
	VehicleVIN                              int NOT NULL,
	-- Has Commercial Registration
	VehicleHasCommercialRegistration        BOOLEAN,
	-- maybe Asset is a Vehicle that is of model-Year and Year has Year Nr
	VehicleModelYearNr                      int NOT NULL,
	-- maybe Asset is a Vehicle that has Registration that has Registration Nr
	VehicleRegistrationNr                   char(8) NOT NULL,
	-- maybe Asset is a Vehicle that is of Vehicle Type that is of Make
	VehicleTypeMake                         varchar NOT NULL,
	-- maybe Asset is a Vehicle that is of Vehicle Type that is of Model
	VehicleTypeModel                        varchar NOT NULL,
	-- maybe Asset is a Vehicle that is of Vehicle Type that maybe has Badge
	VehicleTypeBadge                        varchar NOT NULL,
	-- maybe Asset is a Vehicle that maybe is of Colour
	VehicleColour                           varchar NOT NULL,
	-- maybe Asset is a Vehicle that maybe was sold by Dealer that is a kind of Party that has Party ID
	VehicleDealerID                         int NOT NULL,
	-- maybe Asset is a Vehicle that maybe has Engine Number
	VehicleEngineNumber                     varchar NOT NULL,
	-- maybe Asset is a Vehicle that maybe is subject to finance with Finance Institution that is a kind of Company that is a kind of Party that has Party ID
	VehicleFinanceInstitutionID             int NOT NULL,
	-- Primary index to Asset over PresenceConstraint over (Asset ID in "Asset has Asset ID") occurs at most one time
	PRIMARY KEY CLUSTERED(AssetID)
)
GO
CREATE UNIQUE NONCLUSTERED INDEX AssetByVehicleVIN ON (VehicleVIN) WHERE VehicleVIN IS NOT NULL
GO

CREATE TABLE Claim (
	-- Claim has Claim ID
	ClaimID                                 int NULL IDENTITY,
	-- Claim has p_sequence
	PSequence                               int NULL CHECK((PSequence >= 1 AND PSequence <= 999)),
	-- Policy ID
	PolicyID                                BIGINT IDENTITY NOT NULL,
	-- maybe Claim concerns Incident that relates to loss at Address that is at Street
	IncidentAddressStreet                   varchar(256) NOT NULL,
	-- maybe Claim concerns Incident that relates to loss at Address that is in City
	IncidentAddressCity                     varchar NOT NULL,
	-- maybe Claim concerns Incident that relates to loss at Address that maybe is in Postcode
	IncidentAddressPostcode                 varchar NOT NULL,
	-- State ID
	IncidentAddressStateID                  BIGINT IDENTITY NOT NULL,
	-- maybe Claim concerns Incident that relates to loss on Date Time
	IncidentDateTime                        datetime NOT NULL,
	-- maybe Claim concerns Incident that maybe is covered by Police Report that maybe was to officer-Name
	IncidentOfficerName                     varchar(256) NOT NULL,
	-- maybe Claim concerns Incident that maybe is covered by Police Report that maybe has police-Report Nr
	IncidentPoliceReportNr                  int NOT NULL,
	-- maybe Claim concerns Incident that maybe is covered by Police Report that maybe was on report-Date Time
	IncidentReportDateTime                  datetime NOT NULL,
	-- maybe Claim concerns Incident that maybe is covered by Police Report that maybe was by reporter-Name
	IncidentReporterName                    varchar(256) NOT NULL,
	-- maybe Claim concerns Incident that maybe is covered by Police Report that maybe was at station-Name
	IncidentStationName                     varchar(256) NOT NULL,
	-- maybe Lodgement involves Claim and Lodgement involves Person that is a kind of Party that has Party ID
	LodgementPersonID                       int NOT NULL,
	-- maybe Lodgement involves Claim and maybe Lodgement was made at Date Time
	LodgementDateTime                       datetime NOT NULL,
	-- Primary index to Claim over PresenceConstraint over (Claim ID in "Claim has Claim ID") occurs at most one time
	PRIMARY KEY CLUSTERED(ClaimID),
	-- Unique index to Claim over PresenceConstraint over (Policy, p_sequence in "Claim is on Policy", "Claim has Claim Sequence") occurs at most one time
	UNIQUE NONCLUSTERED(PSequence, PolicyID)
)
GO

CREATE TABLE ContractorAppointment (
	-- Contractor Appointment involves Claim that has Claim ID
	ClaimID                                 int NULL,
	-- Contractor Appointment involves Contractor that is a kind of Company that is a kind of Party that has Party ID
	ContractorID                            int NULL,
	-- Primary index to Contractor Appointment over PresenceConstraint over (Claim, Contractor in "Claim involves Contractor") occurs at most one time
	PRIMARY KEY CLUSTERED(ClaimID, ContractorID),
	FOREIGN KEY (ClaimID) REFERENCES Claim (ClaimID)
)
GO

CREATE TABLE Cover (
	-- Policy ID
	PolicyID                                BIGINT IDENTITY NOT NULL,
	-- Cover Type ID
	CoverTypeID                             BIGINT IDENTITY NOT NULL,
	-- Cover involves Asset that has Asset ID
	AssetID                                 int NULL,
	-- Primary index to Cover over PresenceConstraint over (Policy, Cover Type, Asset in "Policy provides Cover Type over Asset") occurs at most one time
	PRIMARY KEY CLUSTERED(PolicyID, CoverTypeID, AssetID),
	FOREIGN KEY (AssetID) REFERENCES Asset (AssetID)
)
GO

CREATE TABLE CoverType (
	-- Cover Type ID
	CoverTypeID                             BIGINT IDENTITY NOT NULL,
	-- Cover Type has Cover Type Code
	CoverTypeCode                           char NULL,
	-- Cover Type has Cover Type Name
	CoverTypeName                           varchar NULL,
	-- Primary index to Cover Type
	PRIMARY KEY CLUSTERED(CoverTypeID),
	-- Unique index to Cover Type over PresenceConstraint over (Cover Type Code in "Cover Type has Cover Type Code") occurs at most one time
	UNIQUE NONCLUSTERED(CoverTypeCode),
	-- Unique index to Cover Type over PresenceConstraint over (Cover Type Name in "Cover Type has Cover Type Name") occurs at most one time
	UNIQUE NONCLUSTERED(CoverTypeName)
)
GO

CREATE TABLE CoverWording (
	-- Cover Wording ID
	CoverWordingID                          BIGINT IDENTITY NOT NULL,
	-- Cover Type ID
	CoverTypeID                             BIGINT IDENTITY NOT NULL,
	-- Cover Wording involves Policy Wording that has Policy Wording Text
	PolicyWordingText                       varchar NULL,
	-- Cover Wording involves Date
	StartDate                               datetime NULL,
	-- Primary index to Cover Wording
	PRIMARY KEY CLUSTERED(CoverWordingID),
	-- Unique index to Cover Wording over PresenceConstraint over (Cover Type, Policy Wording, Start Date in "Cover Type used Policy Wording from start-Date") occurs at most one time
	UNIQUE NONCLUSTERED(CoverTypeID, PolicyWordingText, StartDate),
	FOREIGN KEY (CoverTypeID) REFERENCES CoverType (CoverTypeID)
)
GO

CREATE TABLE LossType (
	-- Loss Type ID
	LossTypeID                              BIGINT IDENTITY NOT NULL,
	-- Loss Type has Loss Type Code
	LossTypeCode                            char NULL,
	-- Involves Driving
	InvolvesDriving                         BOOLEAN,
	-- Is Single Vehicle Incident
	IsSingleVehicleIncident                 BOOLEAN,
	-- maybe Loss Type implies Liability that has Liability Code
	LiabilityCode                           char(1) NOT NULL CHECK(LiabilityCode = 'D' OR LiabilityCode = 'L' OR LiabilityCode = 'R' OR LiabilityCode = 'U'),
	-- Primary index to Loss Type
	PRIMARY KEY CLUSTERED(LossTypeID),
	-- Unique index to Loss Type over PresenceConstraint over (Loss Type Code in "Loss Type has Loss Type Code") occurs at most one time
	UNIQUE NONCLUSTERED(LossTypeCode)
)
GO

CREATE TABLE LostItem (
	-- Lost Item ID
	LostItemID                              BIGINT IDENTITY NOT NULL,
	-- Lost Item was lost in Incident that is of Claim that has Claim ID
	IncidentClaimID                         int NULL,
	-- Lost Item has Lost Item Nr
	LostItemNr                              int NULL,
	-- Lost Item has Description
	Description                             varchar(1024) NULL,
	-- maybe Lost Item was purchased on purchase-Date
	PurchaseDate                            datetime NOT NULL,
	-- maybe Lost Item was purchased at purchase-Place
	PurchasePlace                           varchar NOT NULL,
	-- maybe Lost Item was purchased for purchase-Price
	PurchasePrice                           decimal(18, 2) NOT NULL,
	-- Primary index to Lost Item
	PRIMARY KEY CLUSTERED(LostItemID),
	-- Unique index to Lost Item over PresenceConstraint over (Incident, Lost Item Nr in "Lost Item was lost in Incident", "Lost Item has Lost Item Nr") occurs at most one time
	UNIQUE NONCLUSTERED(IncidentClaimID, LostItemNr),
	FOREIGN KEY (IncidentClaimID) REFERENCES Claim (ClaimID)
)
GO

CREATE TABLE Party (
	-- Party has Party ID
	PartyID                                 int NULL IDENTITY,
	-- Is A Company
	IsACompany                              BOOLEAN,
	-- maybe Party has postal-Address and Address is at Street
	PostalAddressStreet                     varchar(256) NOT NULL,
	-- maybe Party has postal-Address and Address is in City
	PostalAddressCity                       varchar NOT NULL,
	-- maybe Party has postal-Address and maybe Address is in Postcode
	PostalAddressPostcode                   varchar NOT NULL,
	-- State ID
	PostalAddressStateID                    BIGINT IDENTITY NOT NULL,
	-- maybe Party is a Company that has contact-Person and Person is a kind of Party that has Party ID
	CompanyContactPersonID                  int NOT NULL,
	-- maybe Party is a Person that has Contact Methods that maybe includes business-Phone and Phone has Phone Nr
	PersonBusinessPhoneNr                   varchar NOT NULL,
	-- maybe Party is a Person that has Contact Methods that maybe prefers contact-Time
	PersonContactTime                       datetime NOT NULL,
	-- maybe Party is a Person that has Contact Methods that maybe includes Email
	PersonEmail                             varchar NOT NULL,
	-- maybe Party is a Person that has Contact Methods that maybe includes home-Phone and Phone has Phone Nr
	PersonHomePhoneNr                       varchar NOT NULL,
	-- maybe Party is a Person that has Contact Methods that maybe includes mobile-Phone and Phone has Phone Nr
	PersonMobilePhoneNr                     varchar NOT NULL,
	-- maybe Party is a Person that has Contact Methods that maybe has preferred-Contact Method
	PersonPreferredContactMethod            char(1) NOT NULL CHECK(PersonPreferredContactMethod = 'B' OR PersonPreferredContactMethod = 'H' OR PersonPreferredContactMethod = 'M'),
	-- maybe Party is a Person that has family-Name
	PersonFamilyName                        varchar(256) NOT NULL,
	-- maybe Party is a Person that has given-Name
	PersonGivenName                         varchar(256) NOT NULL,
	-- maybe Party is a Person that has Title
	PersonTitle                             varchar NOT NULL,
	-- maybe Party is a Person that maybe lives at Address that is at Street
	PersonAddressStreet                     varchar(256) NOT NULL,
	-- maybe Party is a Person that maybe lives at Address that is in City
	PersonAddressCity                       varchar NOT NULL,
	-- maybe Party is a Person that maybe lives at Address that maybe is in Postcode
	PersonAddressPostcode                   varchar NOT NULL,
	-- State ID
	PersonAddressStateID                    BIGINT IDENTITY NOT NULL,
	-- maybe Party is a Person that maybe has birth-Date
	PersonBirthDate                         datetime NOT NULL,
	-- Is International
	PersonIsInternational                   BOOLEAN,
	-- maybe Party is a Person that maybe holds License that has License Number
	PersonLicenseNumber                     varchar NOT NULL,
	-- maybe Party is a Person that maybe holds License that is of License Type
	PersonLicenseType                       varchar NOT NULL,
	-- maybe Party is a Person that maybe holds License that maybe was granted in Year that has Year Nr
	PersonYearNr                            int NOT NULL,
	-- maybe Party is a Person that maybe has Occupation
	PersonOccupation                        varchar NOT NULL,
	-- Primary index to Party over PresenceConstraint over (Party ID in "Party has Party ID") occurs at most one time
	PRIMARY KEY CLUSTERED(PartyID),
	FOREIGN KEY (CompanyContactPersonID) REFERENCES Party (PartyID)
)
GO

CREATE TABLE Policy (
	-- Policy ID
	PolicyID                                BIGINT IDENTITY NOT NULL,
	-- Policy was issued in p_year and Year has Year Nr
	PYearNr                                 int NULL,
	-- Product ID
	PProductID                              BIGINT IDENTITY NOT NULL,
	-- State ID
	PStateID                                BIGINT IDENTITY NOT NULL,
	-- Policy has p_serial
	PSerial                                 int NULL CHECK((PSerial >= 1 AND PSerial <= 99999)),
	-- Policy has Application that has Application Nr
	ApplicationNr                           int NULL,
	-- Policy belongs to Insured that is a kind of Party that has Party ID
	InsuredID                               int NULL,
	-- maybe Policy was sold by Authorised Rep that is a kind of Party that has Party ID
	AuthorisedRepID                         int NOT NULL,
	-- maybe Policy has ITC Claimed
	ITCClaimed                              decimal(18, 2) NOT NULL CHECK((ITCClaimed >= 0.0 AND ITCClaimed <= 100.0)),
	-- Primary index to Policy
	PRIMARY KEY CLUSTERED(PolicyID),
	-- Unique index to Policy over PresenceConstraint over (p_year, p_product, p_state, p_serial in "Policy was issued in Year", "Policy is for product having Product", "Policy issued in state having State", "Policy has Policy Serial") occurs at most one time
	UNIQUE NONCLUSTERED(PYearNr, PProductID, PStateID, PSerial),
	FOREIGN KEY (AuthorisedRepID) REFERENCES Party (PartyID),
	FOREIGN KEY (InsuredID) REFERENCES Party (PartyID)
)
GO

CREATE TABLE Product (
	-- Product ID
	ProductID                               BIGINT IDENTITY NOT NULL,
	-- Product has Product Code
	ProductCode                             tinyint NULL CHECK((ProductCode >= 1 AND ProductCode <= 99)),
	-- maybe Product has Alias
	Alias                                   char(3) NOT NULL,
	-- maybe Product has Description
	Description                             varchar(1024) NOT NULL,
	-- Primary index to Product
	PRIMARY KEY CLUSTERED(ProductID),
	-- Unique index to Product over PresenceConstraint over (Product Code in "Product has Product Code") occurs at most one time
	UNIQUE NONCLUSTERED(ProductCode)
)
GO
CREATE UNIQUE NONCLUSTERED INDEX ProductByAlias ON (Alias) WHERE Alias IS NOT NULL
GO

CREATE UNIQUE NONCLUSTERED INDEX ProductByDescription ON (Description) WHERE Description IS NOT NULL
GO

CREATE TABLE PropertyDamage (
	-- Property Damage ID
	PropertyDamageID                        BIGINT IDENTITY NOT NULL,
	-- maybe Property Damage was damaged in Incident that is of Claim that has Claim ID
	IncidentClaimID                         int NOT NULL,
	-- Property Damage is at Address that is at Street
	AddressStreet                           varchar(256) NULL,
	-- Property Damage is at Address that is in City
	AddressCity                             varchar NULL,
	-- Property Damage is at Address that maybe is in Postcode
	AddressPostcode                         varchar NOT NULL,
	-- State ID
	AddressStateID                          BIGINT IDENTITY NOT NULL,
	-- maybe Property Damage belongs to owner-Name
	OwnerName                               varchar(256) NOT NULL,
	-- maybe Property Damage owner has contact Phone that has Phone Nr
	PhoneNr                                 varchar NOT NULL,
	-- Primary index to Property Damage
	PRIMARY KEY CLUSTERED(PropertyDamageID),
	FOREIGN KEY (IncidentClaimID) REFERENCES Claim (ClaimID)
)
GO
CREATE UNIQUE NONCLUSTERED INDEX PropertyDamageByIncidentClaimIDAddressStreetAddressCityAd0ba ON (IncidentClaimID, AddressStreet, AddressCity, AddressPostcode, AddressStateID) WHERE IncidentClaimID IS NOT NULL AND AddressPostcode IS NOT NULL
GO

CREATE TABLE [State] (
	-- State ID
	StateID                                 BIGINT IDENTITY NOT NULL,
	-- State has State Code
	StateCode                               tinyint NULL CHECK((StateCode >= 0 AND StateCode <= 9)),
	-- maybe State has State Name
	StateName                               varchar(256) NOT NULL,
	-- Primary index to State
	PRIMARY KEY CLUSTERED(StateID),
	-- Unique index to State over PresenceConstraint over (State Code in "State has State Code") occurs at most one time
	UNIQUE NONCLUSTERED(StateCode)
)
GO
CREATE UNIQUE NONCLUSTERED INDEX [[State]ByStateName] ON (StateName) WHERE StateName IS NOT NULL
GO

CREATE TABLE ThirdParty (
	-- Third Party ID
	ThirdPartyID                            BIGINT IDENTITY NOT NULL,
	-- Third Party involves Person that is a kind of Party that has Party ID
	PersonID                                int NULL,
	-- Third Party involves Vehicle Incident that is a kind of Incident that is of Claim that has Claim ID
	VehicleIncidentClaimID                  int NULL,
	-- maybe Third Party is insured by Insurer that is a kind of Company that is a kind of Party that has Party ID
	InsurerID                               int NOT NULL,
	-- maybe Third Party vehicle is of model-Year and Year has Year Nr
	ModelYearNr                             int NOT NULL,
	-- maybe Third Party drove vehicle-Registration and Registration has Registration Nr
	VehicleRegistrationNr                   char(8) NOT NULL,
	-- maybe Third Party vehicle is of Vehicle Type that is of Make
	VehicleTypeMake                         varchar NOT NULL,
	-- maybe Third Party vehicle is of Vehicle Type that is of Model
	VehicleTypeModel                        varchar NOT NULL,
	-- maybe Third Party vehicle is of Vehicle Type that maybe has Badge
	VehicleTypeBadge                        varchar NOT NULL,
	-- Primary index to Third Party
	PRIMARY KEY CLUSTERED(ThirdPartyID),
	-- Unique index to Third Party over PresenceConstraint over (Person, Vehicle Incident in "Person was third party in Vehicle Incident") occurs at most one time
	UNIQUE NONCLUSTERED(PersonID, VehicleIncidentClaimID),
	FOREIGN KEY (InsurerID) REFERENCES Party (PartyID),
	FOREIGN KEY (PersonID) REFERENCES Party (PartyID)
)
GO

CREATE TABLE UnderwritingDemerit (
	-- Underwriting Demerit ID
	UnderwritingDemeritID                   BIGINT IDENTITY NOT NULL,
	-- Underwriting Demerit preceded Vehicle Incident that is a kind of Incident that is of Claim that has Claim ID
	VehicleIncidentClaimID                  int NULL,
	-- Underwriting Demerit has Underwriting Question that has Underwriting Question ID
	UnderwritingQuestionID                  int NULL,
	-- maybe Underwriting Demerit occurred occurrence-Count times
	OccurrenceCount                         int NOT NULL,
	-- Primary index to Underwriting Demerit
	PRIMARY KEY CLUSTERED(UnderwritingDemeritID),
	-- Unique index to Underwriting Demerit over PresenceConstraint over (Vehicle Incident, Underwriting Question in "Vehicle Incident occurred despite Underwriting Demerit", "Underwriting Demerit has Underwriting Question") occurs at most one time
	UNIQUE NONCLUSTERED(VehicleIncidentClaimID, UnderwritingQuestionID)
)
GO

CREATE TABLE UnderwritingQuestion (
	-- Underwriting Question has Underwriting Question ID
	UnderwritingQuestionID                  int NULL IDENTITY,
	-- Underwriting Question has Text
	Text                                    varchar NULL,
	-- Primary index to Underwriting Question over PresenceConstraint over (Underwriting Question ID in "Underwriting Question has Underwriting Question ID") occurs at most one time
	PRIMARY KEY CLUSTERED(UnderwritingQuestionID),
	-- Unique index to Underwriting Question over PresenceConstraint over (Text in "Text is of Underwriting Question") occurs at most one time
	UNIQUE NONCLUSTERED(Text)
)
GO

CREATE TABLE VehicleIncident (
	-- Vehicle Incident is a kind of Incident that is of Claim that has Claim ID
	IncidentClaimID                         int NULL,
	-- Occurred While Being Driven
	OccurredWhileBeingDriven                BOOLEAN,
	-- maybe Vehicle Incident has Description
	Description                             varchar(1024) NOT NULL,
	-- maybe Driving involves Vehicle Incident and Driving was by Person that is a kind of Party that has Party ID
	DrivingPersonID                         int NOT NULL,
	-- maybe Driving involves Vehicle Incident and maybe Driving resulted in breath-Test Result
	DrivingBreathTestResult                 varchar NOT NULL,
	-- Is A Warning
	DrivingIsAWarning                       BOOLEAN,
	-- maybe Driving involves Vehicle Incident and maybe Driving Charge involves Driving and Driving Charge involves Charge
	DrivingCharge                           varchar NOT NULL,
	-- maybe Driving involves Vehicle Incident and maybe Hospitalization involves Driving and Hospitalization involves Hospital that has Hospital Name
	DrivingHospitalName                     varchar NOT NULL,
	-- maybe Driving involves Vehicle Incident and maybe Hospitalization involves Driving and maybe Hospitalization resulted in blood-Test Result
	DrivingBloodTestResult                  varchar NOT NULL,
	-- maybe Driving involves Vehicle Incident and maybe Driving followed Intoxication
	DrivingIntoxication                     varchar NOT NULL,
	-- maybe Driving involves Vehicle Incident and maybe Driving was without owners consent for nonconsent-Reason
	DrivingNonconsentReason                 varchar NOT NULL,
	-- maybe Driving involves Vehicle Incident and maybe Driving was unlicenced for unlicensed-Reason
	DrivingUnlicensedReason                 varchar NOT NULL,
	-- Loss Type ID
	LossTypeID                              BIGINT IDENTITY NOT NULL,
	-- maybe Vehicle Incident involved previous_damage-Description
	PreviousDamageDescription               varchar(1024) NOT NULL,
	-- maybe Vehicle Incident was caused by Reason
	Reason                                  varchar NOT NULL,
	-- maybe Vehicle Incident resulted in vehicle being towed to towed-Location
	TowedLocation                           varchar NOT NULL,
	-- maybe Vehicle Incident occurred during weather-Description
	WeatherDescription                      varchar(1024) NOT NULL,
	-- Primary index to Vehicle Incident over PresenceConstraint over (Incident in "Vehicle Incident is a kind of Incident") occurs at most one time
	PRIMARY KEY CLUSTERED(IncidentClaimID),
	FOREIGN KEY (DrivingPersonID) REFERENCES Party (PartyID),
	FOREIGN KEY (IncidentClaimID) REFERENCES Claim (ClaimID),
	FOREIGN KEY (LossTypeID) REFERENCES LossType (LossTypeID)
)
GO

CREATE TABLE Witness (
	-- Witness ID
	WitnessID                               BIGINT IDENTITY NOT NULL,
	-- Witness saw Incident that is of Claim that has Claim ID
	IncidentClaimID                         int NULL,
	-- Witness is called Name
	Name                                    varchar(256) NULL,
	-- maybe Witness lives at Address that is at Street
	AddressStreet                           varchar(256) NOT NULL,
	-- maybe Witness lives at Address that is in City
	AddressCity                             varchar NOT NULL,
	-- maybe Witness lives at Address that maybe is in Postcode
	AddressPostcode                         varchar NOT NULL,
	-- State ID
	AddressStateID                          BIGINT IDENTITY NOT NULL,
	-- maybe Witness has contact-Phone and Phone has Phone Nr
	ContactPhoneNr                          varchar NOT NULL,
	-- Primary index to Witness
	PRIMARY KEY CLUSTERED(WitnessID),
	-- Unique index to Witness over PresenceConstraint over (Incident, Name in "Incident was independently witnessed by Witness", "Witness is called Name") occurs at most one time
	UNIQUE NONCLUSTERED(IncidentClaimID, Name),
	FOREIGN KEY (AddressStateID) REFERENCES [State] (StateID),
	FOREIGN KEY (IncidentClaimID) REFERENCES Claim (ClaimID)
)
GO

ALTER TABLE CoverType
	ADD FOREIGN KEY (CoverTypeID) REFERENCES CoverType (CoverTypeID)
GO

ALTER TABLE Party
	ADD FOREIGN KEY (ContractorID) REFERENCES Party (PartyID)
GO

ALTER TABLE Party
	ADD FOREIGN KEY (LodgementPersonID) REFERENCES Party (PartyID)
GO

ALTER TABLE Party
	ADD FOREIGN KEY (VehicleDealerID) REFERENCES Party (PartyID)
GO

ALTER TABLE Party
	ADD FOREIGN KEY (VehicleFinanceInstitutionID) REFERENCES Party (PartyID)
GO

ALTER TABLE Policy
	ADD FOREIGN KEY (PolicyID) REFERENCES Policy (PolicyID)
GO

ALTER TABLE Policy
	ADD FOREIGN KEY (PolicyID) REFERENCES Policy (PolicyID)
GO

ALTER TABLE Product
	ADD FOREIGN KEY (PProductID) REFERENCES Product (ProductID)
GO

ALTER TABLE UnderwritingQuestion
	ADD FOREIGN KEY (UnderwritingQuestionID) REFERENCES UnderwritingQuestion (UnderwritingQuestionID)
GO

ALTER TABLE VehicleIncident
	ADD FOREIGN KEY (VehicleIncidentClaimID) REFERENCES VehicleIncident (IncidentClaimID)
GO

ALTER TABLE VehicleIncident
	ADD FOREIGN KEY (VehicleIncidentClaimID) REFERENCES VehicleIncident (IncidentClaimID)
GO

ALTER TABLE [State]
	ADD FOREIGN KEY (AddressStateID) REFERENCES [State] (StateID)
GO

ALTER TABLE [State]
	ADD FOREIGN KEY (IncidentAddressStateID) REFERENCES [State] (StateID)
GO

ALTER TABLE [State]
	ADD FOREIGN KEY (PStateID) REFERENCES [State] (StateID)
GO

ALTER TABLE [State]
	ADD FOREIGN KEY (PersonAddressStateID) REFERENCES [State] (StateID)
GO

ALTER TABLE [State]
	ADD FOREIGN KEY (PostalAddressStateID) REFERENCES [State] (StateID)
GO
