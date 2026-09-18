# `ShipmentCargo` — the cargo line

One cargo line of a house shipment: a goods position with its packaging, weights, HS code,
dangerous-goods data and the container it sits in. This is the resource the IFCSUM mapping writes.

```
POST   /api/PolytraSeafreightHouseShipment_BASF/v3/ShipmentCargo
GET    /api/PolytraSeafreightHouseShipment_BASF/v3/ShipmentCargo/{id}
PUT    /api/PolytraSeafreightHouseShipment_BASF/v3/ShipmentCargo/{id}
DELETE /api/PolytraSeafreightHouseShipment_BASF/v3/ShipmentCargo/{id}
```

Body and response are an array under a `shipmentCargo` key:

```json
{ "shipmentCargo": [ { "...": "one cargo line" } ] }
```

## Two ways to write a cargo line

A cargo line reaches CarLo either **nested** inside a house shipment
(`seaHouseShipment[].cargo[]`, the same [`ShipmentCargo`](04-schemas.md#shipmentcargo) type) or
**standalone** through this endpoint. They are not interchangeable:

- Nested, on a create, is how a line comes into existence along with its dossier.
- Standalone is how you amend a line that already exists — adding a VGM, an MRN, a container
  assignment — without resending the whole dossier.

Standalone has no usable create path: nothing on `shipmentCargo` names the parent dossier, so a
line posted here can only be *matched* against one already stored, by `deliveryNoteSAP` /
`eDIID` / `itemNumber`. An `updateorcreate` whose match fails adds an orphan line rather than
failing, so send `actionAttribute: "update"` on this endpoint.

## Required fields

`itemNumber` — the position number within its shipment. It is the only required field, and it is part
of what an `update` matches on, together with the delivery-note reference.

## Fields

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

## Notes

`hSCode` (a free string) and `harmonizedSystemCodes` (references into CarLo's HS-code master
data) are different fields. The string takes whatever the message carried; the array resolves
only against codes that exist in CarLo, and a `matchcode` that does not is a validation error.

`dangerousGoods[]` is an array — one entry per UN number on the line — of
[`ShipmentCargoDangerousGoodsData`](04-schemas.md#shipmentcargodangerousgoodsdata). Its swagger
description, *"Bei Klasse1 wird das Explosivgewicht als Nettogewicht interpretiert"*, means: for
class 1 (explosives) `netWeight` is read as the explosive weight, not the net mass.

`container` is a **single** [`ShipmentContainer`](04-schemas.md#shipmentcontainer), not an array -
a cargo line sits in one container. `sequenceNumber` is required on it and is what ties the line
to the container of the same sequence on the dossier. Get it wrong and CarLo adds a second
container instead of matching the existing one.

Weight, volume and count fields are plain numbers on the wire despite the swagger's
`type: object` — see [quantities](01-calling-the-api.md#quantities).

`mRN` is capped at **50** characters, not the 255 most of the string fields on this resource
carry. The customs MRNs the IFCSUM mapping writes are 18 characters
(`26DE590487611538B5`), so there is headroom, but it is the tightest limit on anything that
mapping emits.

`changedByAPI` is a server-side boolean with no description in the swagger; it is not one of
the 54 schemas' usual fields (only this resource, `ShipmentContainer` and
`ShipmentCargoDangerousGoodsData` have it) and no mapping writes it.

## Related

- [`SeaHouseShipment`](02-seahouseshipment.md) — the dossier these lines belong to
- [05-filter-properties.md](05-filter-properties.md#shipmentcargo) — the 21 filterable properties
