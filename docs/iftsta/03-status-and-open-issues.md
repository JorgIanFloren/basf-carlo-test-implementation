# IFTSTA — status and open issues

Where the outbound IFTSTA work stands, written to pick up from. Paused 18-09-2026, to resume
the week of **22-09-2026**.

| | |
|---|---|
| Branch | `basf/outbound-iftsta` |
| PR | [#5](https://github.com/JorgIanFloren/basf-carlo-test-implementation/pull/5) — open, 5 commits |
| Tests | **255 passing** (`mvn -o test`) — 209 pre-existing, 46 new |
| Deployable | **No.** Two blockers, §3 |

The three documents in this directory divide up like this: **01** is the mapping spec (what each
field becomes), **02** is the input contract (what Carlo sends and how it arrives), **03** is this
— state and what is left.

## 1. What is done

Everything asked for is built and green. The mapping turns a Carlo shipment-change event into
the EDI JSON representation of an IFTSTA D96A interchange; Fracht Connect serialises it.

| | |
|---|---|
| `docs/iftsta/01-IFTSTA_mapping_spec.md` | the mapping spec, from the 7 sheets + `Sheet1` |
| `docs/iftsta/02-carlo-event-contract.md` | the input contract and the path from Carlo |
| `docs/iftsta/IFTSTA_mapping_v1.xlsx` | the workbook, beside its spec as IFTMIN/IFTMBF keep theirs |
| `src/main/dw/OutboundIftsta.dwl` | the mapping — self-contained, no imports |
| `src/test/dw/IftstaMappingTest.dwl` | 46 tests |
| `tools/edifact_to_json.py` | gained the IFTSTA D96A structure and `--outbound` |
| `docs/example-orders/outbound/iftsta/{carlo,basf}/{fcl,lcl}/` | 14 Carlo events, 14 approved messages |
| `src/test/resources/example-orders/outbound/` | 28 generated fixtures |

Seven message types × FCL and LCL = 14 combinations, all reproducing their approved EDIFACT.

### How the tests avoid marking their own homework

`--outbound` parses the 14 approved `.txt` files into the same shape the mapping emits. One side
is built from a Carlo event by DataWeave, the other from EDIFACT by Python; the suite asserts they
agree as whole documents. Same principle the inbound suites get from `manifest.json` — a
cross-check, not a restatement.

```
mvn -o test                                  # 255 tests
python tools/edifact_to_json.py --outbound   # regenerate outbound fixtures
python tools/edifact_to_json.py --all        # regenerate inbound fixtures
```

> On Windows, `--all` rewrites the inbound fixtures with LF endings against CRLF working copies,
> so `git status` shows ~55 files modified with **zero** content change. `git checkout --
> src/test/resources/example-orders/inbound` clears it. Pre-existing behaviour, not introduced here.

## 2. Decisions on record

Settled during the work, with who and when, so none of it gets relitigated:

| | Decision | Source |
|---|---|---|
| NAD segments | dropped — BASF does not use addresses in the current integration | user, 18-09 |
| Value construction | **nothing is constructed.** `LOC` carries Carlo's bare `designation`, not `Antwerpen (BE ANR)`. Placeholder-looking data passes through | analyst, 18-09 |
| `UNT` | counts `UNH`→`UNT` inclusive. The IFTSTA24 sheet's `UNT+32` was an off-by-one, corrected to 31 | sheet fix, 18-09 |
| Event cardinality | one message per status change per file — the array always holds one entry | user, 18-09 |
| Nullability | a scenario's **unmapped** fields are exactly its nullable ones; it tracks the shipment lifecycle | user, 18-09 |
| Message ID | no Carlo source; the mapping sets it from `now()`, as the sheets ask | derived |
| `UNT`/`UNZ` | not emitted — they are not part of the EDI JSON; the serialiser writes them | derived from the parser |

## 3. Blockers — both needed before go-live

Independent of each other. Neither is a code defect; both are missing information.

### 3.1 The EDI writer's JSON shape is reconstructed, not captured

The mapping emits the shape symmetric with what the inbound parser *produces*. That is the only
EDI JSON shape evidenced in this repo, and reader and writer of `mule-edifact-extension` share a
schema — but nothing confirms it, and the IFTSTA D96A positions and group numbers are
reconstructed from the message's own structure.

**Why it matters more than the `ESTIMATED` positions already in the converter:** the inbound three
navigate by `_<SEGMENT>` suffix and never read a position, so a wrong one cannot hurt them. This
mapping **writes** the positions.

What constrains it today, and what does not:

- ✅ all 14 approved messages parse into the structure with nothing left over — `build_message`
  raises `Unplaceable` on a leftover segment, so a merely plausible structure fails loudly
- ✅ the nested TDT → LOC grouping matches how IFTMIN SG8/SG9, IFTMBF SG7/SG8 and IFCSUM SG9 all
  model carriage
- ❌ neither of those proves the writer expects *these* position keys

**To unblock:** capture one outbound transformer envelope from Fracht Connect and diff it against
the structure. It lives in exactly two places — `var K` at the top of `OutboundIftsta.dwl` and
`IFTSTA_D96A` in `tools/edifact_to_json.py` — so a correction is two edits, and the suite's
assertions are written against segment *content*, so they survive it.

The same capture answers **`UNB0401`/`UNB0402`**: they are emitted as numbers to match the parser,
so an event before 10:00 would give `UNB0402: 820` rather than `"0820"`. A writer that knows the
field is 4 characters pads it; one that does not emits a malformed `UNB`. No current example is
before 10:00, so no fixture exercises it.

### 3.2 What triggers MuleSoft off the blob is unidentified

Known: Carlo POSTs to `…/fra-e-inbound/carlo_be/basf_iftsta`, which writes the payload to Azure
blob storage. Unknown: what picks the blob up and starts the flow.

That decides the source step of the outbound `dataProfiler`, which `config/` still lacks — and
therefore also the `dwlPath` blob name, which is why this mapping's header names none where the
inbound three do.

A related assumption rides on it: the mapping expects the **bare** Carlo document as `payload`,
not the two-node `originalPayload`/`payload` envelope IFTMIN and IFTMBF get from their lookup
step. IFTSTA addresses nothing in Carlo — it only reports — so there is nothing to put beside the
payload. If the trigger turns out to wrap the document, only the two accessors in `messages()`
change.

## 4. Smaller open questions

None of these blocks anything; each is cheap to answer.

1. **The TDT vessel flag.** BASF samples end `TDT` with `:MT`, `:PA`, `:LR`. No Carlo field
   supplies one, so it is not emitted. Does BASF need it? If so Carlo has to send it.
2. **`externalReferences` cardinality.** Both examples carry exactly one entry, of type 9. The
   mapping takes the first type-9 match and ignores the rest. Can there be several, or other
   types?
3. **Non-ocean shipments.** `preferredModeOfTransport` is `"Ocean"` everywhere and the mapping
   reads `mainCarriageAsOcean` unconditionally. If road or air can raise these events, `TDT` and
   `LOC` have no source and the sheets do not cover it.
4. **`isedifact`, not `isx12`.** The work was requested in terms of "x12 json". IFTSTA is
   UN/EDIFACT (`UNB`/`UNH`/`UNZ`, `IFTSTA:D:96A:UN`) and X12 has no IFTSTA — its nearest status
   transactions, 214 and 315, are different messages. If an X12 target is genuinely intended, this
   mapping is the wrong shape and the sheets do not describe it.

## 5. Housekeeping that clears itself

- **Placeholder data.** `masterBillOfLadingNumber` is `"master bl number"` and `voyageNumber` is
  `"123"` in both examples. The mapping passes them through, so no mapping change is expected —
  but the approved `.txt` files are fixtures and **will need regenerating**, then
  `python tools/edifact_to_json.py --outbound`.
- **Carlo file naming.** Carlo inputs are named by **matchcode** (`FRA9.json`), BASF outputs by
  **use case** (`IFTSTA6819.txt`). Deliberate — IFTSTA6819 is raised by matchcode `FRA9` — but
  worth a second look if it reads badly to anyone else.

## 6. Picking it up

1. Get **one captured outbound transformer envelope** — clears 3.1 and the `UNB0402` question in
   one go.
2. Ask whoever owns the Fracht Connect config what triggers off the blob — clears 3.2 and unblocks
   writing the outbound `dataProfiler`.
3. Put §4's four questions to the analyst in one pass.
4. Regenerate the approved messages when real B/L and voyage values land.

Until 1 and 2 are answered the mapping is complete and tested but not deployable. Nothing in the
codebase is waiting on a decision — the work is waiting on information.
