# IFTMIN → Carlo v3 `seaHouseShipment` — mapping spec

| | |
|---|---|
| Authority | `docs/iftmin/IFTMIN_mapping_v1.xlsx` (sheets Create / Feedback round 1 / Goods switch); `docs/iftmin/02-IFTMIN-additional-rules.md`; `docs/00-basf.md` |
| Transform library | `src/main/dw/IftminModule.dwl` |
| Entry point | `src/test/dw/BasfIftmin.dwl` |
| Fixtures | every IFTMIN interchange in `docs/example-orders` (9 FCL, 3 LCL, 9 master-sub) |
| Tests | `src/test/dw/IftminMappingTest.dwl` — `cd basf && mvn -o test` |

This document covers **the flow** — the create/cancel/FCL/LCL/master-sub routing of
`docs/00-basf.md`. The field-by-field mapping is the spreadsheet's; the module's doc comments
carry the per-field notes.

## 1. The flow

`docs/00-basf.md` line 50 settles where it lives: *"we should be able to process all three
kinds of basf iftmin messages in one big dwl mapping file"*. So the routing is in
`IftminModule.toCarloShipments`, not in the pipeline.

```
Step 0   BGM03 = 1  ->  cancelShipment          identity-only delete
         BGM03 = 4/9 -> Step 1
Step 1   one entry per IFTMIN message in the interchange
Step 2   master-sub = several messages (BL01, BL02, ...) -> the same per-message treatment
Step 3/4 FCL / LCL per message, from the presence of EQD
```

Steps 1a and 2 collapse into "one entry per message", which is the whole trick: a master-sub
interchange *is* several IFTMIN messages, where an ordinary one is a single message. Mapping
every message covers both, and each message is independently FCL or LCL.

### Master-sub detection

An interchange carrying **more than one IFTMIN message**. Confirmed by the examples: single-BL
interchanges carry `UNH03 = BL00`, master-sub interchanges carry `BL01`, `BL02`, … — one BASF
bill of lading per message, one booking overall.

Three of the nine `ms/` fixtures are master-sub (`2800231445 - AB 9`,
`2800231445 - IFTMBF (2)`, `TrisSQUID-138083512`); the other six are single-BL messages that
happen to belong to the same booking but arrive in their own interchanges.

### HouseType

| | stand-alone | master-sub |
|---|---|---|
| FCL | `BackToBack` | `BackToBack` |
| LCL | `BackToBack` | `Coloadin` |

`BackToBack` is the default (`00-basf.md`: *Default: HouseShipmentType = "BACK-TO-BACK"*). The
single exception is an LCL block of a master-sub — a co-load. The flow document writes it both
as `"Co-load in"` and `"Coloadin"`; the wire value is the enum member `Coloadin`, matching how
`BackToBack` is spelled.

`masterSub` is a property of the interchange, not of the message, so `toCarloShipment` takes it
as a parameter — a single message cannot tell whether it has siblings.

### LoadType and Scenario

`LoadType` = `FCL` when the message carries equipment (`EQD`), else `LCL`. `Scenario/Matchcode`
follows it: `BASF FCL` / `BASF LCL`.

> **Changed from v1.** The first version emitted `Scenario` only for FCL, so every LCL shipment
> arrived without a scenario. It is now unconditional.

### Cancel

`cancelShipment` emits identity only — `actionAttribute: "delete"`, `DUNSCustomer`, `BASFBL`,
`CustomerReference` — per `00-basf.md` step 1b, *"Send cancel: using CustomerRef"*.

Nothing else may go with it. Sending mapped business fields alongside a delete would push
values onto a shipment that is about to be removed, and would overwrite live data if the delete
were rejected. A cancel with no `CustomerReference` is dropped: Carlo would have nothing to
match on.

**No code 1 message exists anywhere in the example set** — the file named
`2800244026 IFTMIN Cancel.txt` is legacy TRS XML, not EDIFACT. The branch is covered by
synthetic messages in the test suite. Confirm the real shape with BASF when one arrives;
`00-basf.md` itself flags step 1b as *"HOW TO BE CONFIRMED by Robin/Niels"*.

## 2. Carrier and subcontractor matchcodes

`docs/iftmin/02-IFTMIN-additional-rules.md` in full, implemented in `carrierMatchcode` /
`subcontractorMatchcode`:

