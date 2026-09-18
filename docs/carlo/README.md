# The Carlo API

How to call CarLo (Soloplan) from this integration, and what its contracts actually contain.

| | |
|---|---|
| Contract | `PolytraSeafreightHouseShipment_BASF` v3 (API-Version 2.0) |
| Base URL | `https://api-carlo-test.fracht.be:4712/api/PolytraSeafreightHouseShipment_BASF/v3` |
| Swagger UI | [`/docs/index.html?urls.primaryName=PolytraSeafreightHouseShipment_BASF-v3`](https://api-carlo-test.fracht.be:4712/docs/index.html?urls.primaryName=PolytraSeafreightHouseShipment_BASF-v3) |
| OpenAPI document | `/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json` (OpenAPI 3.0.1) |
| Resources | `SeaHouseShipment`, `ShipmentCargo` |
| Verified | 2026-09-16, against the test server. Swagger re-checked 2026-09-18 — four differences, all corrected here; see [07-contract-conformance.md § What changed since 2026-09-16](07-contract-conformance.md#what-changed-since-2026-09-16) |

## Pages

| | |
|---|---|
| [01-calling-the-api.md](01-calling-the-api.md) | **Start here.** Endpoint, the three auth schemes, the required headers, `$filter` and its encoding trap, body envelope, field naming, quantities, `actionAttribute`, the response envelope and every status code |
| [02-seahouseshipment.md](02-seahouseshipment.md) | The house shipment (dossier) — all 122 fields, required fields, and the enum values the contract does not declare |
| [03-shipmentcargo.md](03-shipmentcargo.md) | The cargo line — all 42 fields, and nested-vs-standalone writes |
| [04-schemas.md](04-schemas.md) | All 54 nested component schemas, field by field |
| [05-filter-properties.md](05-filter-properties.md) | The numeric `$filter` property ids — 71 on `SeaHouseShipment`, 21 on `ShipmentCargo` |
| [06-dossier-lookup.md](06-dossier-lookup.md) | The "GET dossier by CustomerRef" call the pipeline still needs, and the contract it has to satisfy |
| [07-contract-conformance.md](07-contract-conformance.md) | Whether the three mappings match the contract, and how v3 differs from v4 |

## What the integration calls

| Message | Mapping | Call |
|---|---|---|
| IFTMIN | `InboundIftmin.dwl` | `POST /SeaHouseShipment` |
| IFTMBF | `InboundIftmbf.dwl` | `POST /SeaHouseShipment` |
| IFCSUM | `InboundIfcsum.dwl` | `POST /ShipmentCargo` |
| *(missing)* | — | `GET /SeaHouseShipment/0?$filter=700071 eq '<ref>'` — [06](06-dossier-lookup.md) |

Wiring is in `config/dataProfiler-basf-*.json`, under the `dataDelivery` step. `config/README.md`
covers what is inferred there.

## The five things that bite

1. **`Accept: application/json` is required on GET.** Without it, HTTP `500` —
   `{"message":"Specify a supported data format."}`. `*/*` does not count, and `*/*` is what most
   clients send by default.
2. **`$filter` spaces must be `%20`, not `+`.** Form-encoded, it is HTTP `500` *"did not produce
   any applicable filter criteria"* — which does not read like an encoding problem.
3. **`$top` defaults to 50 and truncates in silence.** No total, no paging, no flag.
4. **Field names are PascalCase with the first letter lower-cased**, mechanically — `hSCode`,
   `mRN`, `bASFBL`, `eDIID`, `gTIN`, `aMSHouseBillOfLadingNumber`. CarLo discards a field it does
   not recognise without a word, so wrong casing is a value that silently never arrives.
5. **`updateorcreate` matches on `customerReference` alone**, so it cannot address one dossier of
   a master-sub order. That is the whole reason [06](06-dossier-lookup.md) exists.

## One working call

```bash
curl -k \
  -H "X-API-Key: $CARLO_KEY" \
  -H "Accept: application/json" \
  "https://api-carlo-test.fracht.be:4712/api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment/0?%24filter=700071%20eq%20'2800209301'&%24top=50"
```

```json
{ "seaHouseShipment": [ { "number": 683, "frachtShipmentRef": "76000016",
    "customerReference": "2800209301", "bASFBL": "BL00", "eDIID": "2800209301BL00",
    "id": 986826, "loadType": "FCL", "deliveryTerms": "Prepaid",
    "isInRecycleBin": false, "…": "115 fields in all" } ] }
```

The test key is in `config/dataProfiler-basf-*.json`. The test host's certificate does not chain
to a public root, hence `-k`.

## Regenerating these pages

[02](02-seahouseshipment.md) through [05](05-filter-properties.md) are generated from the OpenAPI
document — 04 and 05 wholly, the field tables in 02 and 03 spliced into prose. When the contract
is re-generated server-side, regenerate rather than hand-editing:

```bash
python tools/carlo_docs.py                      # fetch the live contract
python tools/carlo_docs.py path/to/docs.json    # or use a saved one
```

The prose — [01](01-calling-the-api.md), [06](06-dossier-lookup.md),
[07](07-contract-conformance.md) — is hand-written, and most of it is behaviour the OpenAPI
document does not describe: the header requirements, the filter encoding, the `$top` default, the
match semantics of `actionAttribute`, the real error envelopes. Those were established by calling
the test server, and re-checking them is a matter of calling it again.
