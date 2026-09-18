# Carlo v3 → BASF IFTSTA — mapping spec

The first **outbound** mapping. The three existing mappings turn a BASF EDIFACT interchange
into a Carlo API call; this one runs the other way — it turns a Carlo shipment-change event
into the EDIFACT status message BASF receives.

| | |
|---|---|
| Authority | `docs/iftsta/IFTSTA_mapping_v1.xlsx` — one sheet per message type, plus `Sheet1` (the index); `docs/00-basf.md` §Outbound |
| Mapping | `src/main/dw/OutboundIftsta.dwl` — one self-contained script |
| Source | Carlo `shipmentChangeEventLogEntry` JSON — contract in `02-carlo-event-contract.md`, examples in `docs/example-orders/outbound/iftsta/carlo/{fcl,lcl}/<matchcode>.json` |
| Target | the EDI JSON representation of an IFTSTA D96A interchange; Fracht Connect serialises it to EDIFACT text |
| Approved output | `docs/example-orders/outbound/iftsta/basf/{fcl,lcl}/IFTSTA*.txt` — 14 files, the EDIFACT these mappings must produce |
| Tests | `src/test/dw/IftstaMappingTest.dwl` — `mvn -o test` |

## 1. Role of the message

IFTSTA is a **status report**. Carlo raises a shipment-change event; the integration turns that
event into one IFTSTA interchange telling BASF what changed. Seven events are in scope, and
`Sheet1` of the mapping workbook is the index:

| Message | Meaning | Carlo matchcode | Status |
|---|---|---|---|
| IFTSTA6817 | ETD/ETA change before departure | `IFTSTA6817` | `STS+1+68+17` |
| IFTSTA6819 | Vessel change | **`FRA9`** | `STS+1+68+19` |
| IFTSTA24 | Departure confirmation | `IFTSTA24` | `STS+1+24+40` |
| IFTSTA6828 | Send BL number to BASF | `IFTSTA6828` | `STS+1+68+28` |
| IFTSTA6808 | ETA change after departure | `IFTSTA6808` | `STS+1+68+8` |
| IFTSTA29 | Arrival on destination | `IFTSTA29` | `STS+1+29` |
| IFTSTA21 | Inland arrival on destination | `IFTSTA21` | `STS+1+21` |

**IFTSTA6819 is the one message whose Carlo matchcode is not its own name** — it is `FRA9`.
Every other matchcode equals the use case. The mapping keys on the matchcode, so this is the
single case where the event that drives a message and the message it produces are named
differently; `Sheet1` column C is the authority. The Carlo example files are named after the
**matchcode** (`FRA9.json`), the BASF outputs after the **use case** (`IFTSTA6819.txt`).

Each sheet gates its status segment on the event type — *"`eventType.matchcode = IFTSTA6808`
then `STS+1+68+8`"* — so the matchcode both **selects** the message and **is asserted by** it.
An event whose matchcode matches no sheet produces nothing.

## 2. Shape of the message

One interchange carries one message, and the message is a header followed by **one repeated
block per cargo line**:

```
UNB                          interchange header
UNH  BGM  DTM+137 ×2         message header: type, function, event timestamp
[TSR]                        LCL only
RFF+SI  [RFF+BN]             customer reference, booking reference
  ┌ CNI                      ── one block per eventHouseShipment.cargo[] entry ──
  │ STS                      the status this message reports
  │ [RFF+BN] [RFF+BM]        booking / master B/L
  │ [DTM+95]                 B/L date of issue
  │ DTM+334 ×2               event date and time
  │ TDT  LOC+9  LOC+12       carriage, ports
  │ DTM+133/186/132/178      the dates this message reports
  └ [EQD]                    container, when there is one
UNT  UNZ
```

Everything below the `CNI` repeats verbatim for each cargo line except the `CNI` itself and its
`EQD` — the sheets state this as *"Value is always the same for each array element"* against
every other row, and *"Value is unique per array element"* against those two. The repetition is
not redundancy to be optimised away: it is what the message format requires.

## 3. Source

Carlo POSTs the event to
`https://api-ch2.fracht-connect.com/dev/s/v1/fra-e-inbound/carlo_be/basf_iftsta`, which writes the
JSON to Azure blob storage; MuleSoft is then triggered to process the file. **The full contract —
every field, its type, how it reaches the transformer, and what is still open about its value
ranges — is `02-carlo-event-contract.md`.** The summary below is the part this mapping consumes.

`shipmentChangeEventLogEntry[0]` — the mapping reads the **first** entry. Every captured example
carries exactly one; see §9.

