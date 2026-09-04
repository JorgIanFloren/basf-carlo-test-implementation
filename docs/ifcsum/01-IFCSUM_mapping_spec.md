# IFCSUM → Carlo v3 `shipmentCargo` — mapping spec

Third of the three BASF inbound mappings, and the only one that does not target
`seaHouseShipment`.

| | |
|---|---|
| Authority | `docs/00-basf.md` §IFCSUM; `docs/expected_output_ShipmentCargo.json` (the contract) |
| Mapping | `src/main/dw/BasfIfcsum.dwl` — one self-contained script, deployed as `basf/BasfIfcsum.dwl` |
| Fixtures | every IFCSUM interchange in `docs/example-orders` (3 FCL, 1 LCL) |
| Tests | `src/test/dw/IfcsumMappingTest.dwl` — `cd basf && mvn -o test` |

## 1. Role of the message

IFTMIN creates the shipment and its cargo lines. IFTMBF updates the booking. IFCSUM arrives
last and updates **individual cargo lines** of a shipment that already exists:

> Step 0: Fetch Shipment Cargo Line by RFF-LI id / Update fields according to mapping / Send to Server

There is no create path in that flow, which is why every emitted entry carries
`actionAttribute: "update"` rather than the `updateorcreate` the other two mappings use. An
upsert here would silently add a duplicate cargo line every time the delivery-note match
failed.

## 2. What the message actually carries

The four captured examples come in two shapes, and the mapping handles both with the same
rule:

| | FCL (3 examples) | LCL (1 example) |
|---|---|---|
| Equipment | one sea container, ISO type `45RT` | a truck, `Truck with removable tarp` |
| `MEA WT/AAB` "VGM" | verified gross mass | — |
| `SEL` | seal number | — |
| `NAD+AM` | VGM signatory | — |
| `RFF+ABT` | — | customs MRN per consignment |
| `CNI` count | 1–3 | 6 |

So an FCL summary is a **VGM declaration** and an LCL summary is an **MRN delivery**. Both are
"here is new information about cargo lines you already have".

## 3. Field mapping

One `shipmentCargo` entry per (`CNI`, `GID`) pair.

| Source | Carlo target | Notes |
|---|---|---|
| — constant — | `actionAttribute` = `"update"` | §1 |
| `GID01` | `ItemNumber` | |
| `RFF+LI` `RFF0102` | `DeliveryNoteSAP` | falls back to `CNI0201`, which repeats it |
| `RFF+LI` `RFF0103` | `DeliveryPositionNumber` | |
| `RFF+LI` `RFF0102`/`RFF0103` | `EDIID` = `"<note>/<position>"` | |
| `RFF+ABT` of the `CNI` group | `MRN` | LCL only in the captures |
| `EQD0201` | `Container/ContainerNumber` | see §4 |
| `EQD0301` | `Container/ContainerType/Matchcode` | |
| `MEA WT/AAB` `MEA0302` | `Container/VerifiedGrossMass` | emitted as a number |
| `SEL01` | `Container/SealNumber` | |
| `NAD+AM` `NAD0401` | `Container/VGMPersonInChanrge` | contract spelling, typo included |

### Identity

`RFF+LI` is the key `00-basf.md` names, and it is exactly what `BasfIftmin.dwl` wrote onto the
cargo line it created — as `DeliveryNoteSAP`, `DeliveryPositionNumber` and
`EDIID` (`"<note>/<position>"`). All three are emitted so Carlo can match on whichever it
indexes.

## 4. The container guard

`soleContainer` emits the container block only when **both** hold:

1. **The equipment has an ISO type code (`EQD0301`).** An LCL summary describes the truck that
   ran the consignments to the terminal, not the container the cargo sits in. Writing a truck
   onto a cargo line would be wrong, and `EQD0301` is what distinguishes the two — the truck
   entry has none.
