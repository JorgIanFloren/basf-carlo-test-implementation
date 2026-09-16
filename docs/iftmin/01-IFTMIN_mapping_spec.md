# IFTMIN → Carlo v3 `seaHouseShipment` — mapping spec

| | |
|---|---|
| Authority | `docs/iftmin/IFTMIN_mapping_v1.xlsx` (sheets Create / Feedback round 1 / Goods switch); `docs/iftmin/02-IFTMIN-additional-rules.md`; `docs/00-basf.md` |
| Mapping | `src/main/dw/BasfIftmin.dwl` — one self-contained script, deployed as `basf/BasfIftmin.dwl` |
| Fixtures | every IFTMIN interchange in `docs/example-orders` (9 FCL, 3 LCL, 9 master-sub) |
| Tests | `src/test/dw/IftminMappingTest.dwl` — `cd basf && mvn -o test` |

This document covers **the flow** — the create/cancel/FCL/LCL/master-sub routing of
`docs/00-basf.md`. The field-by-field mapping is the spreadsheet's; the mapping's doc comments
carry the per-field notes.

## 1. The flow

`docs/00-basf.md` line 50 settles where it lives: *"we should be able to process all three
kinds of basf iftmin messages in one big dwl mapping file"*. So the routing is in
``BasfIftmin.dwl`'s `toCarloShipments``, not in the pipeline.