```
shipmentChangeEventLogEntry[0]
├── eventType.matchcode                which message this is (§1)
├── localTime                          the event timestamp
└── eventHouseShipment
    ├── frachtShipmentRef              UNH/UNT message reference
    ├── customerReference              RFF+SI
    ├── dUNSCustomer                   UNB recipient
    ├── loadType                       1 = FCL, 2 = LCL
    ├── master
    │   ├── externalReferences[]       referenceType 9 → RFF+BN
    │   └── mainCarriageAsOcean
    │       ├── masterBillOfLadingNumber       RFF+BM
    │       ├── voyageNumber, carrier, vessel  TDT
    │       ├── portOfDeparture, portOfArrival LOC+9 / LOC+12
    │       └── estimated/actual TimeOf Departure/Arrival  DTM+133/186/132/178
    ├── cargo[]                        one CNI block each
    │   ├── deliveryNoteSAP, deliveryPositionNumber   CNI
    │   └── containerTransport.containerNumber        EQD
    └── billOfLading.dateOfIssue       DTM+95
```

## 4. Field mapping

### 4.1 Interchange and message header

| Segment | Source | Notes |
|---|---|---|
| `UNB+UNOY:3+283155273+878542765:01:<dUNS>+<YYMMDD>:<HHmm>+<msgId>` | `dUNSCustomer`, `localTime` | sender `283155273` and recipient `878542765:01` are constants in every sheet |
| `UNH+<ref>+IFTSTA:D:96A:UN` | `frachtShipmentRef` | |
| `BGM` | — | `BGM+44` for IFTSTA24, `BGM+23+1+9` for all six others |
| `DTM+137:<YYYYMMDD>:102` | `localTime` | |
| `DTM+137:<HHmmss>:402` | `localTime` | |
| `TSR+25+3` | `loadType` | **LCL only** (`loadType = 2`); omitted for FCL |
| `RFF+SI:<ref>` | `customerReference` | |
| `RFF+BN:<ref>` | `externalReferences[referenceType = 9].value` | header-level on 21/29/6808/6817/6819; **inside the block** on 6828; absent on 24 |

**The message ID** (`UNB` element 5, which the serialiser repeats in `UNZ`) is *"the equivalent
of `Datetime.Now.Ticks`"*, set **once at the start of the run** and used wherever it is
referenced. The mapping sets it from `now()` — see §6.

### 4.2 The repeated block

| Segment | Source | Present on |
|---|---|---|
| `CNI+<n>+<deliveryNoteSAP>::<deliveryPositionNumber>` | `cargo[n]` | all — `n` is the 1-based block counter |
| `STS` | `eventType.matchcode` | all — the code from the §1 table |
| `RFF+BN` | `externalReferences[9]` | **6828 only** |
| `RFF+BM` | `masterBillOfLadingNumber` | all except **6808** |
| `DTM+95:<YYYYMMDD>:102` | `billOfLading.dateOfIssue` | all except **6808** |
| `DTM+334:<YYYYMMDD>:102` | `localTime` | all |
| `DTM+334:<HHmmss>:402` | `localTime` | all |
| `TDT+21+<voyage>+10+13+::11:<carrier.name1>+++<vessel.matchcode>:::<vessel.designation>` | `mainCarriageAsOcean` | all — no vessel flag, §8.2 |
| `LOC+9+<matchcode>:::<designation>` | `portOfDeparture` | all |
| `LOC+12+<matchcode>:::<designation>` | `portOfArrival` | all |
| `DTM+133` ETD / `DTM+186` ATD / `DTM+132` ETA / `DTM+178` ATA | `mainCarriageAsOcean` | per §4.3 |
| `EQD+CN+<containerNumber>` | `cargo[n].containerTransport.containerNumber` | all — **omitted when empty or null** |

### 4.3 Which dates each message reports, and in which order

The sheets differ here and the order is theirs, not ascending-qualifier order:

| Message | DTM order |
|---|---|
| IFTSTA21, IFTSTA29 | `133` ETD, `186` ATD, `132` ETA, `178` ATA |
| IFTSTA24, IFTSTA6808 | `132` ETA, `186` ATD |
| IFTSTA6817, IFTSTA6819, IFTSTA6828 | `133` ETD, `132` ETA |

A date whose source field is null is omitted, so a message can carry fewer than its sheet lists.

### 4.4 Per-message differences, in one table

