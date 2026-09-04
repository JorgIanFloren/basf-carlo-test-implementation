# IFTMBF → Carlo v3 — mapping spec

Canonical spec for the **second** mapping of the BASF integration: BASF **IFTMBF** (firm booking)
→ the same Carlo (Soloplan) v3 `seaHouseShipment` endpoint the IFTMIN mapping targets.

| | |
|---|---|
| Authority | `docs/iftmbf/IFTMBF_mapping_v1.xlsx`, single worksheet **"Update"** |
| Mapping | `src/main/dw/BasfIftmbf.dwl` — one self-contained script, deployed as `basf/BasfIftmbf.dwl` |
| Fixture | every IFTMBF interchange in `docs/example-orders`, converted by `tools/edifact_to_json.py` |
| Tests | `src/test/dw/IftmbfMappingTest.dwl` — `cd basf && mvn -o test` |
| Rendered sample | `docs/2800209301_iftmbf_carlo_output.json` |

## 1. Role of the message

IFTMIN **creates** the shipment; IFTMBF **updates** it. The sheet marks BGM0201 "(searchfield)",
and `actionAttribute: "updateorcreate"` makes an unaddressed call an upsert, so a booking that
arrives before its IFTMIN still lands.

That is why the sheet is so sparse — and why this mapping emits **only** what the sheet maps
(plus the contract-required fields in §3). Emitting unmapped fields on an update would overwrite
shipment data with booking-stage values.

### One booking, one update per dossier

`CustomerReference` alone is **not** enough to address a record, and that is issue 2 in
`00-basf.md` §Issues. A booking describes the whole order and carries no BL of its own, so for a
master-sub order whose IFTMIN already created BL01 and BL02 there are *two* dossiers the single
booking has to reach. Emitting one update left the booking data on only one of them.

Steps 1 and 2 of the flow say so directly: GET the dossiers of the order, then *"For each dossier
in the result of step 1 — PUT DOSSIER (By CustomerRef and BL ID)"*. So the lookup response the
pipeline puts on `payload.lookup` (see `config/README.md` check 6) decides how many calls one
booking becomes:

| Lookup result | Emitted |
|---|---|
| *n* dossiers | *n* updates — the same mapped values addressed to each in turn, `actionAttribute: "update"` |
| 0 dossiers | one upsert, no address — the booking arrived first and creates the dossier |
| no lookup at all | one upsert, no address — the pre-lookup behaviour |

The mapped values are necessarily identical across the copies; only the address differs. It is
taken from the dossier and never from the message — `Id`, `BASFBL` and `EDIID`, none of which the
booking itself knows. The BL-less dossier the 0-result case creates is the one
`BasfIftmin.dwl` later re-purposes when the IFTMIN arrives; see that spec's *"Carrying an earlier
IFTMBF forward"*.

Both halves of the address must match **exactly** — the reference *and*, where the dossier has
one, the BL. A dossier of a different order that merely shares a reference prefix, or a dossier
of the right order but the wrong BL, is treated as no match: applying either would update the
wrong record. See §8 for the two guards that hold this.

## 2. Field mapping

| # | Source (EDIFACT) | Where in the parsed JSON | Carlo target | Emitted |
|---|---|---|---|---|
| 1 | `UNB` sender id | `Interchange.UNB0201` | `DUNSCustomer` | `"BASFAG2"` |
| 2 | `BGM+335+2800209301+9` | `Heading.<BGM>.BGM0201` | `CustomerReference` *(searchfield)* | `"2800209301"` |
| 3 | `LOC+10+DELUH:::Ludwigshafen` | LOC group under any TDT stage, `LOC01 == "10"` | `PickupLocation/PickupLocation/UnLocationCode/Matchcode` ← `LOC0201` | `"DELUH"` |
| 4 | ″ | ″ | `PickupLocation/PickupLocation/Address/Location1` ← `LOC0204` | `"Ludwigshafen"` |
| 5 | `DTM+132:20260508:102` under `TDT+20` | main-carriage stage, `DTM0101 == "132"` | `Master/MainCarriageAsOcean/CustomerETA` | `"2026-05-08"` |
| 6 | `DTM+180:20260415:102` under `TDT+20` | ″ , `DTM0101 == "180"` | `Master/MainCarriageAsOcean/CustomerClosing` | `"2026-04-15"` |
| 7 | `NAD+CZ+1000+…` | header NAD group, `NAD01 == "CZ"` → `NAD0201` | `Customer/Matchcode` *(conversion)* | `"1000"` |
| 8 | `FTX+ITR+++08.04.2026` | first EQD group, `FTX01 == "ITR"` | `EstimatedDispatchDate` | `"2026-04-08T00:00:00"` |
| 9 | — constant — | — | `ObjectOwner/OrganisationalUnitId` | `5` |
| 10 | `EQD` present? | header EQD groups | `Scenario/Matchcode` | `"BASF FCL"` / `"BASF LCL"` |
| 11 | `TMD03` + `LOC+20` | first EQD group's TMD; LOC+20 across stages | `HaulageType/Matchcode` | `"CAR/CAR"` |