```
Step 0   BGM03 = 1  ->  recycleShipments        one identity-only recycle per dossier
         BGM03 = 4/9 -> Step 1
Step 1   one entry per IFTMIN message in the interchange, each addressed at the dossier
         the CustomerRef lookup resolved for its own BL
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

### Which dossier an entry updates

Every entry is addressed at a specific record, resolved from the "GET dossier by CustomerRef"
response the pipeline puts on `payload.lookup` (see `config/README.md` check 6). This is what
fixes the three master-sub defects in `00-basf.md` §Issues.

**`CustomerReference` identifies the order, never the dossier.** Both subs of a master-sub carry
the same one — `2800231445` for BL01 and BL02 alike — so matching on it alone resolves the
second sub onto the first sub's record and BL02 silently overwrites BL01. That was issue 1. The
BL comes from `UNH03`, and the composite is emitted as `EDIID`:

```
EDIID = CustomerReference ++ BASFBL      "2800231445BL01"
```

That form is not invented here: it is how the field reads on every real record in
`docs/get-responses/`, without exception — `2800226066BL00` for a plain order, `2800231445BL01`
and `2800231445BL02` for the subs of a master-sub, and the bare reference on a dossier an IFTMBF
created alone.

`targetDossier` resolves in two steps:

1. **Exact `CustomerReference` + `bASFBL` match** — the normal case, and proposed solution 1.
2. Failing that, **the lone BL-less dossier of the order.** Only an IFTMBF that arrived before
   any IFTMIN can have created such a record, since IFTMBF carries no BL at all. The IFTMIN
   re-purposes it rather than leaving it orphaned beside a fresh one — the flow document's
   preferred option, *"Idealy we would repurpose the existing dossier"*, which also means
   nothing has to be moved to the recycle bin. For a master-sub interchange only the **first**
   BL may claim it; every later sub is created.

A resolved dossier contributes its `Id` and forces `actionAttribute: "update"` whatever BGM03
says — the record demonstrably exists, so leaving `updateorcreate` in place would let a
mis-addressed call create a duplicate instead of failing. Two BL-less dossiers for one order is
deliberately treated as no match: the flow has no rule for it, and creating fresh records is
safer than picking one arbitrarily.

### Carrying an earlier IFTMBF forward

The second half of proposed solution 3, and the rest of issue 3. When a booking ran first, its
values sit on that one BL-less dossier; the arriving IFTMIN re-purposes it for the first sub, but
every *other* sub is a brand-new record that would carry no booking data at all.

`bookingCarryForward` reads those values once — the lookup is a single response, so there is
nothing to re-fetch per message — and `mergeUnder` lays them under every sub. The set is exactly
the fields `BasfIftmbf.dwl` maps that this mapping does not, verified against the captures rather
than assumed: `estimatedDispatchDate`, the pickup UN/LOCODE and place name, `haulageType`, and
the carrier's `customerETA` / `customerClosing`. All are present on every
`iftmbf-before-iftmin-*.json` and absent from every `iftmin-before-iftmbf-*.json`.

`mergeUnder` is a deep merge in which **the message always wins**, so the cache can only fill
gaps and can never push booking-stage values over what the order says. It has to be a deep merge
rather than `++`: IFTMBF writes `pickupLocation.pickupLocation` while this mapping writes
`pickupLocation.exportCarrier`, and both write inside `master.mainCarriageAsOcean` — the booking
contributing the carrier's ETA, the message the vessel, ports and ETD. Replacing either node
wholesale would drop half of it. It runs *after* `camelKeys`, because the cached fragment comes
back from Carlo already camelCase.

### LoadType, Scenario and the FCL switch

`LoadType` = `FCL` when the message carries equipment (`EQD`), else `LCL`.

`Scenario` is **no longer emitted at all.** The field is obsolete on BASF's side (spec v1.1 §16)
and real CarLo records carry `scenario.matchcode: null`. `BasfIftmbf.dwl` drops it too, or a
booking update would write back on every run what the instruction stopped sending.

`PROCESS_FCL`, a constant at the head of this mapping, decides whether FCL is processed at all.
It ships `false`: go-live carries LCL only. With it off an FCL message contributes nothing — no
create, no update and no cancel either, since a load type the integration never created is one it
must not address. A master-sub interchange is always uniformly FCL or uniformly LCL, so the filter
takes such an interchange whole or not at all. The same constant lives in `BasfIftmbf.dwl` and the
two must agree; see `docs/00-basf.md` *"FCL switch"*.

The mapping reads it through `processFcl(payload)`, which falls back to the constant when the
payload carries no `config` key — which it never does in production. That seam exists only so the
test suite can exercise both states: it runs the file through `evalPath` exactly as shipped, and
`dw::Runtime::eval`, the only route that could patch the constant, types its scope as
`Dictionary<String>` and so cannot be handed a payload.

### Cancel

`recycleShipments` emits identity plus `IsInRecycleBin: true`, and nothing else, per
`00-basf.md` *"IFTMIN / Canceling"*: **"Get the dossier(s) by `customerrefSet`, then for each
result set the property isInRecycleBin to true and upsert the record."**

So a cancel is a *recycle*, not a delete: the dossier stays in Carlo and simply drops out of
every later lookup, which `liveDossiers` enforces by filtering `isInRecycleBin` on the way in.
Because a cancel names an *order* and a master-sub order is several dossiers, one message yields
one recycle per dossier the lookup returned — each addressed by its own `Id` and BL, so the subs
do not recycle one another. With no lookup at all it yields a single upsert keyed on
`CustomerReference` + `BASFBL`; with a lookup that found nothing it yields nothing, since there
is no dossier to recycle and an upsert would create the very record being cancelled.

Nothing else may go with it. Sending mapped business fields alongside a cancel would push order
values onto a dossier that is being withdrawn, and would leave them there if the upsert were
rejected. A cancel with no `CustomerReference` is dropped: Carlo would have nothing to match on.

> **Changed.** Earlier versions emitted `actionAttribute: "delete"` and relied on Carlo removing
> the record. `00-basf.md` no longer describes a delete anywhere, and the recycle-bin flag is now
> the specified mechanism.

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

`src/test/dw/IftminMappingTest.dwl`, 106 tests.

Twenty-one interchanges are exercised — every IFTMIN interchange in `docs/example-orders`. Each
is compared against a row of `src/test/resources/example-orders/manifest.json`, which records
the message's own BASF BL, BGM code, CustomerReference and equipment count as read off the
parsed tree. The expectations (`FCL`/`LCL`, `BackToBack`/`Coloadin`, the scenario, the action,
the contract-required field set) are derived from those facts independently of the mapping, so
a wrong flow decision fails here rather than being restated.

The flow decisions are additionally called out one by one — the master-sub split, the LCL
co-load, the FCL master-sub staying back-to-back — plus the cancel branch and the derivation
units.

**`BasfIftmin.dwl` is covered end to end, script included.** The suite runs it through
`evalPath`, exactly as the data-transformer evaluates the uploaded file, and asserts on the JSON
Carlo would receive — so the output header, the document body and every inlined helper are all
under test. Nothing is imported from the mapping and nothing about it is mirrored in the test,
so there is no wrapper shape to keep in sync.

### Scenario directories

`src/test/resources/BasfIftmin/<Scenario>/inputs/payload.json` — how the IDE preview binds
`payload`, and what `inputsFrom()` / `outputFrom()` read if a whole-document golden test is added
(drop a reviewed `out.json` beside `inputs/`). Four are provided: `FclCreate`, `LclCreate`,
`MasterSubFcl`, `MasterSubLcl`.

The directory name must equal the mapping **filename**, so these live under `BasfIftmin/`. A
directory named after a file that no longer exists silently binds nothing.

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
