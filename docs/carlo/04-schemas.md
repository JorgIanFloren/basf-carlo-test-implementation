# Component schemas — `PolytraSeafreightHouseShipment_BASF` v3

Every nested object type reachable from [`seaHouseShipment`](02-seahouseshipment.md) or
[`shipmentCargo`](03-shipmentcargo.md). Generated from
`/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json`.

`actionAttribute` is omitted from every table — it is present on all of these types and means the
same thing everywhere; see [§ actionAttribute](01-calling-the-api.md#actionattribute).

**Req** marks a field the contract declares required *for that object*, which only bites when the
object itself is present. **Max** is `maxLength`; a `0` there is the swagger's way of saying the
property is generated and not writable.

`changedByAPI` (`boolean`, description `-`) appears on
[`ShipmentCargo`](#shipmentcargo), [`ShipmentCargoDangerousGoodsData`](#shipmentcargodangerousgoodsdata)
and [`ShipmentContainer`](#shipmentcontainer) in v3 and on no other schema. It is absent from v4
(see [07-contract-conformance.md § v3 versus v4](07-contract-conformance.md#v3-versus-v4)), so
treat it as a server-side flag rather than something an integration sets — none of the three
mappings writes it.

Fields typed `number` below are declared `type: object` with no properties in the swagger. They
are CarLo quantities and go on the wire as **plain JSON numbers** — see
[§ Quantities](01-calling-the-api.md#quantities).

---

## AddressWithAppendix

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `location1` | `string` |  | 70 |  |
| `location2` | `string` |  | 70 |  |
| `zipCode` | `string` |  | 10 |  |
| `street` | `string` |  | 60 |  |
| `houseNumber` | `string` |  | 10 |  |
| `country` | [`Country`](04-schemas.md#country) |  |  |  |
| `appendix` | `string` |  | 35 |  |
| `geoCoord` | `string` |  | 0 *(unused)* |  |
| `state` | `string` |  | 10 |  |


## AirAndSeaContingentContract

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `contractID` | `string` | yes | 10 | The match code. |
| `contractName` | `string` | yes | 255 | The designation. |


## Article

Artikel sind jede Art von Gütern die aufgrund ihrer Beschaffenheit zum Handel, Transport und zur Lagerung geeignet sind.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `articleID` | `string` |  | 10 |  |
| `articleName` | `string` |  | 30 |  |


## AutomatedManifestSystemFilingDocument

AMS filing, also referred to as "Automated Manifest System filing", is a document that is presented to US customs. It contains a description of all goods with that destination.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `billOfLadingNumber` | `string` |  | 200 | The bill of lading number for AMS purpose only. |


## BLRecipients

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `recipientNumber` | `integer` |  |  |  |
| `bLType` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `company` | `string` |  | 255 |  |
| `copies` | `integer` |  |  |  |
| `country` | [`Country`](04-schemas.md#country) |  |  |  |
| `email` | `string` |  | 255 |  |
| `name` | `string` |  | 255 |  |
| `originals` | `integer` |  |  |  |


## BusinessPartner

Hiermit können Geschäftspartner angelegt werden. Dies können z. B. Kunden, Unternehmer oder Lieferanten sein. Wie diese im System verwendet werden sollen, legen Sie über den Typ fest.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `businessPartnerId` | `integer` |  |  |  |
| `externalNumber` | `string` |  | 20 |  |
| `matchcode` | `string` |  |  |  |
| `globalLocationNumber` | `string` |  | 50 | Global Location Number. Schnittstellen können anhand dieser Nummer einen Geschäftspartner identifizieren und zuordnen. |
| `name1` | `string` |  | 40 |  |
| `name2` | `string` |  | 40 |  |
| `name3` | `string` |  | 40 |  |
| `name4` | `string` |  | 40 |  |
| `phoneNumberHeadOffice` | `string` |  | 30 |  |
| `contactPerson` | array of [`ContactPerson`](04-schemas.md#contactperson) |  |  | Verwaltet die Kontaktdaten zu den Ansprechpartnern. |
| `finAccAccountDebtor` | `string` |  | 20 |  |
| `finAccAccountCreditor` | `string` |  | 20 |  |
| `inttraRefNumber` | `string` |  | 50 |  |
| `inttraRefType` | `string` |  |  |  |
| `addresses` | array of [`BusinessPartnerAddress`](04-schemas.md#businesspartneraddress) |  |  |  |
| `senderReceiver` | `boolean` |  |  |  |
| `freightBusinessPartner` | `boolean` |  |  |  |
| `valueAddedTaxNumber` | `string` |  | 30 |  |
| `vATIsoTwoCharacterCountryCode` | `string` |  | 2 |  |
| `locationCode` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |


## BusinessPartnerAddress

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `businessPartnerAddressType` | `string` |  |  |  |
| `location1` | `string` |  | 70 |  |
| `location2` | `string` |  | 70 |  |
| `zipCode` | `string` |  | 10 |  |
| `street` | `string` |  | 60 |  |
| `houseNumber` | `string` |  | 10 |  |
| `country` | [`Country`](04-schemas.md#country) |  |  |  |
| `appendix` | `string` |  | 35 |  |


## CarriageBase

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` |  |  |  |
| `objectOwner` | [`OrganizationalUnit`](04-schemas.md#organizationalunit) |  |  |  |
| `carrierContactPerson` | [`ContactPerson`](04-schemas.md#contactperson) |  |  |  |
| `designation` | `string` |  | 255 |  |
| `transportMode` | `string` |  |  |  |
| `trafficType` | [`TrafficType`](04-schemas.md#traffictype) |  |  |  |
| `purpose` | `string` |  |  |  |
| `section` | `string` |  |  |  |
| `vehicle` | [`Vehicle`](04-schemas.md#vehicle) |  |  |  |
| `plannedWaypoint` | array of [`PlannedWaypoint`](04-schemas.md#plannedwaypoint) |  |  |  |


## Claim

*No fields other than `actionAttribute`.*


## Client

Clients are used to depict the structure of a business or of an area of a business.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `matchcode` | `string` | yes | 10 | The matchcode. |
| `name1` | `string` | yes | 40 | The name 1 of this client. |
| `externalNumber` | `string` |  |  | The external number. |


## ConsignmentBusinessPartner

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `externalNumber` | `string` |  | 20 |  |
| `name1` | `string` |  | 40 |  |
| `name2` | `string` |  | 40 |  |
| `name3` | `string` |  | 40 |  |
| `name4` | `string` |  | 40 |  |
| `address` | [`AddressWithAppendix`](04-schemas.md#addresswithappendix) |  |  |  |


## ContactPerson

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` |  |  |  |
| `position` | `string` |  | 60 |  |
| `salutation` | `string` |  | 10 |  |
| `title` | `string` |  | 20 |  |
| `firstName` | `string` |  | 20 |  |
| `lastName` | `string` | yes | 20 |  |
| `department` | `string` |  | 60 |  |
| `telephone` | `string` |  | 30 |  |
| `fax` | `string` |  | 30 |  |
| `emailAddress` | `string` |  | 255 |  |
| `homepage` | `string` |  | 60 |  |
| `comment` | `string` |  | 255 |  |


## ContainerType

Hiermit können die verschiedenen Containertypen abgebildet werden.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` | yes |  |  |
| `matchcode` | `string` | yes |  |  |
| `designation` | `string` |  | 100 |  |
| `isoCode` | `string` |  | 4 |  |
| `content` | `string` |  | 255 |  |
| `isTemperatureControlled` | `boolean` |  |  |  |
| `tareWeight` | `number` |  |  |  |
| `payload` | `number` |  |  |  |
| `lengthInMeters` | `number` |  |  |  |
| `widthInMeters` | `number` |  |  |  |
| `heightInMeters` | `number` |  |  |  |
| `meter` | `number` |  |  |  |
| `squareMeter` | `number` |  |  |  |
| `cubicMeter` | `number` |  |  |  |
| `storePlace` | `number` |  |  |  |
| `tEU` | `number` |  |  | Unit of measurement for the size of containers. TEU = twenty-foot equivalent unit. |
| `stackability` | `integer` |  |  | Specifies how many containers, depending on their weight, can be stacked. For example, 2 containers. |


## Country

Hier können einzelne Länder angelegt werden.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `countryID` | `string` |  | 2 |  |
| `countryName` | `string` |  | 40 | The name of the country. |


## Currency

Hier können Währungen und deren Euro-Umrechnungsfaktor eingegeben werden.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `isoCurrencyCode` | `string` |  | 3 | 3-stelliges Währungskennzeichen nach ISO 4217 |


## CustomTypeValue

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `matchcode` | `string` | yes | 10 | The matchcode. |
| `designation` | `string` | yes | 100 | The designation. |


## CustomerBusinessPartner

Allows for the creation of business partners. For example, these can be customers, carriers or suppliers. The type serves to define how they are used in the system.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `businessPartnerId` | `integer` |  |  | The visible business partner id. |
| `externalNumber` | `string` |  | 20 | The external business partner number. |
| `matchcode` | `string` |  |  | The matchcode. |
| `globalLocationNumber` | `string` |  | 50 | Global Location Number. Interfaces can identify and allocate a business partner based on this number. |
| `name1` | `string` |  | 40 | The name1. |
| `name2` | `string` |  | 40 | The name2. |
| `name3` | `string` |  | 40 | The name3. |
| `name4` | `string` |  | 40 | The name4. |
| `phoneNumberHeadOffice` | `string` |  | 30 | The phone number of the head office. |
| `contactPerson` | array of [`ContactPerson`](04-schemas.md#contactperson) |  |  | Manages the contact data for the contacts. |
| `finAccAccountDebtor` | `string` |  | 20 | The account of the debtor. |
| `finAccAccountCreditor` | `string` |  | 20 | The account of the creditor. |
| `inttraRefNumber` | `string` |  | 50 | The INTTRA reference number. |
| `inttraRefType` | `integer \| string` |  |  | The INTTRA reference type. |
| `addresses` | array of [`BusinessPartnerAddress`](04-schemas.md#businesspartneraddress) |  |  | All addresses associated with this business partner. Up to 3 addresses are supported right now (see ). |
| `senderReceiver` | `boolean` |  |  | Whether this can act as a sender and receiver. |
| `freightBusinessPartner` | `boolean` |  |  | Whether this is a freight business partner. |
| `valueAddedTaxNumber` | `string` |  | 30 | The value added tax number of the business partner. |
| `vATIsoTwoCharacterCountryCode` | `string` |  | 2 | The two letter code of this country as according to ISO 3166-1 alpha-2. |
| `locationCode` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |


## DangerousGood

Gefahrgut bezeichnet Stoffe und Gegenstände, von denen bei der Beförderung Gefahren für die öffentliche Sicherheit ausgehen können. Die Gefahrgutangaben können Artikeln oder Verpackungen zugeordnet werden und die Angaben werden bei Auswahl des Artikels/Verpackung in den Auftrag übernommen. Alternativ kann man Gefahrgutangaben auch direkt im Auftrag auswählen.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` | yes |  |  |
| `externalIdentity` | `string` |  | 200 |  |
| `matchcode` | `string` | yes | 10 |  |
| `classificationCode` | `string` |  | 10 | ADR table A, column 3b |
| `class` | `string` |  |  | ADR table A, column 3a |
| `dataSheetAccident` | `string` |  | 30 |  |
| `dataSheetFirstAid` | `string` |  | 30 |  |
| `description` | `string` | yes | 2000 |  |
| `designation` | `string` |  | 255 |  |
| `flashpointEmergencyTemperature` | `number` |  |  |  |
| `hazardLabel` | `string` |  | 20 | <Main danger>+<optional add. danger> e.g. 3 or 4.1 or 6.1+3 or 2.3+5.1 |
| `hazardIdentificationNumber` | `string` |  | 5 | ADR table A, column 20 |
| `isDangerousToEnvironment` | `boolean` |  |  |  |
| `marinePollutant` | `string` |  |  |  |
| `intermediateBulkContainerInstruction` | `string` |  | 10 |  |
| `intermediateBulkContainerRegulation` | `string` |  | 10 |  |
| `emergencySchedules` | `string` |  | 10 |  |
| `internationalDescription` | `string` |  | 200 |  |
| `descriptionAir` | `string` |  | 200 |  |
| `limitedAmount` | `string` |  | 20 | With ADR 2013, the LQ coding was replaced by the specification of absolute quantities for the individual goods. This means that the absolute entries in column 7 a and the provisions of chapter 3.4 apply to all goods now. |
| `packageGroup` | `string` |  |  |  |
| `relevance` | `integer \| string` |  |  |  |
| `specialHandlingInformation` | `string` |  | 2000 |  |
| `isMsdsNeeded` | `boolean` |  |  |  |
| `specialProvisions640` | `string` |  | 1 |  |
| `dangerousGoodsWarehouseClass` | `string` |  |  |  |
| `transportUsing` | `string` |  |  |  |
| `tunnelRestrictionCode` | `string` |  |  |  |
| `unNumber` | `string` | yes | 4 |  |


## DocumentData

Defines a document with name, category and content as base64 string.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `name` | `string` | yes |  |  |
| `category` | `string` |  |  |  |
| `content` | `string` | yes |  |  |


## ErrorResponse

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `id` | `integer` |  |  | Unique id of the created/updated entity. |
| `messages` | `number` |  |  | Provides details in case of validation errors. |


## HarmonizedSystemCode

A customs tariff number that corresponds to the Harmonized System (HS) code.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `description` | `string` |  | 2000 | The description. |
| `designation` | `string` | yes | 255 | The designation. |
| `isActive` | `boolean` |  |  | Whether this instance is active. |
| `matchcode` | `string` | yes | 10 | The matchcode. |
| `number` | `integer` | yes |  | A visible number that can be used to identify this dataset. |
| `objectOwner` | [`OrganizationalUnit`](04-schemas.md#organizationalunit) |  |  |  |
| `isUsageLocked` | `boolean` |  |  | If enabled, the usage of the HS code is not permitted. The check, whether an HS code may not be used, can be configured in the "Restriction Tests" dialogue. |
| `validCountries` | array of [`Country`](04-schemas.md#country) |  |  | Contains all countries in which the HS code is valid. If no country is specified, this HS code is applicable in every country. |
| `codeValue` | `string` | yes | 255 | The value of the Harmonized System code. |


## HouseBillOfLading

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `shipperAddressString` | `string` |  | 2000 |  |
| `consigneeAddressString` | `string` |  | 2000 |  |
| `notify1AddressString` | `string` |  | 2000 |  |
| `notify2AddressString` | `string` |  | 2000 |  |
| `notify3AddressString` | `string` |  | 2000 |  |
| `portOfLoading` | `string` |  | 255 |  |
| `portOfDischarge` | `string` |  | 255 |  |
| `placeOfReceipt` | `string` |  | 255 |  |
| `placeOfDelivery` | `string` |  | 255 |  |
| `importAgentAddressString` | `string` |  | 2000 |  |
| `vessel` | `string` |  | 100 |  |
| `voyageNumber` | `string` |  | 100 |  |
| `placeOfIssue` | `string` |  | 255 |  |
| `placeOfPayment` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `placeOfPaymentName` | `string` |  | 255 |  |
| `freightAmount` | `number` |  |  |  |
| `goodsAreInsured` | `boolean` |  |  |  |
| `dateOfIssue` | `date-time` |  |  |  |
| `number` | `integer` |  |  |  |
| `numberOfGoods` | `integer` |  |  |  |
| `printDate` | `date-time` |  |  |  |
| `shippersDeclaration` | `string` |  | 2000 |  |
| `signature` | `string` |  | 255 |  |
| `stomachString` | `string` |  | 2000 | The stomach string. |


## LocationCode

Auflistung von Flughäfen, Bahnhöfen, Seehäfen usw. laut UN Locations-Liste und IATA-Liste.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `matchcode` | `string` | yes | 10 |  |
| `designation` | `string` |  | 255 |  |
| `iataCode` | `string` |  | 3 |  |
| `cityCode` | `string` |  | 3 |  |
| `country` | [`Country`](04-schemas.md#country) |  |  |  |


## MessageResult

Defines a validation message.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `code` | `integer` |  |  |  |
| `level` | `string` |  |  |  |
| `message` | `string` |  |  |  |
| `relatedPropertyId` | `integer` |  |  |  |
| `innerMessageResults` | array of [`MessageResult`](04-schemas.md#messageresult) |  |  |  |


## OceanCarriage

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `vessel` | [`OceanVessel`](04-schemas.md#oceanvessel) |  |  |  |
| `voyageNumber` | `string` |  | 255 | The voyage number. |
| `bookingAgent` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `portOfLoading` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `portOfDischarge` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `estimatedTimeOfDeparture` | `date-time` |  |  | The estimated time of departure (ETD). |
| `estimatedTimeOfArrival` | `date-time` |  |  | The estimated time of arrival (ETA). |
| `actualTimeOfDeparture` | `date-time` |  |  | The actual time of departure (ATD). |
| `actualTimeOfArrival` | `date-time` |  |  | The actual time of arrival (ATA). |
| `cutoffDates` | [`SeaCarriageCutoffDates`](04-schemas.md#seacarriagecutoffdates) |  |  |  |
| `masterBillOfLadingNumber` | `string` |  | 255 | The master B/L number can be used instead of the posting number to query Track & Trace events using the INTTRA interface. |
| `carrier` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `customerClosing` | `date` |  |  |  |
| `customerETD` | `date` |  |  |  |
| `customerETA` | `date` |  |  |  |
| `customerVessel` | [`OceanVessel`](04-schemas.md#oceanvessel) |  |  |  |
| `customerVoyage` | `string` |  | 20 |  |
| `customerPOL` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `customerPOD` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `customerPlaceofDelivery` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `pOLConfirmedByCarrier` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `pODConfirmedByCarrier` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `vesselConfirmedByCarrier` | [`OceanVessel`](04-schemas.md#oceanvessel) |  |  |  |
| `voyageConfirmedByCarrier` | `string` |  | 20 |  |
| `eTDConfirmedByCarrier` | `date` |  |  |  |
| `eTAConfirmedByCarrier` | `date` |  |  |  |
| `eTAInlandDestination` | `date` |  |  |  |
| `aTAInlandDestination` | `date` |  |  |  |


## OceanVessel

Allows for the entry of vessels as Master Data as, in sea freight, the same vessels are often used by a sea freight forwarder.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `vesselName` | `string` | yes | 200 | A short text containing a designation of this dataset. |
| `vesselNumber` | `string` | yes | 10 | An (alphanumeric) matchcode that can be used to identify this dataset. |


## OkResponse

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `id` | `integer` |  |  | Unique id of the created/updated entity. |


## OnCarriagePresets

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `emptyContainerReturnDepot` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `emptyContainerReturnTimeFrame` | [`SharedTimeFrame`](04-schemas.md#sharedtimeframe) |  |  |  |
| `importCarrier` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `importTransshipmentLocation1` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `importTransshipmentLocation2` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `deliveryLocation` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |


## OrganizationalUnit

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `organisationalUnitId` | `integer` |  |  |  |
| `organisationalUnitName` | `string` | yes | 10 | The matchcode. |
| `client` | [`Client`](04-schemas.md#client) |  |  |  |


## Package

Verpackungen von Artikeln, z. B. Kartons anlegen.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` | yes |  |  |
| `matchcode` | `string` | yes |  |  |
| `shortDesignation` | `string` |  | 10 |  |
| `contents` | `string` |  | 255 | A detailed description of the content of this package. |


## Person

This dialogue makes it possible to enter employees of the company.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `businessEmailAddress` | `string` |  | 255 | The business email address. |
| `businessTelephone` | `string` |  | 30 | The business phone number. |
| `businessCellular` | `string` |  | 30 | The business cell number. |


## PlannedWaypoint

The planned waypoint represents a transport waypoint on every level of the transport hierarchy on which it is visible within Transport Planning.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `sequence` | `integer` | yes |  |  |
| `number` | `integer` |  |  |  |
| `process` | `string` |  | 0 *(unused)* |  |
| `transportSector` | `integer \| string` |  |  |  |
| `transportWaypoint` | [`TransportWaypoint`](04-schemas.md#transportwaypoint) |  |  |  |


## PreCarriagePresets

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `emptyContainerPickupDepot` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `emptyContainerPickupTimeFrame` | [`SharedTimeFrame`](04-schemas.md#sharedtimeframe) |  |  |  |
| `exportCarrier` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `exportTransshipmentLocation1` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `exportTransshipmentLocation2` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `pickupLocation` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |


## ProcessingLogResponse

Defines an api processing log message which is the response for all incoming messages.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `processingResult` | `string` |  |  |  |
| `date` | `date-time` |  |  |  |
| `typeIdentifier` | `string` |  |  |  |
| `dataSets` | array of `object` |  |  |  |
| `validationMessages` | array of [`MessageResult`](04-schemas.md#messageresult) |  |  |  |
| `message` | `string` |  |  |  |
| `queueId` | `string` |  |  | Reference to pass the queue which will be returned in the final processing response. If no queueId is provided a guid will be generated to match enqueue response and final processing response. |
| `statusCode` | `integer` |  |  |  |


## RoadCarriage

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `haulage` | `integer \| string` |  |  | This property selects whether the CarLo user ("merchant") or the main carriage carrier ("carrier") should execute this particular carriage. |
| `transportMode` | `integer \| string` |  |  | The mode of transport used for the carriage. |
| `number` | `integer` |  |  |  |
| `objectOwner` | [`OrganizationalUnit`](04-schemas.md#organizationalunit) |  |  |  |
| `carrierContactPerson` | [`ContactPerson`](04-schemas.md#contactperson) |  |  |  |
| `designation` | `string` |  | 255 |  |
| `estimatedTimeOfDeparture` | `date-time` |  |  |  |
| `actualTimeOfDeparture` | `date-time` |  |  |  |
| `estimatedTimeOfArrival` | `date-time` |  |  |  |
| `actualTimeOfArrival` | `date-time` |  |  |  |
| `trafficType` | [`TrafficType`](04-schemas.md#traffictype) |  |  |  |
| `purpose` | `string` |  |  |  |
| `section` | `string` |  |  |  |
| `truck` | [`Vehicle`](04-schemas.md#vehicle) |  |  |  |
| `vehicle` | [`Vehicle`](04-schemas.md#vehicle) |  |  |  |
| `plannedWaypoint` | array of [`PlannedWaypoint`](04-schemas.md#plannedwaypoint) |  |  |  |
| `transportType` | [`TransportType`](04-schemas.md#transporttype) |  |  |  |


## SeaCarriageCutoffDates

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `exportTerminalDeliveryTimeFrame` | [`SharedTimeFrame`](04-schemas.md#sharedtimeframe) |  |  |  |
| `reeferDelClosing` | `date-time` |  |  | The latest date a booking with temperature control cargo can be placed. |
| `vGMClosing` | `date-time` |  |  | The latest date a VGM can be sent to the carrier. |
| `dGDelClosing` | `date-time` |  |  | The latest date a booking with dangerous goods can be placed. |
| `sIClosing` | `date-time` |  |  | The latest date a shipping instruction can be created. |


## SeaHouseShipment

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `preferredModeOfTransport` | `integer \| string` |  |  |  |
| `number` | `integer` |  |  |  |
| `frachtShipmentRef` | `string` |  | 255 |  |
| `customerReference` | `string` |  | 255 |  |
| `aMSHouseBillOfLadingNumber` | `string` |  | 200 | The bill of lading number for AMS purpose only. |
| `houseBillOfLadingNumber` | `string` |  | 255 |  |
| `movementType` | `string` |  |  |  |
| `houseType` | `string` |  |  |  |
| `loadType` | `string` |  |  |  |
| `incoterms` | `string` |  |  |  |
| `incotermplace` | `string` |  | 255 |  |
| `insuranceAmount` | `number` |  |  |  |
| `insuranceCurrency` | [`Currency`](04-schemas.md#currency) |  |  |  |
| `shipmentNumberSAP` | `string` |  | 255 |  |
| `deliveryTerms` | `string` | yes |  | The delivery terms. |
| `lockStatus` | `string` |  |  | The lock status. |
| `shipmentCostNumberSAP` | `string` |  | 255 |  |
| `shipmentDate` | `date` | yes |  | The shipment date. |
| `financialReportingDate` | `date` |  |  | Financial Reporting Date |
| `scenario` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `deliveryNoteSAP` | `string` |  | 255 |  |
| `customerTransportManagerName` | `string` |  | 255 |  |
| `customerTransportManagerEmail` | `string` |  | 255 |  |
| `customerTransportManagerPhone` | `string` |  | 255 |  |
| `customerExportManagerName` | `string` |  | 255 |  |
| `customerExportManagerEmail` | `string` |  | 255 |  |
| `customerExportManagerPhone` | `string` |  | 255 |  |
| `customerExportManagerAddress` | `string` |  | 2000 |  |
| `precedingCustomsDocumentDate` | `date` |  |  |  |
| `estimatedDispatchDate` | `date-time` |  |  |  |
| `latestDeliveryDate` | `date-time` |  |  |  |
| `internalComment` | `string` |  | 1000 | The remarks. |
| `externalComment` | `string` |  | 500 |  |
| `customsComment` | `string` |  | 255 |  |
| `customsOfficeOfExit` | `string` |  | 255 |  |
| `goodsLocationCustoms` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `customsDocumentType` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `aTREUR1Required` | `boolean` |  |  |  |
| `cOOInvoiceRequired` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `transportOrderComment` | `string` |  | 255 |  |
| `containerSummary` | `string` |  | 255 |  |
| `haulageType` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `goodsValue` | `number` |  |  |  |
| `goodsValueCurrency` | [`Currency`](04-schemas.md#currency) |  |  |  |
| `aTRNumber` | `string` |  | 255 |  |
| `customsInvoiceNumber` | `string` |  | 255 |  |
| `customerSalesOffice` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `countryOfOrigin` | [`Country`](04-schemas.md#country) |  |  |  |
| `countryOfDestination` | [`Country`](04-schemas.md#country) |  |  |  |
| `phoneNumberNotify1` | `string` |  | 255 |  |
| `phoneNumberNotify2` | `string` |  | 255 |  |
| `phoneNumberNotify3` | `string` |  | 255 |  |
| `emailNotify1` | `string` |  | 255 |  |
| `emailNotify2` | `string` |  | 255 |  |
| `emailNotify3` | `string` |  | 255 |  |
| `shipperTAXID` | `string` |  | 255 |  |
| `consigneeTAXID` | `string` |  | 255 |  |
| `notify1TAXID` | `string` |  | 255 |  |
| `notify2TAXID` | `string` |  | 255 |  |
| `notify3TAXID` | `string` |  | 255 |  |
| `showOnBLShipperPhoneEmail` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `commodity` | [`Article`](04-schemas.md#article) |  |  |  |
| `preCarriageLoadingRef` | `string` |  | 255 |  |
| `onCarriageDeliveryRef` | `string` |  | 255 |  |
| `endCustomerRef` | `string` |  | 255 |  |
| `createDocuments` | `boolean` |  |  |  |
| `readyForInvoicing` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `eDIID` | `string` |  | 255 |  |
| `shipmentBaseTasks` | array of [`ShipmentBaseTask`](04-schemas.md#shipmentbasetask) |  |  | All tasks assigned to this shipment. |
| `dUNSCustomer` | `string` |  | 255 |  |
| `bASFBL` | `string` |  | 255 |  |
| `sendersInstructions` | `string` |  | 4000 |  |
| `docDeliveryInstructions` | `string` |  | 4000 |  |
| `customerEDIType` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `bLRemarks` | `string` |  | 4000 |  |
| `forwarderName` | `string` |  | 255 |  |
| `forwarderRoad` | `string` |  | 255 |  |
| `forwarderNumber` | `string` |  | 255 |  |
| `forwarderPcd` | `string` |  | 255 |  |
| `forwarderCity1` | `string` |  | 255 |  |
| `forwarderCity2` | `string` |  | 255 |  |
| `forwarderCountry` | [`Country`](04-schemas.md#country) |  |  |  |
| `forwarderPhone` | `string` |  | 255 |  |
| `forwarderEmail` | `string` |  | 255 |  |
| `freightPayer` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `bLRecipients` | array of [`BLRecipients`](04-schemas.md#blrecipients) |  |  |  |
| `goodsReceiverName` | `string` |  | 255 |  |
| `goodsReceiverRoad` | `string` |  | 255 |  |
| `goodsReceiverNumber` | `string` |  | 255 |  |
| `goodsReceiverPcd` | `string` |  | 255 |  |
| `goodsReceiverCity1` | `string` |  | 255 |  |
| `goodsReceiverCity2` | `string` |  | 255 |  |
| `goodsReceiverCountry` | [`Country`](04-schemas.md#country) |  |  |  |
| `goodsReceiverPhone` | `string` |  | 255 |  |
| `goodsReceiverEmail` | `string` |  | 255 |  |
| `consignor` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `customsAgent` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `isInRecycleBin` | `string \| integer \| boolean` |  |  | Whether the shipment is in recycle bin or not. |
| `objectOwner` | [`OrganizationalUnit`](04-schemas.md#organizationalunit) | yes |  |  |
| `customer` | [`CustomerBusinessPartner`](04-schemas.md#customerbusinesspartner) | yes |  |  |
| `shipper` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `consignee` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `notify1` | [`ConsignmentBusinessPartner`](04-schemas.md#consignmentbusinesspartner) |  |  |  |
| `notify2` | [`ConsignmentBusinessPartner`](04-schemas.md#consignmentbusinesspartner) |  |  |  |
| `notify3` | [`ConsignmentBusinessPartner`](04-schemas.md#consignmentbusinesspartner) |  |  |  |
| `pickupLocation` | [`PreCarriagePresets`](04-schemas.md#precarriagepresets) |  |  |  |
| `transportSubcontractor` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `deliveryLocation` | [`OnCarriagePresets`](04-schemas.md#oncarriagepresets) |  |  |  |
| `placeOfReceipt` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `placeOfDelivery` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `externalReferenc` | array of [`ShipmentExternalReference`](04-schemas.md#shipmentexternalreference) |  |  |  |
| `billOfLading` | [`HouseBillOfLading`](04-schemas.md#housebilloflading) |  |  |  |
| `container` | array of [`ShipmentContainer`](04-schemas.md#shipmentcontainer) |  |  |  |
| `cargo` | array of [`ShipmentCargo`](04-schemas.md#shipmentcargo) |  |  | The cargoes, assigned to this shipment. |
| `master` | [`SeaMasterShipment`](04-schemas.md#seamastershipment) | yes |  |  |
| `carriage` | array of [`RoadCarriage`](04-schemas.md#roadcarriage) |  |  |  |
| `id` | `integer` |  |  | The unique id of this instance. |
| `differentFreightPayer` | [`BusinessPartner`](04-schemas.md#businesspartner) |  |  |  |
| `lCNumber` | `string` |  | 255 |  |
| `aCIDNumber` | `string` |  | 255 |  |
| `preCarriageMeansofTransport` | [`CustomTypeValue`](04-schemas.md#customtypevalue) |  |  |  |
| `documentData` | array of [`DocumentData`](04-schemas.md#documentdata) |  |  |  |


## SeaMasterShipment

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `preferredModeOfTransport` | `integer \| string` |  |  |  |
| `number` | `integer` |  |  |  |
| `mainCarriageAsOcean` | [`OceanCarriage`](04-schemas.md#oceancarriage) |  |  |  |
| `docClosingTransp` | `date-time` |  |  | The document closing date. |
| `contingentContract` | [`AirAndSeaContingentContract`](04-schemas.md#airandseacontingentcontract) |  |  |  |
| `automatedManifestSystemFilingDocument` | [`AutomatedManifestSystemFilingDocument`](04-schemas.md#automatedmanifestsystemfilingdocument) |  |  |  |
| `exportTerminalLocation` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `importTerminalLocation` | [`SharedLocation`](04-schemas.md#sharedlocation) |  |  |  |
| `placeOfReceipt` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `deliveryTerms` | `string` | yes |  | The delivery terms. |
| `placeOfDelivery` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `releaseTimeFrame` | [`SharedTimeFrame`](04-schemas.md#sharedtimeframe) |  |  |  |
| `remarks` | `string` |  | 1000 | The remarks. |
| `externalReferences` | array of [`ShipmentExternalReference`](04-schemas.md#shipmentexternalreference) |  |  | The external references assigned to this shipment. |
| `shippingInstructions` | [`ShippingInstructions`](04-schemas.md#shippinginstructions) |  |  |  |
| `lCLContainerNumber` | `string` |  | 255 |  |


## SharedLocation

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `externalNumber` | `string` |  | 20 |  |
| `externalDesignation` | `string` |  | 255 | The designation which was obtained from an external source. |
| `name1` | `string` |  | 40 |  |
| `name2` | `string` |  | 40 |  |
| `name3` | `string` |  | 40 |  |
| `name4` | `string` |  | 40 |  |
| `contact` | `string` |  | 255 | The name of the contact person of this shared location. |
| `emailAddress` | `string` |  | 255 | The contact person E-Mail address of this shared location. |
| `phoneNumber` | `string` |  | 255 | The contact person phone number of this shared location. |
| `address` | [`AddressWithAppendix`](04-schemas.md#addresswithappendix) |  |  |  |
| `unLocationCode` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |


## SharedTimeFrame

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `yardOpening` | `date-time` |  |  |  |
| `cYClosingTransp` | `date-time` |  |  |  |
| `cYClosingActual` | `date-time` |  |  |  |


## ShipmentBaseTask

A task that is allocated to a house/master shipment.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `completedByUser` | [`User`](04-schemas.md#user) |  |  |  |
| `completedTimestamp` | `date-time` |  |  | The the task was completed. |
| `designation` | `string` |  | 100 | The description of this task. |
| `dueDate` | `date-time` |  |  | The due date - the task should be finished on. |
| `responsibleUser` | [`User`](04-schemas.md#user) |  |  |  |
| `state` | `integer \| string` |  |  | The state. |
| `taskTemplate` | [`TaskTemplate`](04-schemas.md#tasktemplate) |  |  |  |


## ShipmentCargo

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `container` | [`ShipmentContainer`](04-schemas.md#shipmentcontainer) |  |  |  |
| `itemNumber` | `integer` | yes |  |  |
| `deliveryNoteSAP` | `string` |  | 255 |  |
| `totalNumberOfPackages` | `number` |  |  |  |
| `packaging` | [`Package`](04-schemas.md#package) |  |  |  |
| `article` | [`Article`](04-schemas.md#article) |  |  |  |
| `goodsDesignation` | `string` |  | 2000 |  |
| `totalGrossWeight` | `number` |  |  |  |
| `totalNetWeight` | `number` |  |  |  |
| `totalDimensionsArea` | `number` |  |  |  |
| `totalDimensionsVolume` | `number` |  |  |  |
| `hSCode` | `string` |  | 255 |  |
| `harmonizedSystemCodes` | array of [`HarmonizedSystemCode`](04-schemas.md#harmonizedsystemcode) |  |  | The harmonized system (HS) codes. |
| `totalSizeHeight` | `number` |  |  |  |
| `totalSizeLength` | `number` |  |  |  |
| `totalSizeWidth` | `number` |  |  |  |
| `transports` | array of [`CarriageBase`](04-schemas.md#carriagebase) |  |  |  |
| `totalDimensionsLoadingMeters` | `number` |  |  |  |
| `storePlaces` | `number` |  |  |  |
| `stackable` | `integer` |  |  |  |
| `handlingInfo` | `string` |  | 2000 |  |
| `dimensions` | array of [`ShipmentCargoItem`](04-schemas.md#shipmentcargoitem) |  |  |  |
| `dangerousGoods` | array of [`ShipmentCargoDangerousGoodsData`](04-schemas.md#shipmentcargodangerousgoodsdata) |  |  | Bei Klasse1 wird das Explosivgewicht als Nettogewicht interpretiert. |
| `character` | `string` |  | 2000 |  |
| `mRN` | `string` |  | 50 |  |
| `temperatureRangeFrom` | `number` |  |  |  |
| `temperateRangeTo` | `number` |  |  |  |
| `articleNumber` | `string` |  | 255 |  |
| `gTIN` | `string` |  | 255 |  |
| `deliveryInfo` | `string` |  | 4000 |  |
| `palletWeight` | `number` |  |  |  |
| `deliveryPositionNumber` | `string` |  | 255 |  |
| `orderNumberSAP` | `string` |  | 255 |  |
| `goodsReceiverReference` | `string` |  | 255 |  |
| `customerPONumber` | `string` |  | 255 |  |
| `additionalDGInfo` | `string` |  | 4000 |  |
| `additionalInfo` | `string` |  | 4000 |  |
| `loadingInstructions` | `string` |  | 4000 |  |
| `handlingRestrictions` | `string` |  | 4000 |  |
| `temperatureControlInstructions` | `string` |  | 4000 |  |
| `eDIID` | `string` |  | 255 |  |
| `changedByAPI` | `boolean` |  |  |  |


## ShipmentCargoDangerousGoodsData

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `quantity` | `number` |  |  |  |
| `unNumber` | `string` |  | 4 |  |
| `dangerousGoods` | [`DangerousGood`](04-schemas.md#dangerousgood) |  |  |  |
| `dangerousGoodsNote` | `string` |  | 2000 |  |
| `technicalName` | `string` |  | 2000 |  |
| `emergencyContactName` | `string` |  | 50 |  |
| `properShippingName` | `string` |  | 2000 |  |
| `tunnelRestrictionCodes` | `string` |  |  |  |
| `packagingGroup` | `string` |  |  |  |
| `packaging` | [`Package`](04-schemas.md#package) |  |  |  |
| `netWeight` | `number` |  |  |  |
| `instructionsForEmergency` | `string` |  | 10 |  |
| `imdgClass` | `string` |  |  |  |
| `hazardousToWater` | `string` |  |  |  |
| `flashpoint` | `number` |  |  |  |
| `emergencyContactPhoneNo` | `string` |  | 30 |  |
| `editing` | `string` |  | 2000 |  |
| `dangerousGoodsVolume` | `number` |  |  |  |
| `dangerousGoodsQuantityType` | `string` |  |  |  |
| `aggregationState` | `string` |  |  |  |
| `changedByAPI` | `boolean` |  |  |  |


## ShipmentCargoItem

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `itemNumber` | `integer` | yes |  |  |
| `quantity` | `number` |  |  |  |
| `grossWeight` | `number` |  |  |  |
| `sizeLength` | `number` |  |  |  |
| `sizeWidth` | `number` |  |  |  |
| `sizeHeight` | `number` |  |  |  |
| `dimensionsVolume` | `number` |  |  |  |
| `dimensionsLoadingMeters` | `number` |  |  |  |
| `dimensionsArea` | `number` |  |  |  |


## ShipmentContainer

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `sequenceNumber` | `integer` | yes |  | The sequence number. |
| `containerType` | [`ContainerType`](04-schemas.md#containertype) |  |  |  |
| `containerNumber` | `string` |  | 40 |  |
| `containerNumberType` | `string` |  |  |  |
| `sealNumber` | `string` |  | 40 |  |
| `sealnumber2` | `string` |  | 255 |  |
| `prelegReference` | `string` |  | 1000 |  |
| `tareWeight` | `number` |  |  |  |
| `verifiedGrossMass` | `number` |  |  |  |
| `vGMDate` | `date-time` |  |  |  |
| `vGMPersonInChanrge` | `string` |  | 255 |  |
| `vgmWeightDeterminationMethod` | `string` |  |  | The VGM weight determination method. |
| `vgmVerificationSignature` | `string` |  | 255 | The VGM verification signature. |
| `vgmState` | `string` |  |  | The VGM state. |
| `temperature` | `number` |  |  |  |
| `airflowPerHour` | `number` |  |  |  |
| `humidificationNecessary` | `boolean` |  |  |  |
| `humidification` | `number` |  |  |  |
| `oversizeDimensionsLength` | `number` |  |  |  |
| `oversizeDimensionsWidth` | `number` |  |  |  |
| `oversizeDimensionsHeight` | `number` |  |  |  |
| `ventSetting` | `string` |  |  |  |
| `drainage` | `string` |  |  |  |
| `notes` | `string` |  | 1000 |  |
| `transportMode` | `string` |  |  |  |
| `vgmClosingDate` | `date-time` |  |  |  |
| `siClosingDate` | `date-time` |  |  |  |
| `reeferClosingDate` | `date-time` |  |  |  |
| `dangerousGoodsBookingClosingDate` | `date-time` |  |  |  |
| `bookingClosingDate` | `date-time` |  |  |  |
| `importDetentionFreeDays` | `integer` |  |  |  |
| `importDemurageFreeUntil` | `date-time` |  |  |  |
| `importDemurrageFreeDays` | `integer` |  |  |  |
| `importDeletionDate` | `date-time` |  |  |  |
| `importReturnEmptyUntil` | `date-time` |  |  |  |
| `importReturnEmptyActual` | `date-time` |  |  |  |
| `importPickupFullActual` | `date-time` |  |  |  |
| `exportPickupEmtpyActual` | `date-time` |  |  |  |
| `exportDateActual` | `date-time` |  |  |  |
| `exportHandoverFullUntil` | `date-time` |  |  |  |
| `exportHandoverFullActual` | `date-time` |  |  |  |
| `exportDetentionFreeDays` | `integer` |  |  |  |
| `exportDemurrageFreeUntil` | `date-time` |  |  |  |
| `exportDemurrageFreeDays` | `integer` |  |  |  |
| `emptyContainerReturnStartTimeTarget` | `date-time` |  |  |  |
| `emptyContainerReturnStartActual` | `date-time` |  |  |  |
| `emptyContainerReturnEndTarget` | `date-time` |  |  |  |
| `emptyContainerReturnEndActual` | `date-time` |  |  |  |
| `emptyContainerPickupStartTarget` | `date-time` |  |  |  |
| `emptyContainerPickupStartActual` | `date-time` |  |  |  |
| `emptyContainerPickupEndTarget` | `date-time` |  |  |  |
| `emptyContainerPickupEndTimeActual` | `date-time` |  |  |  |
| `deliveryCFSCYStartTimeTarget` | `date-time` |  |  |  |
| `deliveryCFSCYStartTimeActuel` | `date-time` |  |  |  |
| `deliveryCFSCYEndTimeTarget` | `date-time` |  |  |  |
| `deliveryCFSCYEndTimeActual` | `date-time` |  |  |  |
| `customsReleaseNumber` | `string` |  | 35 |  |
| `containerGoodsInfo` | `string` |  | 255 |  |
| `eDIID` | `string` |  | 255 |  |
| `changedByAPI` | `boolean` |  |  |  |


## ShipmentExternalReference

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `referenceType` | `integer \| string` |  |  |  |
| `value` | `string` | yes | 2000 |  |


## ShippingInstructions

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `billOfLadingKind` | `integer \| string` |  |  |  |
| `consigneeAddressString` | `string` |  | 2000 |  |
| `currency` | [`Currency`](04-schemas.md#currency) |  |  |  |
| `forwardingAgent` | `string` |  | 0 *(unused)* |  |
| `freightAmount` | `number` |  |  |  |
| `goodsAreInsured` | `boolean` |  |  |  |
| `valueOfGoods` | `number` |  |  |  |
| `importAgentAddressString` | `string` |  | 2000 |  |
| `dateOfIssue` | `date-time` |  |  |  |
| `placeOfIssue` | `string` |  | 255 |  |
| `notify1AddressString` | `string` |  | 2000 |  |
| `notify2AddressString` | `string` |  | 2000 |  |
| `notify3AddressString` | `string` |  | 2000 |  |
| `number` | `integer` |  |  |  |
| `numberOfOriginals` | `integer` |  |  | Is preset via the Global Configuration, under CarLo\Sea freight\Bill of lading. |
| `oceanCarrier` | `string` |  | 0 *(unused)* |  |
| `placeOfPayment` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |
| `placeOfPaymentDesignation` | `string` |  | 255 |  |
| `placeOfDelivery` | `string` |  | 255 |  |
| `placeOfReceipt` | `string` |  | 255 |  |
| `dischargePortName` | `string` |  | 255 |  |
| `loadingPortName` | `string` |  | 255 |  |
| `printDate` | `date-time` |  |  |  |
| `shipperAddressString` | `string` |  | 2000 |  |
| `shippersDeclaration` | `string` |  | 2000 |  |
| `signature` | `string` |  | 255 |  |
| `specialNotesForOceanCarrier` | `string` |  | 0 *(unused)* |  |
| `stomachString` | `string` |  | 2000 |  |
| `vessel` | `string` |  | 100 |  |
| `voyageNumber` | `string` |  | 100 |  |


## TaskTemplate

Task templates can be used directly in the consignment task list or the business partner task list as well as in the Task List Templates dialogue.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `designation` | `string` | yes | 100 | The designation . |
| `isActive` | `boolean` |  |  | Whether this is active. |
| `matchcode` | `string` | yes | 10 | The matchcode . |
| `number` | `integer` | yes |  | The number of the . |


## TrafficType

Hier können die Verkehrsarten definiert werden, diese stehen in Form eines Drop-Down Feldes in der Auftragserfassung zur Verfügung.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` | yes |  |  |
| `externalNumber` | `string` |  | 30 |  |
| `matchcode` | `string` | yes | 10 |  |
| `designation` | `string` | yes | 30 |  |
| `transportCarrier` | `string` |  |  |  |


## TransportType

The shipment mode indicates the type of delivery (e.g. road, rail).

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` | yes |  |  |
| `matchcode` | `string` | yes | 10 |  |
| `description` | `string` |  | 50 |  |


## TransportWaypoint

A (transport) waypoint represents a (usually) stationary event in the life of the corresponding transport within Transport Planning.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` |  |  |  |
| `type` | `string` |  |  |  |
| `sharedLocation` | [`WaypointSharedLocation`](04-schemas.md#waypointsharedlocation) |  |  |  |
| `startTarget` | `date-time` |  |  |  |
| `endTarget` | `date-time` |  |  |  |
| `startActual` | `date-time` |  |  |  |
| `endActual` | `date-time` |  |  |  |
| `referenceLoadingUnloadingPickupDropoff` | `string` |  | 255 |  |


## User

Allows for the creation of users for the CarLo system.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `fullName` | `string` | yes | 30 | The full name. |
| `logOnName` | `string` | yes | 40 | The log-on-name. |
| `person` | [`Person`](04-schemas.md#person) |  |  |  |


## Vehicle

Hier werden sämtliche Fahrzeuge (u.a. LKW, Anhänger und Transportmittel) des Unternehmens erfasst.

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `number` | `integer` | yes |  |  |
| `matchcode` | `string` | yes | 10 |  |
| `licensePlate` | `string` | yes | 20 |  |
| `actualKm` | `number` |  |  |  |


## WaypointSharedLocation

| Field | Type | Req | Max | Notes |
|---|---|:-:|--:|---|
| `externalNumber` | `string` |  | 20 |  |
| `externalDesignation` | `string` |  | 255 |  |
| `name1` | `string` |  | 40 |  |
| `name2` | `string` |  | 40 |  |
| `name3` | `string` |  | 40 |  |
| `name4` | `string` |  | 40 |  |
| `contact` | `string` |  | 255 | The name of the contact person of this shared location. |
| `emailAddress` | `string` |  | 255 |  |
| `phoneNumber` | `string` |  | 255 |  |
| `address` | [`AddressWithAppendix`](04-schemas.md#addresswithappendix) |  |  |  |
| `unLocationCode` | [`LocationCode`](04-schemas.md#locationcode) |  |  |  |

