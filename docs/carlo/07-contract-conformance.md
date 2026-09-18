# Do the mappings match the contract?

README open item 3 says:

> **24 fields the IFTMIN mapping emits are not attested in any contract sample.** They come from
> the Create sheet's XPaths but appear in neither `expected_output_SeaHouseShipment.json` nor the
> v3 XML sample — both of which are export dumps rather than schemas. Carlo ignores unknown
> fields silently. Check them against Carlo's Swagger.

This page is that check, run against
`/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json` on 2026-09-16 and **re-run on
2026-09-18**, when the live document had moved under it — see § What changed since 2026-09-16.

## Result

**Every field the three mappings emit exists in the v3 contract.**

| Mapping | Distinct keys emitted | In contract | Not in contract |
|---|--:|--:|--:|
| `InboundIftmin.dwl` | 145 | 143 | 2 |
| `InboundIftmbf.dwl` | 21 | 21 | 0 |
| `InboundIfcsum.dwl` | 12 | 12 | 0 |

(Counts as of 2026-09-18. The 2026-09-16 run read 130 / 22 / 12; the mappings themselves have
moved since, not the verdict.)

The `InboundIfcsum.dwl` row survives the v1-sheet feedback unchanged: dropping `ItemNumber`
and adding `PrelegReference` leaves the count at 12, and the container-level `EDIID` reuses a
key name already counted. `container.prelegReference` and `container.eDIID` are both defined on
`ShipmentContainer` — see `docs/expected_output_ShipmentCargo.json`.

The two exceptions are `SendDate` and `ExportItemReference`, both in one function:

```dataweave
/** Carlo `<Header>` content. */
fun carloHeader(doc) = {
    SendDate: toIsoDateTime(doc.Heading."0050_DTM"[0].DTM0102) default null,
    ExportItemReference: doc.Heading."0020_BGM".BGM0201 default ""
}
```

`carloHeader` is **never called** — `grep -rn carloHeader src/` finds only its own definition. It
is a leftover of the legacy TRS `<Header>` element (visible in
`docs/2800209301_carlo_output.json`, which still has a `Header` block beside its
`SeaHouseShipment` one). The v3 contract has no header: the envelope is
`{"seaHouseShipment": [ … ]}` and nothing else. Neither field exists in v3 or in v4.

So open item 3 resolves as: nothing the mappings send is unknown to CarLo, and the one piece of
code that would have sent unknown fields is dead. It can go.

## Method, and what it does not prove

Two independent checks:

1. **Static key extraction.** Strip comments from each `.dwl`, collect every
   `Identifier:` that starts an object-literal entry, and look each up in the set of all 492
   distinct field names the contract defines across its 54 schemas. Case-insensitive, because the
   mappings write PascalCase and `camelKeys` lower-cases the first letter on the way out.
2. **Structural validation of a real output.** Walk `docs/2800209301_carlo_output.json` (a
   captured IFTMIN result) and `docs/2800209301_iftmbf_carlo_output.json` against the contract
   tree, checking each field **at its own nesting level** and each `maxLength`. Zero errors in
   both, other than the dead `Header` block.

Check 1 is flat: it proves a name exists *somewhere* in the contract, not that it is legal where
the mapping puts it. Check 2 covers nesting but only for the two captured payloads. Between them
they cover every field the IFTMIN and IFTMBF mappings emit, but a field that is correctly named
and wrongly nested in a branch neither capture exercises would still slip through.

What neither check covers:

- **Enum values.** The contract types `movementType`, `houseType`, `loadType` and friends as bare
  `string` with no `enum`, so nothing here can validate them. The values the mappings emit are
  cross-checked against live GET responses instead —
  [02-seahouseshipment.md § Values the contract does not enumerate](02-seahouseshipment.md#values-the-contract-does-not-enumerate).
- **Master-data references.** A `matchcode` that does not resolve to a record in CarLo — an HS
  code, a container type, an organizational unit — is a `400` at runtime, not a schema problem.
- **Whether CarLo does the right thing with a field it accepts.** That is what the test system is
  for.

## Reproducing it

```
python - <<'EOF'
import json, re
spec = json.load(open('docs.json', encoding='utf-8'))
valid = {k.lower() for s in spec['components']['schemas'].values()
                   for k in (s.get('properties') or {})}
for f in ['src/main/dw/InboundIftmin.dwl','src/main/dw/InboundIftmbf.dwl','src/main/dw/InboundIfcsum.dwl']:
    txt = open(f, encoding='utf-8').read()
    txt = re.sub(r'//.*', '', re.sub(r'/\*.*?\*/', '', txt, flags=re.S))
    keys = set(re.findall(r'(?m)(?:^|[\s({,])([A-Z][A-Za-z0-9]*)\s*:', txt))
    print(f, sorted(k for k in keys if k.lower() not in valid))
EOF
```

with `docs.json` fetched from
`https://api-carlo-test.fracht.be:4712/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json`.
Worth re-running whenever the contract is re-generated server-side — CarLo drops unknown fields
in silence, so a renamed field is a mapping that quietly stops populating something.

## What changed since 2026-09-16

Re-run on 2026-09-18 against the same URL. The verdict above still holds — every field the three
mappings emit still exists in the contract — but the document underneath had moved in four
places, and the other pages in `docs/carlo/` have been corrected to match:

| Change | Where | Consequence |
|---|---|---|
| `changedByAPI` (`boolean`) added to `ShipmentCargo`, `ShipmentContainer` and `ShipmentCargoDangerousGoodsData` | [04-schemas.md](04-schemas.md), [03-shipmentcargo.md](03-shipmentcargo.md) | none — no mapping writes it; it takes the distinct-field-name count from 491 to 492 |
| `ShipmentCargo.mRN` `maxLength` 255 → **50** | [04-schemas.md](04-schemas.md), [03-shipmentcargo.md](03-shipmentcargo.md) | the IFCSUM mapping writes `mRN`; the captured MRNs are 18 characters, so it fits, but the margin is much smaller than the page claimed |
| `ShipmentCargo` `MRN` filter id `700139` → **`5745430`** | [05-filter-properties.md](05-filter-properties.md) | `700139` is not in the document at all any more. A filter on a withdrawn id is **silently dropped**, so anything still filtering cargo lines by MRN was quietly reading the unfiltered set |
| v4 diverges from v3 in four schemas, not one | § v3 versus v4 below | the earlier "the mappings would work unchanged against v4" no longer holds — see below |

Nothing in `src/` needed changing: the mappings emit none of the added, removed or re-typed
fields, and `mvn -o test` is unaffected. The behavioural notes in
[01-calling-the-api.md](01-calling-the-api.md) (status codes, `Accept`/`Content-Type` handling,
`$top`, the `+`-vs-`%20` trap) were **not** re-tested on 2026-09-18 — they need live calls, not
the swagger, and still carry their 2026-09-16 date.

## v3 versus v4

The host also serves `PolytraSeafreightHouseShipment_BASF_NV_20260910-v4`. Both documents have
the same 54 schemas under the same names, and v4 only ever *removes* properties — it gains
nothing. But the removals are wider than this page used to say. As of 2026-09-18 four schemas
differ:

| Schema | Fields v4 drops |
|---|---|
| `SeaHouseShipment` | `shipperTAXID`, `consigneeTAXID`, `notify1TAXID`, `notify2TAXID`, `notify3TAXID`, `lCNumber`, `aCIDNumber`, `preCarriageMeansofTransport` |
| `OceanCarriage` | `customerPOL`, `customerPOD`, `customerPlaceofDelivery` |
| `LocationCode` | `country` |
| `RoadCarriage` | `haulage` |
| `ShipmentCargo`, `ShipmentContainer`, `ShipmentCargoDangerousGoodsData` | `changedByAPI` |

**This changes the migration answer.** `InboundIftmin.dwl` emits all three `OceanCarriage`
fields — `CustomerPOL`, `CustomerPOD` and `CustomerPlaceofDelivery`, in `MainCarriageAsOcean`
(the LOC 5 / LOC 12 / place-of-delivery routing) — so moving to v4 as the mappings stand would
**silently drop the ocean routing**, since CarLo ignores unknown fields without a warning. None
of the other removals touches the mappings: no mapping emits `haulage`, none puts a `Country`
inside a `LocationCode` (the `Country` blocks they do write sit on `AddressWithAppendix` /
`BusinessPartnerAddress`, which keep it), and none writes `changedByAPI` or any of the eight
`SeaHouseShipment` fields.

So v4 remains a *narrower* contract rather than a newer one, and moving to it is still a
question of which integration profile BASF should be on — but it is no longer a free change of
path prefix (`/api/PolytraSeafreightHouseShipment_BASF_NV_20260910/v4/…`). Ask BASF where the
ocean routing is meant to go under v4 before switching.

Two other sibling contracts on the same host are worth knowing about but are not this
integration: `PolytraSeafreightHouseMasterShipmentEvents_BASF_IFTSTA-v1` (outbound status events)
and `PolytraSeafreightHouseShipment_BASF-v2` (the predecessor). The full list is in the Swagger
UI's contract dropdown.