| | 21 | 24 | 29 | 6808 | 6817 | 6819 | 6828 |
|---|---|---|---|---|---|---|---|
| `BGM` | 23+1+9 | **44** | 23+1+9 | 23+1+9 | 23+1+9 | 23+1+9 | 23+1+9 |
| `RFF+BN` | header | **—** | header | header | header | header | **in block** |
| `RFF+BM` | ✓ | ✓ | ✓ | **—** | ✓ | ✓ | ✓ |
| `DTM+95` | ✓ | ✓ | ✓ | **—** | ✓ | ✓ | ✓ |
| dates | 133 186 132 178 | 132 186 | 133 186 132 178 | 132 186 | 133 132 | 133 132 | 133 132 |
| matchcode | IFTSTA21 | IFTSTA24 | IFTSTA29 | IFTSTA6808 | IFTSTA6817 | **FRA9** | IFTSTA6828 |

IFTSTA21 and IFTSTA29 are structurally identical; only the status code differs.

## 5. FCL and LCL

The same seven messages are produced for both load types, and the difference is exactly two
segments:

| | FCL (`loadType` 1) | LCL (`loadType` 2) |
|---|---|---|
| `TSR+25+3` | absent | present |
| `EQD` | one per cargo line | absent — `containerNumber` is null |

So every LCL message is **4 segments shorter** than its FCL counterpart (one `TSR` gained, five
`EQD` lost across five cargo lines). That invariant is asserted by the test suite, because it
holds for a structural reason rather than by coincidence: an LCL consignment has no container to
report.

## 6. Values the mapping does not invent

**Nothing is constructed or enriched — every value is Carlo's, passed through bare.**
Analyst-confirmed 18-09-2026. Two consequences worth stating because both were tried and
rejected:

- `LOC` carries the **plain** `designation`: `LOC+9+BEANR:::Antwerpen`, not
  `Antwerpen (BE ANR)`. Older BASF samples show the parenthesised UN/LOCODE, and it is
  derivable from the matchcode — the mapping does not derive it.
- Placeholder-looking source data is passed through unchanged. The current examples carry
  `masterBillOfLadingNumber: "master bl number"`; that is what goes in `RFF+BM`. Real data
  arrives later and needs no mapping change.

The one value not taken from Carlo is the **message ID**, which has no source field. It is a
mapping **parameter**, defaulted from the event timestamp so that a given event always renders
the same interchange — a mapping that read the clock could not be tested, and the sheets require
one value shared by `UNB` and `UNZ` anyway. Fracht Connect can override it per run.

## 7. `UNT` and `UNZ` — which the mapping does not emit

`UNT` carries the count of segments from `UNH` through `UNT` **inclusive** — the EDIFACT rule.
Every sheet's own sample agrees with it. The IFTSTA24 sheet briefly read `UNT+32` where its
sample held 31 segments; that was corrected to `UNT+31` on 18-09-2026, which is what settled the
question. `UNT` also repeats `frachtShipmentRef` from `UNH`, and `UNZ` repeats the message ID
from `UNB`.

**Neither segment is part of the EDI JSON.** The parser consumes `UNT` without emitting it and
never represents `UNZ` at all, so the mapping emits neither — Fracht Connect counts the segments
and writes both when it serialises. The rule is recorded here because the approved messages must
satisfy it, not because this mapping applies it. One consequence: the message ID appears exactly
**once** in the emitted document (`UNB05`), which is what lets the test suite blank a single
field to compare a clock-derived value against a fixed fixture.

## 8. Output format

### 8.1 EDIFACT text

The approved outputs under `docs/example-orders/outbound/iftsta/basf/` are **CRLF-terminated with
no trailing newline** after `UNZ`, matching every BASF sample. Fracht Connect produces the text,
not the mapping — but the 14 approved files are what it must produce, and the test suite renders
the mapping's output back to text to compare against them (§9).

### 8.2 The missing TDT vessel flag

BASF samples end `TDT` with a vessel flag (`:MT`, `:PA`, `:LR`). Nothing in the Carlo event
supplies one, so **`TDT0805` is not emitted** — and since EDIFACT drops trailing empty
components, the serialised segment simply ends after the vessel name. The approved `.txt` files
carry a trailing `:` there, which is cosmetic: parsing it back yields no `TDT0805`, which is why
the round-trip comparison in §9 is unaffected. See §10.4.

## 9. Tests

`src/test/dw/IftstaMappingTest.dwl` runs the mapping the way the data-transformer does —
`evalPath` over the whole self-contained script — for **all 14 combinations** (7 messages × FCL
and LCL).

The suite does not restate the mapping. It asserts against the **14 approved EDIFACT files**,
reached by a second, independent route: `tools/edifact_to_json.py` parses each approved `.txt`
into the same EDI JSON shape the mapping emits, and the two documents are compared. The
converter walks EDIFACT text by segment structure where the mapping builds JSON from a Carlo
event, so the two arrive at the same document from opposite directions — the same
cross-check-not-restatement principle the inbound suites use with `manifest.json`.