| `NAD+CA` | condition | `Master/MainCarriageAsOcean/Carrier/Matchcode` |
|---|---|---|
| `300606` | POD country is EU | `DIAMOND` |
| `300606` | non-EU, `NAD+CZ` = `20051` | `COSSHISHA1` |
| `300606` | non-EU, otherwise | `COSSHI_DE` |
| `2713158`, `292062`, `300627`, `4071504` | `NAD+CZ` = `20051` | `MSCMEDGVA1` |
| ″ | otherwise | `MSCMEDGVA` |
| `4794866` | — | `OCENETSIN3` |
| `817630` | `LOC+5` starts `DE` | `ECUWOR_DE` |
| `817630` | `LOC+5` starts `IT` | `ECUWOR_IT` |
| `817630` | `LOC+5` starts `BE`/`UK`/`FR`/`NL` | `ECUWOR_BE` |
| anything else | — | the raw `NAD+CA` number, resolved by Carlo master data |

`NAD+EP` = `4794866` → `TransportSubcontractor/Matchcode` = `OCEANHAMBU`.

The EU list is the one in that document, including the non-ISO `EU` and `XI` entries.

## 3. Dangerous goods

Per the same document's "Mapping adjustment": `DGS1001` → `dangerousGoods[].imdgClass`,
`DGS06` → `dangerousGoods[].instructionsForEmergency`. Both are emitted at the outer DG level
(the self-nested `dangerousGoods.dangerousGoods` is the Carlo master-data catalogue record, not
the shipment's DG line).

## 4. Input / output

**Input** — the whole parsed interchange, `payload.EDI.Messages.D99A.IFTMIN[]`.

**Output** — `{ "seaHouseShipment": [ … ] }`, camelCase. Carlo's JSON deserializer is
case-sensitive; `camelKeys` renders the PascalCase names the mapping is authored in (matching
the sheet's XPaths) as the camelCase the API expects. Uploading PascalCase makes Carlo silently
ignore every field.

Positional selectors (`"0890_Segment_group_18"`) are used throughout, and **every position this
module reads is verified against the real parser capture**
`docs/example-orders/fcl/2800209301_FCL_IFTMIN_ERST_9.json` — none of the positions
`tools/edifact_to_json.py` marks ESTIMATED is read here.

## 5. Test coverage

`src/test/dw/IftminMappingTest.dwl`, 43 tests.

Twenty-one interchanges are exercised — every IFTMIN interchange in `docs/example-orders`. Each
is compared against a row of `src/test/resources/example-orders/manifest.json`, which records
the message's own BASF BL, BGM code, CustomerReference and equipment count as read off the
parsed tree. The expectations (`FCL`/`LCL`, `BackToBack`/`Coloadin`, the scenario, the action,
the contract-required field set) are derived from those facts independently of the mapping, so
a wrong flow decision fails here rather than being restated.

The flow decisions are additionally called out one by one — the master-sub split, the LCL
co-load, the FCL master-sub staying back-to-back — plus the cancel branch and the derivation
units.

**`BasfIftmin.dwl` itself is covered only by compilation.** A mapping is not importable, so the
test mirrors its document expression to pin the wrapper shape; keep the two in sync.

### Scenario directories

`src/test/resources/BasfIftmin/<Scenario>/inputs/payload.json` — how the IDE preview binds
`payload`. Four are provided: `FclCreate`, `LclCreate`, `MasterSubFcl`, `MasterSubLcl`.

## 6. Open items

1. **The cancel shape is unconfirmed** (§1) — no example message, and `00-basf.md` marks it as
   to be confirmed.
2. **24 emitted fields are not attested in either contract sample.** `ForwarderName`,
   `GoodsReceiver*`, `BLRecipients`, `SendersInstructions`, `DocDeliveryInstructions`,
   `BLRemarks`, `CustomerEDIType`, `Consignor`, `FreightPayer`, `TransportSubcontractor`,
   `CustomerExportManagerAddress` and the rest come from the Create sheet's XPaths, but appear
   in neither `docs/expected_output_SeaHouseShipment.json` nor
   `docs/API v3 Sample_*.xml`. Both of those are export **dumps** of real shipments rather than
   schemas, so absence is not proof — but Carlo ignores unknown fields silently, which is
   exactly how the v1 PascalCase bug hid. **Check the names against Carlo's Swagger.**
   `docs/expected_output_ShipmentCargo.json`, by contrast, *is* a schema, which is why the
   IFCSUM mapping could be fully verified.
3. **`vgmWeightDeterminationMethod`, `containerSummary`, `financialReportingDate`** and the
   other contract fields listed as never emitted are either Carlo-derived or not present in
   IFTMIN. Worth one pass with Soloplan to confirm none of them is expected from us.
