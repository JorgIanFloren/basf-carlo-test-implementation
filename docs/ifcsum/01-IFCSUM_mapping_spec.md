# IFCSUM → Carlo v3 `shipmentCargo` — mapping spec

Third of the three BASF inbound mappings, and the only one that does not target
`seaHouseShipment`.

| | |
|---|---|
| Authority | `docs/ifcsum/IFCSUM_mapping_v1.xlsx` (sheet `JSON`, rows 2-11); `docs/00-basf.md` §IFCSUM; `docs/expected_output_ShipmentCargo.json` (the contract) |
| Mapping | `src/main/dw/InboundIfcsum.dwl` — one self-contained script, deployed as `basf/InboundIfcsum.dwl` |
| Fixtures | every IFCSUM interchange in `docs/example-orders/inbound` (5 FCL, 1 LCL) |
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

The six captured examples come in two shapes, and the mapping handles both with the same
rule:

| | FCL (5 examples) | LCL (1 example) |
|---|---|---|
| Equipment | one sea container, ISO type `45RT` / `42RT` | a truck, `Truck with removable tarp` |
| `MEA WT/AAB` "VGM" | verified gross mass | — |
| `SEL` | seal number | — |
| `NAD+AM` | VGM signatory | — |
| `RFF+AIW` | pre-leg reference | pre-leg reference (not emitted — §3.1) |
| `RFF+ABT` | customs MRN in `fcl/ifcsum-withmrn` only | customs MRN per consignment |
| `CNI` count | 1–6 | 6 |

So an FCL summary is normally a **VGM declaration** and an LCL summary an **MRN delivery**,
though `fcl/ifcsum-withmrn` carries both. Either way it is "here is new information about cargo
lines you already have".

## 3. Field mapping

One `shipmentCargo` entry per (`CNI`, `GID`) pair.

| Source | Carlo target | Sheet row | Notes |
|---|---|---|---|
| — constant — | `actionAttribute` = `"update"` | — | §1 |
| `RFF+LI` `RFF0102` | `DeliveryNoteSAP` | 2 | falls back to `CNI0201`, which repeats it |
| `RFF+LI` `RFF0103` | `DeliveryPositionNumber` | 2 | |
| `RFF+LI` `RFF0102`/`RFF0103` | `EDIID` = `"<note>/<position>"` | 2 | |
| `RFF+ABT` of the `CNI` group | `MRN` | 3 | LCL only in the captures |
| `EQD0201` | `Container/ContainerNumber` | 5 | see §4 |
| `EQD0301` | `Container/ContainerType/Matchcode` | 6 | |
| `MEA WT/AAB` `MEA0302` | `Container/VerifiedGrossMass` | 9 | emitted as a number |
| `SEL01` | `Container/SealNumber` | 7 | |
| `NAD+AM` `NAD0401` | `Container/VGMPersonInChanrge` | 4 | contract spelling, typo included |
| header `RFF+AIW` `RFF0102` | `Container/PrelegReference` | 10 | §3.1 |
| every line's `RFF+LI` | `Container/EDIID` = the lines' EDIIDs joined by `-` | 11 | §3.2 |

`GID01` is **not** mapped. It used to be emitted as `ItemNumber`; BASF's feedback on
`IFCSUM_mapping_v1.xlsx` removed it, and the sheet has no row for it. `GID01` is the goods-item
counter *within one consignment* — every captured consignment carries a single goods item, so it
is `1` on every line — and writing it would renumber the cargo line `InboundIftmin.dwl` created
rather than identify it. The delivery note, the position and `EDIID` are what address the line.

### 3.1 `Container/PrelegReference`

Sheet row 10. The source is `RFF+AIW`, which in every capture is a **header** reference (SG1,
beside `RFF+ACE`) repeating the `BGM0201` document number — `2013354401`, `2013357254`,
`2013476959` and so on. The sheet spells its XPath through the TDT group (SG9/SG16), which is
where row 2 reads `RFF+LI`; suffix navigation finds the real one either way, because `refOf`
only considers RFF groups that are direct children of the node it is given, and the TDT group
carries no `RFF+AIW`.

