# `$filter` property ids

CarLo's OData-ish filter addresses fields by **numeric property id**, never by name:
`$filter=700071 eq '2800209301'` filters on `customerReference`. The ids below are the complete
set the v3 contract advertises as filterable — 71 on `SeaHouseShipment`, 21 on
`ShipmentCargo`. A field not in these tables cannot be filtered on, even though it exists on the
object.

Read [§ $filter](01-calling-the-api.md#4-filter) first for the encoding rules — getting the
space encoding wrong is an HTTP 500, not a 400.

Two ids separated by `/` (e.g. `186062/5765907`) are the swagger's own example and mean the
property is reachable by either id; use the first.

A `_Range` row is a pair: the property has a *from* id and a *to* id one higher, and you combine
them with `ge` / `le`. The plain (non-range) id matches a single exact value.

## SeaHouseShipment

| Property | Id | Operators | Example |
|---|---|---|---|
| `Number` | `186002` | `eq` | `186002 eq 10` |
| `FrachtShipmentRef` | `700029` | `eq`, `contains`, `endswith`, `startswith` | `700029 eq 'yourFilterString'` |
| `CustomerReference` | `700071` | `eq`, `contains`, `endswith`, `startswith` | `700071 eq 'yourFilterString'` |
| `AMSHouseBillOfLadingNumber` | `186062` / `5765907` | `eq`, `contains`, `endswith`, `startswith` | `186062/5765907 eq 'yourFilterString'` |
| `HouseBillOfLadingNumber` | `189004` | `eq`, `contains`, `endswith`, `startswith` | `189004 eq 'yourFilterString'` |
| `Incotermplace` | `191004` | `eq`, `contains`, `endswith`, `startswith` | `191004 eq 'yourFilterString'` |
| `ShipmentNumberSAP` | `700116` | `eq`, `contains`, `endswith`, `startswith` | `700116 eq 'yourFilterString'` |
| `ShipmentCostNumberSAP` | `700115` | `eq`, `contains`, `endswith`, `startswith` | `700115 eq 'yourFilterString'` |
| `ShipmentDate` | `186055` | `eq` | `186055 eq datetime'2026-09-14'` |
| `ShipmentDate_Range` | `186056` / `186057` | `eq` | `Filter ShipmentDate from/to use 186056 ge datetime'2026-09-14' and 186057 le datetime'2026-09-14'` |
| `FinancialReportingDate` | `700034` | `eq` | `700034 eq datetime'2026-09-14'` |
| `DeliveryNoteSAP` | `700042` | `eq`, `contains`, `endswith`, `startswith` | `700042 eq 'yourFilterString'` |
| `CustomerTransportManagerName` | `700046` | `eq`, `contains`, `endswith`, `startswith` | `700046 eq 'yourFilterString'` |
| `CustomerTransportManagerEmail` | `700047` | `eq`, `contains`, `endswith`, `startswith` | `700047 eq 'yourFilterString'` |
| `CustomerTransportManagerPhone` | `700151` | `eq`, `contains`, `endswith`, `startswith` | `700151 eq 'yourFilterString'` |
| `CustomerExportManagerName` | `700048` | `eq`, `contains`, `endswith`, `startswith` | `700048 eq 'yourFilterString'` |
| `CustomerExportManagerEmail` | `700049` | `eq`, `contains`, `endswith`, `startswith` | `700049 eq 'yourFilterString'` |
| `CustomerExportManagerPhone` | `700152` | `eq`, `contains`, `endswith`, `startswith` | `700152 eq 'yourFilterString'` |
| `CustomerExportManagerAddress` | `700277` | `eq`, `contains`, `endswith`, `startswith` | `700277 eq 'yourFilterString'` |
| `PrecedingCustomsDocumentDate` | `700056` | `eq` | `700056 eq datetime'2026-09-14'` |
| `EstimatedDispatchDate` | `191009` | `eq` | `191009 eq datetime'2026-09-14T12:45:19'` |
| `EstimatedDispatchDate_Range` | `191010` / `191011` | `eq` | `Filter EstimatedDispatchDate from/to use 191010 ge datetime'2026-09-14T12:45:19' and 191011 le datetime'2026-09-14T12:45:19'` |
| `LatestDeliveryDate` | `191012` | `eq` | `191012 eq datetime'2026-09-14T12:45:19'` |
| `LatestDeliveryDate_Range` | `191013` / `191014` | `eq` | `Filter LatestDeliveryDate from/to use 191013 ge datetime'2026-09-14T12:45:19' and 191014 le datetime'2026-09-14T12:45:19'` |
| `InternalComment` | `186011` | `eq`, `contains`, `endswith`, `startswith` | `186011 eq 'yourFilterString'` |
| `ExternalComment` | `700043` | `eq`, `contains`, `endswith`, `startswith` | `700043 eq 'yourFilterString'` |
| `CustomsComment` | `700051` | `eq`, `contains`, `endswith`, `startswith` | `700051 eq 'yourFilterString'` |
| `CustomsOfficeOfExit` | `700058` | `eq`, `contains`, `endswith`, `startswith` | `700058 eq 'yourFilterString'` |
| `TransportOrderComment` | `700067` | `eq`, `contains`, `endswith`, `startswith` | `700067 eq 'yourFilterString'` |
| `ContainerSummary` | `700069` | `eq`, `contains`, `endswith`, `startswith` | `700069 eq 'yourFilterString'` |
| `ATRNumber` | `700103` | `eq`, `contains`, `endswith`, `startswith` | `700103 eq 'yourFilterString'` |
| `CustomsInvoiceNumber` | `700102` | `eq`, `contains`, `endswith`, `startswith` | `700102 eq 'yourFilterString'` |
| `PhoneNumberNotify1` | `700104` | `eq`, `contains`, `endswith`, `startswith` | `700104 eq 'yourFilterString'` |
| `PhoneNumberNotify2` | `700105` | `eq`, `contains`, `endswith`, `startswith` | `700105 eq 'yourFilterString'` |
| `PhoneNumberNotify3` | `700106` | `eq`, `contains`, `endswith`, `startswith` | `700106 eq 'yourFilterString'` |
| `EmailNotify1` | `700107` | `eq`, `contains`, `endswith`, `startswith` | `700107 eq 'yourFilterString'` |
| `EmailNotify2` | `700108` | `eq`, `contains`, `endswith`, `startswith` | `700108 eq 'yourFilterString'` |
| `EmailNotify3` | `700109` | `eq`, `contains`, `endswith`, `startswith` | `700109 eq 'yourFilterString'` |
| `ShipperTAXID` | `700416` | `eq`, `contains`, `endswith`, `startswith` | `700416 eq 'yourFilterString'` |
| `ConsigneeTAXID` | `700417` | `eq`, `contains`, `endswith`, `startswith` | `700417 eq 'yourFilterString'` |
| `Notify1TAXID` | `700418` | `eq`, `contains`, `endswith`, `startswith` | `700418 eq 'yourFilterString'` |
| `Notify2TAXID` | `700419` | `eq`, `contains`, `endswith`, `startswith` | `700419 eq 'yourFilterString'` |
| `Notify3TAXID` | `700420` | `eq`, `contains`, `endswith`, `startswith` | `700420 eq 'yourFilterString'` |
| `PreCarriageLoadingRef` | `700113` | `eq`, `contains`, `endswith`, `startswith` | `700113 eq 'yourFilterString'` |
| `OnCarriageDeliveryRef` | `700114` | `eq`, `contains`, `endswith`, `startswith` | `700114 eq 'yourFilterString'` |
| `EndCustomerRef` | `700128` | `eq`, `contains`, `endswith`, `startswith` | `700128 eq 'yourFilterString'` |
| `EDIID` | `700147` | `eq`, `contains`, `endswith`, `startswith` | `700147 eq 'yourFilterString'` |
| `DUNSCustomer` | `700194` | `eq`, `contains`, `endswith`, `startswith` | `700194 eq 'yourFilterString'` |
| `BASFBL` | `700199` | `eq`, `contains`, `endswith`, `startswith` | `700199 eq 'yourFilterString'` |
| `SendersInstructions` | `700248` | `eq`, `contains`, `endswith`, `startswith` | `700248 eq 'yourFilterString'` |
| `DocDeliveryInstructions` | `700249` | `eq`, `contains`, `endswith`, `startswith` | `700249 eq 'yourFilterString'` |
| `BLRemarks` | `700251` | `eq`, `contains`, `endswith`, `startswith` | `700251 eq 'yourFilterString'` |
| `ForwarderName` | `700253` | `eq`, `contains`, `endswith`, `startswith` | `700253 eq 'yourFilterString'` |
| `ForwarderRoad` | `700254` | `eq`, `contains`, `endswith`, `startswith` | `700254 eq 'yourFilterString'` |
| `ForwarderNumber` | `700255` | `eq`, `contains`, `endswith`, `startswith` | `700255 eq 'yourFilterString'` |
| `ForwarderPcd` | `700256` | `eq`, `contains`, `endswith`, `startswith` | `700256 eq 'yourFilterString'` |
| `ForwarderCity1` | `700257` | `eq`, `contains`, `endswith`, `startswith` | `700257 eq 'yourFilterString'` |
| `ForwarderCity2` | `700258` | `eq`, `contains`, `endswith`, `startswith` | `700258 eq 'yourFilterString'` |
| `ForwarderPhone` | `700260` | `eq`, `contains`, `endswith`, `startswith` | `700260 eq 'yourFilterString'` |
| `ForwarderEmail` | `700261` | `eq`, `contains`, `endswith`, `startswith` | `700261 eq 'yourFilterString'` |
| `GoodsReceiverName` | `700268` | `eq`, `contains`, `endswith`, `startswith` | `700268 eq 'yourFilterString'` |
| `GoodsReceiverRoad` | `700269` | `eq`, `contains`, `endswith`, `startswith` | `700269 eq 'yourFilterString'` |
| `GoodsReceiverNumber` | `700270` | `eq`, `contains`, `endswith`, `startswith` | `700270 eq 'yourFilterString'` |
| `GoodsReceiverPcd` | `700271` | `eq`, `contains`, `endswith`, `startswith` | `700271 eq 'yourFilterString'` |
| `GoodsReceiverCity1` | `700272` | `eq`, `contains`, `endswith`, `startswith` | `700272 eq 'yourFilterString'` |
| `GoodsReceiverCity2` | `700273` | `eq`, `contains`, `endswith`, `startswith` | `700273 eq 'yourFilterString'` |
| `GoodsReceiverPhone` | `700275` | `eq`, `contains`, `endswith`, `startswith` | `700275 eq 'yourFilterString'` |
| `GoodsReceiverEmail` | `700276` | `eq`, `contains`, `endswith`, `startswith` | `700276 eq 'yourFilterString'` |
| `Id` | `186001` | `eq` | `186001 eq 10` |
| `LCNumber` | `700468` | `eq`, `contains`, `endswith`, `startswith` | `700468 eq 'yourFilterString'` |
| `ACIDNumber` | `700469` | `eq`, `contains`, `endswith`, `startswith` | `700469 eq 'yourFilterString'` |

## ShipmentCargo

| Property | Id | Operators | Example |
|---|---|---|---|
| `ItemNumber` | `5745402` | `eq` | `5745402 eq 10` |
| `DeliveryNoteSAP` | `700068` | `eq`, `contains`, `endswith`, `startswith` | `700068 eq 'yourFilterString'` |
| `GoodsDesignation` | `5745410` | `eq`, `contains`, `endswith`, `startswith` | `5745410 eq 'yourFilterString'` |
| `HSCode` | `5745415` | `eq`, `contains`, `endswith`, `startswith` | `5745415 eq 'yourFilterString'` |
| `Stackable` | `5745412` | `eq` | `5745412 eq 10` |
| `HandlingInfo` | `5745414` | `eq`, `contains`, `endswith`, `startswith` | `5745414 eq 'yourFilterString'` |
| `Character` | `5745413` | `eq`, `contains`, `endswith`, `startswith` | `5745413 eq 'yourFilterString'` |
| `MRN` | `700139` | `eq`, `contains`, `endswith`, `startswith` | `700139 eq 'yourFilterString'` |
| `ArticleNumber` | `700265` | `eq`, `contains`, `endswith`, `startswith` | `700265 eq 'yourFilterString'` |
| `GTIN` | `700266` | `eq`, `contains`, `endswith`, `startswith` | `700266 eq 'yourFilterString'` |
| `DeliveryInfo` | `700267` | `eq`, `contains`, `endswith`, `startswith` | `700267 eq 'yourFilterString'` |
| `DeliveryPositionNumber` | `700279` | `eq`, `contains`, `endswith`, `startswith` | `700279 eq 'yourFilterString'` |
| `OrderNumberSAP` | `700289` | `eq`, `contains`, `endswith`, `startswith` | `700289 eq 'yourFilterString'` |
| `GoodsReceiverReference` | `700288` | `eq`, `contains`, `endswith`, `startswith` | `700288 eq 'yourFilterString'` |
| `CustomerPONumber` | `700281` | `eq`, `contains`, `endswith`, `startswith` | `700281 eq 'yourFilterString'` |
| `AdditionalDGInfo` | `700282` | `eq`, `contains`, `endswith`, `startswith` | `700282 eq 'yourFilterString'` |
| `AdditionalInfo` | `700283` | `eq`, `contains`, `endswith`, `startswith` | `700283 eq 'yourFilterString'` |
| `LoadingInstructions` | `700284` | `eq`, `contains`, `endswith`, `startswith` | `700284 eq 'yourFilterString'` |
| `HandlingRestrictions` | `700285` | `eq`, `contains`, `endswith`, `startswith` | `700285 eq 'yourFilterString'` |
| `TemperatureControlInstructions` | `700286` | `eq`, `contains`, `endswith`, `startswith` | `700286 eq 'yourFilterString'` |
| `EDIID` | `700310` | `eq`, `contains`, `endswith`, `startswith` | `700310 eq 'yourFilterString'` |
