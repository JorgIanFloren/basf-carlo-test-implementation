# `SeaHouseShipment` — the house shipment (dossier)

A CarLo **house shipment** is one dossier: one bill of lading's worth of a booking, with its
master shipment, containers, cargo lines and road carriages hanging off it. This is the resource
the IFTMIN and IFTMBF mappings write.

```
POST   /api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment
GET    /api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment/{id}
PUT    /api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment/{id}
DELETE /api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment/{id}
```

The body is **always** an array under a `seaHouseShipment` key, on POST and PUT alike, and the
GET response comes back the same way:

```json
{ "seaHouseShipment": [ { "...": "one dossier" } ] }
```

One request can carry many dossiers. That is what makes a BASF master-sub order a single call:
each bill of lading is its own entry in the array. See
[batching](01-calling-the-api.md#writing-several-records-in-one-call).

## Required fields

`deliveryTerms`, `shipmentDate`, `objectOwner`, `customer`, `master`

The contract enforces these on a create. On an `update` — or an `updateorcreate` that resolves to
an existing record — CarLo merges what you send into the stored dossier, so an update need not
restate them. On a create, omitting one is a `400` carrying a validation message, not a silent
default.

`master` being required means **every** house shipment carries a
[`SeaMasterShipment`](04-schemas.md#seamastershipment), even a stand-alone one; its own
`deliveryTerms` is required in turn.

## Fields

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

## Values the contract does not enumerate

The swagger types `movementType`, `houseType`, `loadType`, `deliveryTerms`, `lockStatus`,
`incoterms` and their neighbours as bare `string` with no `enum`, but CarLo validates them
against its own enum members and rejects anything else. These are the values attested by live GET
responses from the test system and by this repo's captures in `docs/get-responses/`:

| Field | Observed values |
|---|---|
| `preferredModeOfTransport` | `Ocean` |
| `movementType` | `P/P`, `D/P`, `D/D` |
| `houseType` | `House`, `BackToBack`; `Coloadin` per BASF's flow document, not yet seen in a response |
| `loadType` | `FCL`, `LCL`, `GC` |
| `incoterms` | `CIF`, `CIP`, `CFR` — ISO Incoterm codes |
| `deliveryTerms` | `Prepaid` |
| `lockStatus` | `Free`, `Consolidated` |
| `isInRecycleBin` | `true` / `false` |
| `carriage[].purpose` | `PickUpContainerForExportTerminal`, `DeliveryFromImportTerminal` |
| `carriage[].section` | `PreCarriage`, `OnCarriage` |
| `carriage[].transportMode` | `Container`, `Road` |
| `container[].containerNumberType` | `Known`, `Unknown` |
| `container[].vgmWeightDeterminationMethod` | `SM2` |
| `container[].vgmState` | `NotSent` |
| `container[].ventSetting`, `container[].drainage` | `None` |
| `externalReferenc[].referenceType` | `9` — numeric member |
| `shipmentBaseTasks[].state` | `0`, `1` — numeric member |
| `master.shippingInstructions.billOfLadingKind` | `1` — numeric member |
| `customer.inttraRefType` | `InttraCompanyId`, `0` |
| `*.addresses[].businessPartnerAddressType` | `Default` |

`houseType: "Coloadin"` is spelled that way — one word, lower-case `in` — even though BASF's
flow document writes it "Co-load in". It is the only value in the table above that no live
response has confirmed, so it is the one to check first if an LCL master-sub is rejected.

Fields typed `string | integer` in the table above take either the enum member's name or its
numeric value. Prefer the name wherever one is attested: a number out of range is accepted
silently and stores nonsense.

`isInRecycleBin` is how a dossier is withdrawn. Setting it `true` and upserting keeps the record
in CarLo but drops it out of every later `$filter` result — which is why the lookup in
[06-dossier-lookup.md](06-dossier-lookup.md) also filters recycled records out client-side.

## Addressing an existing dossier

`POST` with `actionAttribute: "updateorcreate"` keys on the record's natural identity, which for
BASF is `customerReference`. A master-sub order, where several dossiers share one
`customerReference`, therefore cannot be addressed that way — the last entry in the array wins.
To update one specific dossier you need its `id`, and for that you need a lookup:
[06-dossier-lookup.md](06-dossier-lookup.md).

## Related

- [`ShipmentCargo`](03-shipmentcargo.md) — the cargo lines, writable standalone as well as nested
  here under `cargo`
- [04-schemas.md](04-schemas.md) — every nested type
- [05-filter-properties.md](05-filter-properties.md#seahouseshipment) — the 71 filterable
  properties