It is a **container** field, so an LCL summary — which has no container (§4) — reports no pre-leg
reference even though it does carry the header `RFF+AIW`.

### 3.2 `Container/EDIID`

Sheet row 11, "Same as in IFTMIN on container level": every cargo line's `"<note>/<position>"`
joined with `-`, with no trailing separator. The sheet's own example is
`3550879430/000010-3550879730/000010-3550879847/000010`, which is exactly what
`fcl/ifcsum-2013354403.json` produces.

`InboundIftmin.dwl` builds the same composite in `containerEdiid`, but it can pick *the goods
items loaded in this container* because its SG18 items name their equipment. IFCSUM carries no
`CNI`→`EQD` link, so the IFCSUM version joins every cargo line of the message. That is sound
only because guard 2 of §4 has already established there is exactly one container — with
several, no container block is emitted at all, and no `EDIID` with it.

It is built from the same `(note, position)` pair, and on the same condition, as the line-level
`EDIID`, so the container key is always precisely the join of the keys of the lines under it.

### Identity

`RFF+LI` is the key `00-basf.md` names, and it is exactly what `InboundIftmin.dwl` wrote onto the
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

Both fields added in §3.1 and §3.2 sit inside this block, so both inherit the guard: a summary
with no unambiguous container reports neither.

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
rather than a data dump. All emitted paths were checked against it, `container.prelegReference`
and `container.eDIID` included.

A message with no consignments, or a consignment with no delivery note, yields nothing rather
than an identity-less cargo line.

### Scenario directories — how the IDE preview binds `payload`

Scenario directories add no tests to `mvn -o test` yet, but they are **not** decoration. They are
how the DataWeave IDE / preview runner binds the `payload` variable — without one, running
`InboundIfcsum.dwl` in the preview fails with `Unable to resolve reference of: 'payload'` — and they
are what `inputsFrom()` / `outputFrom()` read if a whole-document golden test is added (drop a
reviewed `out.json` beside `inputs/`). The layout is
`src/test/resources/<MappingFileName>/<ScenarioName>/inputs/<variableName>.json`, where each file
in `inputs/` is bound as a variable of that name:

| Scenario | Input |
|---|---|
| `InboundIfcsum/FclVgm/` | `fcl/20260625-142940-681-v2.json` — one container, VGM / seal / signatory, 3 cargo lines |
| `InboundIfcsum/LclMrn/` | `lcl/ifcsum-136579804.json` — pre-carriage truck, an MRN per consignment, 6 cargo lines |

The directory name must equal the mapping **filename**, so these live under `InboundIfcsum/`. A
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
   line and the sheet has no row for it.
4. **`SEL02` → `Container/Sealnumber2`** (sheet row 8) is not mapped, and deliberately so. In
   every capture the segment reads `SEL+0024451+SH`: `SEL02` is the composite naming the party
   that affixed the seal (`SH` = shipper), not a second seal number. Mapping it as the row asks
   would write `"SH"` into a seal-number field. The row is marked `ok` on the sheet, so it was
   presumably never checked against a real message — confirm with BASF whether a second seal
   number occurs in IFCSUM at all before implementing it.
5. **The contract marks `itemNumber` as `shipmentCargo`'s only required field**
   ([`docs/carlo/03-shipmentcargo.md`](../carlo/03-shipmentcargo.md)), and §3 no longer sends
   it. BASF's feedback on the v1 sheet asked for it to go, and nothing in the six captures
   carries a value worth sending in its place — `GID01` is `1` on every line. The delivery-note
   reference is what an `update` matches on in practice, but if CarLo rejects a cargo line
   without `itemNumber`, this is the reason and the fix is a decision for BASF, not a guess
   here.
6. **`RFF+AIW` is assumed to be the pre-leg reference itself.** It repeats `BGM0201` in all six
   captures, so nothing in the example set distinguishes "pre-leg reference" from "this
   message's own document number". If BASF ever sends the two as different values, §3.1 needs
   re-checking.