**Derivations**

- **HaulageType** = `<pre-carriage>/<on-carriage>`. Pre-carriage: `TMD+…+1` → `CAR`, `TMD+…+2` →
  `MER` (fallback: the C219 description containing "Carrier"; then `MER`). On-carriage: `LOC+20`
  present → `CAR`, absent → `MER`. First occurrence only; omitted entirely when there is no TMD.
  The sheet's fourth clause reads `MER/CAR ← TMD+…+2/TMD+…+1`, which is a typo — the other three
  clauses all derive slot 2 from `LOC+20`, and the four combinations exhaust the 2×2 space.
- **Scenario** = `EQD` present → `BASF FCL`, else `BASF LCL`.
- **EstimatedDispatchDate**: the date is pulled out of the FTX free text. Accepted spellings per
  the sheet: `DD.MM.YYYY`, `DD/MM/YYYY`, `DD-MM-YYYY`, `DD MM YYYY`.
- **Date formats on the wire**: `CustomerETA` / `CustomerClosing` / `ShipmentDate` are date-only
  `YYYY-MM-DD` (matching the `customerETD` Carlo already accepts); `EstimatedDispatchDate` is a
  dateTime `…T00:00:00` (the v3 sample renders it as `2025-12-02T15:00:00`). The sheet's
  "DD/MM/YYYY" notation describes the Carlo UI / the BASF side, not the wire format.
- **DTM disambiguation**: `DTM+132` occurs under both `TDT+20` (20260508) and `TDT+30` (20260512).
  Only the main-carriage stage feeds `CustomerETA`.

## 3. Emitted but not in the sheet

Three fields the Carlo contract needs; all carry the same values `BasfIftmin.dwl` already sends for
this shipment, so the update cannot change them:

| Field | Value | Why |
|---|---|---|
| `actionAttribute` | `"update"` whenever a dossier was resolved; otherwise from BGM03 (`4`/`5`→update, else `updateorcreate`; `1` never reaches here) | selects update-vs-create; without it Carlo applies its default and each booking creates a duplicate |
| `DeliveryTerms` | `"Prepaid"` | contract-required top-level field |
| `ShipmentDate` | `DTM+133` of `TDT+20` → `"2026-04-20"` | contract-required top-level field; same source IFTMIN uses |

Plus the three identity fields of §1 — `Id`, `BASFBL`, `EDIID` — emitted only when the lookup
resolved a dossier, and copied from it rather than derived from the message. A resolved dossier
forces `"update"` because the record demonstrably exists: leaving `updateorcreate` in place would
let a mis-addressed call create a duplicate instead of failing.

The required set is `DeliveryTerms, ShipmentDate, ObjectOwner, Customer, Master`. Of these,
`DeliveryTerms`, `ObjectOwner` and `Master` are unconditional; **`Customer` and `ShipmentDate` are
emitted only when their source segment is present** (`NAD+CZ`, `DTM+133` of `TDT+20`). That is
deliberate — on an update, `Customer: { Matchcode: null }` could blank the customer on the
existing shipment, which is worse than the 400 Carlo returns for a missing one. A booking without
`NAD+CZ` is a data error and should surface as a rejected call.

`ShipmentDate` intentionally does **not** reuse `BasfIftmin.dwl`'s `DTM+137` fallback: the message
date would overwrite the real ETD that IFTMIN set. `Master` is always present but its
`MainCarriageAsOcean` child is omitted when neither date is available, so the update never sends a
blank carriage node.

## 4. Deliberately not mapped

- **`TDT+10++60+11` (pre-carriage mode of transport)** — the sheet row is highlighted yellow,
  "Mode of transport - waiting Soloplan v3.07". No target XPath exists yet. **TODO** once Soloplan
  ships it.
- The **in-app logic** in column E (copy Customer ETD → ETD when ETD is empty) happens inside
  Carlo, not in the transform.
- Everything else in the message: other parties, goods items, dangerous goods, containers, ports,
  CNT totals, RFF SI/CT. Unmapped in the sheet; see §1 for why that matters on an update.

## 5. Input / output

**Input** — parsed IFTMBF JSON at `payload.EDI.Messages.D08A.IFTMBF[0]` (`UNH+…+IFTMBF:D:08A:UN`).
Only `Messages` carries value; `Errors`, `Delimiters` and `FunctionalAcks*` are ignored.