2. **There is exactly one such container.** Nothing in the message links a consignment to a
   specific piece of equipment. With one container the link is unambiguous; with several it
   would be a guess, so the block is omitted rather than risk attaching one container's VGM to
   another container's cargo.

Every captured example carries exactly one piece of equipment, so guard 2 has never fired. See
§7.

## 5. Cancel

A code 1 IFCSUM contributes nothing — `toCarloCargoUpdates` drops it.

Cancelling a consolidation summary does not cancel the underlying cargo, and this mapping has
no safe way to undo a VGM or an MRN it previously sent (blanking those fields is not the same
as "the summary was withdrawn"). As with IFTMBF the flow simply stops. If BASF needs a cancel
to clear those fields, it has to be specified rather than inferred. No code 1 IFCSUM exists in
the example set.

## 6. Input / output

**Input** — the whole parsed interchange, `payload.EDI.Messages.D08A.IFCSUM[]`. Navigation is by
`_<SEGMENT>` key suffix (the inlined navigation helpers), not by position key; see
`docs/iftmbf/01-IFTMBF_mapping_spec.md` §6 for why that matters in D08A.

**Output** — `{ "shipmentCargo": [ … ] }`, camelCase. Every field emitted is present in
`docs/expected_output_ShipmentCargo.json`; that file is a Swagger schema example (placeholder
values throughout), so unlike the `seaHouseShipment` contract it is an authoritative field list
rather than a data dump. All twelve emitted paths were checked against it.

A message with no consignments, or a consignment with no delivery note, yields nothing rather
than an identity-less cargo line.

### Scenario directories — how the IDE preview binds `payload`

Scenario directories add no tests to `mvn -o test` yet, but they are **not** decoration. They are
how the DataWeave IDE / preview runner binds the `payload` variable — without one, running
`BasfIfcsum.dwl` in the preview fails with `Unable to resolve reference of: 'payload'` — and they
are what `inputsFrom()` / `outputFrom()` read if a whole-document golden test is added (drop a
reviewed `out.json` beside `inputs/`). The layout is
`src/test/resources/<MappingFileName>/<ScenarioName>/inputs/<variableName>.json`, where each file
in `inputs/` is bound as a variable of that name:

| Scenario | Input |
|---|---|
| `BasfIfcsum/FclVgm/` | `fcl/20260625-142940-681-v2.json` — one container, VGM / seal / signatory, 3 cargo lines |
| `BasfIfcsum/LclMrn/` | `lcl/ifcsum-136579804.json` — pre-carriage truck, an MRN per consignment, 6 cargo lines |

The directory name must equal the mapping **filename**, so these live under `BasfIfcsum/`. A
directory named after a file that no longer exists silently binds nothing.

## 7. Open items

1. **Multi-container summaries.** §4 guard 2 has never been exercised. If BASF ever sends one
   IFCSUM covering several containers, the mapping will silently omit the container block for
   every cargo line — the VGM data would be lost, not mis-assigned. Ask BASF whether that case
   occurs and, if so, what links a `CNI` to an `EQD`.
2. **`vgmWeightDeterminationMethod` is not derivable.** The `seaHouseShipment` contract sample
   shows `"SM2"` on the container, but nothing in IFCSUM carries a determination method.
   Confirm whether Carlo needs it alongside `VerifiedGrossMass`.
3. **`RFF+ACE`** (`YE45` in every example) is not mapped. It looks like the EDI-type code the
   IFTMIN mapping reads out of `FTX+ABO` (`YE22`), but there is no target for it on a cargo
   line and no sheet to confirm against.
4. **There is no IFCSUM mapping sheet.** `docs/ifcsum/` holds this spec and nothing else — the
   mapping above is derived from `00-basf.md`, the contract, and what the four captures
   actually contain. If BASF/Soloplan produce an `IFCSUM_mapping_v1.xlsx` like the other two
   messages have, re-check this mapping against it.