On top of that, the per-message rules of §4.4, the FCL/LCL invariant of §5 and the `UNT` rule of
§7 are asserted directly, so a regression names the rule it broke rather than only reporting a
document diff.

## 10. Open items

> **Parked until the week of 22-09-2026.** Outstanding: 1–4 and 7. Items 0 and 6 are
> housekeeping that resolves itself when a capture and real data arrive. Items 5 and 8 are
> resolved and kept for the record.

0. **UNB0401/UNB0402 lose a leading zero.** The parser types the interchange date and time as
   numeric, so the mapping emits them as numbers to stay comparable with a parsed message. An
   event at 08:20 therefore gives `UNB0402: 820`, not `"0820"`. A writer that knows the field is
   4 characters will pad it; one that does not will emit a malformed `UNB`. Every current example
   is after 10:00, so no fixture exercises it. **Check this with the same capture that settles
   item 1.**
1. **The writer's JSON schema is not attested.** The mapping emits the EDI JSON shape symmetric
   with what the inbound parser produces — position-prefixed segment keys (`"0020_BGM"`),
   `Segment_group_N` nesting, `<TAG><ee><cc>` element keys. That is the only EDI JSON shape
   evidenced anywhere in this repo, and reader and writer of the `mule-edifact-extension` share
   a schema, but **no captured outbound envelope exists to confirm it**, and the IFTSTA D96A
   group numbers and positions are reconstructed from the message's own structure rather than
   verified against a capture. Unlike the inbound mappings — which navigate by segment-name
   suffix and are therefore immune to a wrong position — an outbound mapping *writes* these
   keys, so they are load-bearing.

   The structure lives in **one table at the top of `OutboundIftsta.dwl`** so that correcting it
   is a single edit, and the test suite's content assertions are written against segment
   *content*, so they survive a correction. **Capture one outbound transformer envelope from
   Fracht Connect and diff it against the table before go-live.**
2. **`isedifact` vs `isx12`.** `config/README.md` notes both flags exist on a transformer step
   and make it *write* EDI. IFTSTA is a UN/EDIFACT message — `UNB`/`UNH`/`UNZ`, `IFTSTA:D:96A:UN`
   — so `isedifact` is the flag, and there is no X12 equivalent of IFTSTA (the nearest X12
   status transactions are 214 and 315, which are different messages). Stated because the work
   was requested in terms of "x12 json"; if an X12 target is genuinely intended, this mapping is
   the wrong shape and the sheets do not describe it.
3. **No outbound profiler config exists, and the trigger is unidentified.** `config/` holds three
   inbound `dataProfiler` documents and one `dataGetter`; an IFTSTA profile needs a source, this
   transformer, and an EDI delivery step, none of which is written. The front half of the path is
   now known — Carlo POSTs to `fra-e-inbound/carlo_be/basf_iftsta`, which writes the payload to
   Azure blob storage — but **what then picks the blob up and starts the flow is not
   established**, and that decides the profiler's source step. See `02-carlo-event-contract.md`
   §1. The `dwlPath` blob name is consequently not fixed either, which is why this mapping's
   header names none where the inbound three do.
4. **The vessel flag has no source.** §8.2. Confirm with the analyst whether BASF needs it; if
   so, Carlo has to supply it.
5. ~~**Only `shipmentChangeEventLogEntry[0]` is read.**~~ Resolved — one message per status
   change, one status change per file, so the array always carries one entry
   (`02-carlo-event-contract.md` §4). Reading `[0]` is correct. A longer array would be silently
   truncated rather than rejected, so this is the line to change first if batching is ever
   introduced.
6. **The example data is still partly placeholder.** `masterBillOfLadingNumber` is
   `"master bl number"` and `voyageNumber` is `"123"` in both FCL and LCL examples. The mapping
   passes them through (§6), so no change is expected when real values arrive — but the approved
   `.txt` files will need regenerating, and they are fixtures.
7. **`preferredModeOfTransport` is `"Ocean"` in every example and is not mapped.** The mapping
   reads `mainCarriageAsOcean` unconditionally. If a road or air shipment can raise the same
   events, `TDT`/`LOC` have no source and the sheets do not cover it. It is one of only three
   contract fields the mapping ignores — `02-carlo-event-contract.md` §3.
8. ~~**Which fields Carlo can leave null is unknown.**~~ Resolved — a scenario's *unmapped*
   fields are exactly its nullable ones, which tracks the shipment lifecycle: no actuals before
   departure, no ATA before arrival, no booking reference on a departure confirmation, no master
   B/L on an ETA change. `02-carlo-event-contract.md` §4 has the table, and the test suite asserts
   both directions — emptying a scenario's unmapped fields leaves its message unchanged, and
   emptying a mapped one does not.