**Output** — `{ "seaHouseShipment": [ { … } ] }`, camelCase (Carlo's deserializer is
case-sensitive; `camelKeys` from `BasfIftmin.dwl` renders the PascalCase names the mapping is
authored in). A message with no `CustomerReference` yields `{ "seaHouseShipment": [] }` rather
than an identity-less shipment that this upsert endpoint would turn into a junk record.

## 6. Why this module navigates by segment name, not position key

The EDI parser prefixes every key with the message-structure position (`"0020_BGM"`,
`"0460_Segment_group_10"`). Those numbers are **directory-specific**, and IFTMBF D08A renumbers
almost every group relative to IFTMIN D99A:

| Meaning | IFTMIN D99A | IFTMBF D08A |
|---|---|---|
| Transport stage (TDT) group | SG8 @0460 | SG7 @0360 |
| LOC under TDT | SG9 @0500 | SG8 @0400 |
| Header parties (NAD) | SG11 @0560 | SG10 @0460 |
| Goods item (GID) | SG18 @0890 | SG16 @0700 |
| Equipment (EQD) | SG37 @1640 | SG32 @1260 |
| Equipment party (NAD) | SG39 @1840 | SG33 @1370 |

Two numbers even **collide with a different meaning**: `Segment_group_32` is the goods-item DGS
group in D99A but the equipment group in D08A; `Segment_group_18` is the goods item in D99A but
the item MEA group in D08A. Selectors copied from `BasfIftmin.dwl` would therefore have selected the
wrong data silently.

So `BasfIftmbf.dwl` matches segments on their `_<SEGMENT>` key suffix and walks groups
structurally — `groupsWith(node, "NAD")` means "the direct child group that contains NAD segments":

| Helper | Purpose |
|---|---|
| `segs(node, name)` / `seg1` | direct-child segments named `<name>`, always as an array |
| `subGroups(node)` | direct-child segment-group repeats, flattened |
| `groupsWith(node, seg)` | the direct-child group identified by the segment it carries |
| `body`, `stages`, `stage`, `locsOf`, `anyLoc`, `stageDtm`, `parties`, `nad`, `equipments` | the navigation this mapping needs |

Because it only ever looks at **direct** children, header parties (SG10, a direct child of
`Heading`) can never be confused with equipment parties (SG33, two levels down inside SG32) or
with the DG contact CTA (SG28, inside SG27 inside SG16). Every helper is null-safe: a missing
segment or group degrades to an omitted key, never an error.

## 7. Open items

1. **`PickupLocation/PickupLocation/UnLocationCode/Matchcode` and `.../Address/Location1`** are
   taken verbatim from the sheet (cell C26) but are **not attested** in the v3 contract sample.
   That sample shows a *flat* `PickupLocation` business partner using `LocationCode`
   (`{Matchcode, Designation, CityCode}`) and `Addresses` (plural). The sample is an export dump of
   a different customer and is already known to omit import-only elements (`DUNSCustomer`,
   `CustomerETA`, `ExportCarrier` are all absent from it yet real), so the sheet is followed as
   written. **Confirm with Soloplan before go-live.**
2. **`PickupLocation` merge behaviour.** IFTMIN writes `pickupLocation.exportCarrier.matchcode`;
   this update writes a sibling under the same node. If Carlo replaces the node wholesale instead
   of merging, the IFTMIN-set export carrier is lost. Needs one round-trip test.
3. **Row 26 label transposition.** Column D reads "1. Loading Place / 2. Loading Place (Code)"
   while the coloured values are `DELUH` then `Ludwigshafen`. The left-to-right convention is
   followed (`DELUH` → the code element, `Ludwigshafen` → the address line), which is the only
   reading that puts a UN/LOCODE into a matchcode. The labels in column D are simply swapped.
4. **`Master/PreferredModeOfTransport`** is not emitted (IFTMIN sets it to `"Ocean"` on the same
   shipment). Add it if Carlo turns out to need the discriminator to bind `MainCarriageAsOcean`.
5. **Platform inbound config.** `config/InboundIftMin.json` exists (currently empty); a matching
   `InboundIftMbf` route/config is presumably needed on the Fracht Connect side.
6. **Two fields go blank on an LCL booking.** With no `EQD` there is no equipment group, so
   neither `HaulageType` (no `TMD` — the sheet's 2×2 table never covers the TMD-absent case, even
   though its `LOC+20` clause could still yield the on-carriage slot) nor `EstimatedDispatchDate`
   (no equipment `FTX+ITR`) can be derived. Note the header `FTX+ACB` carries the same loading
   date — "Planned Loading Date: 08.04.2026", sheet row 19 — but the sheet leaves it unhighlighted,
   so it is not mapped. Omitting a field on an update is the safe failure mode, so no code change
   is made on the strength of the sheet alone. **Ask BASF/Soloplan what LCL bookings should do.**
