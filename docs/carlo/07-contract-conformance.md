# Do the mappings match the contract?

README open item 3 says:

> **24 fields the IFTMIN mapping emits are not attested in any contract sample.** They come from
> the Create sheet's XPaths but appear in neither `expected_output_SeaHouseShipment.json` nor the
> v3 XML sample — both of which are export dumps rather than schemas. Carlo ignores unknown
> fields silently. Check them against Carlo's Swagger.

This page is that check, run against
`/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json` on 2026-09-16.

## Result

**Every field the three mappings emit exists in the v3 contract.**

| Mapping | Distinct keys emitted | In contract | Not in contract |
|---|--:|--:|--:|
| `InboundIftmin.dwl` | 130 | 128 | 2 |
| `InboundIftmbf.dwl` | 22 | 22 | 0 |
| `InboundIfcsum.dwl` | 12 | 12 | 0 |

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
   `Identifier:` that starts an object-literal entry, and look each up in the set of all 491
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

## v3 versus v4

The host also serves `PolytraSeafreightHouseShipment_BASF_NV_20260910-v4`. This repo targets v3,
and the difference is small and in one direction:

- `ShipmentCargo` is **identical** in both.
- All 54 component schemas are identical in both.
- `SeaHouseShipment` **loses** eight fields in v4 and gains none:
  `shipperTAXID`, `consigneeTAXID`, `notify1TAXID`, `notify2TAXID`, `notify3TAXID`,
  `lCNumber`, `aCIDNumber`, `preCarriageMeansofTransport`.

None of the three mappings emits any of the eight, so the mappings would work unchanged against
v4 — only the path prefix changes
(`/api/PolytraSeafreightHouseShipment_BASF_NV_20260910/v4/…`). v4 is a *narrower* contract, not a
newer one, so moving to it is a decision about which integration profile BASF should be on rather
than an upgrade.

Two other sibling contracts on the same host are worth knowing about but are not this
integration: `PolytraSeafreightHouseMasterShipmentEvents_BASF_IFTSTA-v1` (outbound status events)
and `PolytraSeafreightHouseShipment_BASF-v2` (the predecessor). The full list is in the Swagger
UI's contract dropdown.