7. **Function-name overlap with `BasfIftmin.dwl`** (`stages`, `stage`, `mainStage`, `parties`, `nad`,
   `haulageType`, `shipmentAction` exist in both with different semantics). Safe today because
   every importer uses selective imports, but `import * from` both modules in one file would be
   ambiguous. Worth a prefix on the next touch.

## 8. Test coverage

`src/test/dw/IftmbfMappingTest.dwl`, run by `cd basf && mvn -o test`.

Nine IFTMBF interchanges are exercised — every one in `docs/example-orders` (4 FCL, 1 LCL,
4 master-sub). Each is checked against a row of `src/test/resources/example-orders/manifest.json`,
which records the message's own BGM code, CustomerReference and equipment count as read off the
parsed tree, so the expectations are derived independently of this mapping.

Beyond the per-fixture comparison the suite covers the sheet-mapped values against the richest FCL
booking, the LCL gap of §7.6, the cancel branch, the degenerate-input guards, the
`MainCarriageAsOcean` emptiness guard, every `HaulageType` combination, both `Scenario` branches,
every `BGM03` action and the date parser's reject cases.

**"nothing unmapped leaks" is the load-bearing test.** It asserts, for every fixture, that the
emitted key set is a subset of the twelve fields §2 and §3 allow. On an update, an extra field is
not a cosmetic problem — it overwrites shipment data with booking-stage values.

**`BasfIftmbf.dwl` is covered end to end, script included.** The suite runs it through
`evalPath`, exactly as the data-transformer evaluates the uploaded file, and asserts on the JSON
Carlo would receive — so the output header, the document body and every inlined helper are all
under test. Nothing is imported from the mapping and nothing about it is mirrored in the test,
so there is no wrapper shape to keep in sync.

### Scenario directories — how the IDE preview binds `payload`

Scenario directories add no tests to `mvn -o test` yet, but they are **not** decoration. They are
how the DataWeave IDE / preview runner binds the `payload` variable — without one, running
`BasfIftmbf.dwl` in the preview fails with `Unable to resolve reference of: 'payload'` — and they
are what `inputsFrom()` / `outputFrom()` read if a whole-document golden test is added (drop a
reviewed `out.json` beside `inputs/`). The layout is
`src/test/resources/<MappingFileName>/<ScenarioName>/inputs/<variableName>.json`, where each file
in `inputs/` is bound as a variable of that name:

| Scenario | Input |
|---|---|
| `BasfIftmbf/FclBooking/` | `fcl/2800209301-iftmin-absch-9.json` — containers, TMD, FTX+ITR |
| `BasfIftmbf/LclBooking/` | `lcl/2800226066-iftmbf-9.json` — no equipment, so §7.6 applies |

## 9. Fixtures

Fixtures are generated, not hand-written: `python tools/edifact_to_json.py --all` converts every
EDIFACT interchange under `docs/example-orders` into the JSON shape the Fracht Connect EDI parser
produces, writing `src/test/resources/example-orders/` plus `manifest.json`. Re-run it whenever
the example set changes. See `README.md` §Fixtures for how faithful that conversion is and how it
was verified.

The reconstructed hand-built fixture the previous version of this spec described is gone, and so
is the "real captures fail to parse" caveat that went with it — see below.

## 10. Resolved: the upstream parse failure

The previous version of this spec recorded that every real IFTMBF capture failed to parse, so only
a hand-reconstructed fixture could exercise the mapping. The cause was `NAD+CA` carrying CMA CGM's
Marseille address *4 Quai d'Arenc*: in EDIFACT `'` terminates a segment, so a literal apostrophe in
data is escaped `?'`, and in the newline-delimited flavour of these captures that escape survives
as a trailing `?` before the line break. The production parser treats the result as a stray CR
inside `NAD05` and rejects the message.

`tools/edifact_to_json.py` handles it (`split_segments`): a line ending in an unconsumed release
character continues onto the next line with a literal apostrophe. Real IFTMBF captures therefore
parse cleanly here, and all nine are used as fixtures.

**This does not fix production.** The interchange writer on the BASF side is still emitting `?`
followed by CRLF where it should emit `?'`, and the production parser still rejects those messages
(`UCM03: 4`). Evidence is kept at `docs/iftmbf/2800209301_FCL_IFTMBF_real_parse_failed.json`. The
related non-fatal `EQD03` "data element too long (36 > 35)" errors are the CP1252/UTF-8
double-encoding inflating `40´ Reefer 9´6"…` from 34 characters to 36 — same root cause class.
**Both belong at the sender; raise them with BASF.**
