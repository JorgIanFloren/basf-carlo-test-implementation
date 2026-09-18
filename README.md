# BASF ↔ Carlo integration

Four DataWeave mappings between BASF's EDIFACT messages and Carlo (Soloplan) v3, deployed on
Fracht Connect. **Three inbound**, which turn a BASF interchange into a Carlo API call, and
**one outbound**, which turns a Carlo event into a BASF message. No mapping ever sees EDIFACT
text: the platform's EDI parser hands the inbound three the **parsed JSON** representation of an
interchange, and the outbound one returns that same representation for the platform to
serialise.

| Message | Mapping | Deployed as | Target contract | Spec |
|---|---|---|---|---|
| IFTMIN (instruction) | `src/main/dw/InboundIftmin.dwl` | `Fracht-Belgium/basf/basf-inbound-iftmin-to-carlo.dwl` | `docs/expected_output_SeaHouseShipment.json` | `docs/iftmin/01-IFTMIN_mapping_spec.md` |
| IFTMBF (firm booking) | `src/main/dw/InboundIftmbf.dwl` | `Fracht-Belgium/basf/basf-inbound-iftmbf-to-carlo.dwl` | ″ | `docs/iftmbf/01-IFTMBF_mapping_spec.md` |
| IFCSUM (consolidation summary) | `src/main/dw/InboundIfcsum.dwl` | `basf/InboundIfcsum.dwl` | `docs/expected_output_ShipmentCargo.json` | `docs/ifcsum/01-IFCSUM_mapping_spec.md` |
| **IFTSTA (status report) — outbound** | `src/main/dw/OutboundIftsta.dwl` | *not yet profiled* | `docs/example-orders/outbound/iftsta/basf/` (14 approved messages) | `docs/iftsta/01-IFTSTA_mapping_spec.md` |

**IFTSTA runs the other way.** Its source is a Carlo `shipmentChangeEventLogEntry` and its
target is the EDI JSON representation of an IFTSTA D96A interchange; one Carlo event becomes one
status message for BASF. Seven event types are in scope, each in an FCL and an LCL flavour. It
has no `dwlPath` yet because no outbound profiler exists in `config/` — see the spec's open
items, the first of which (**the writer's JSON schema is reconstructed, not captured**) has to be
settled before it can go live.

Carlo reaches it by POSTing to `…/fra-e-inbound/carlo_be/basf_iftsta`, which writes the payload to
Azure blob storage; MuleSoft is then triggered to process the file. The field contract is fixed
and fully documented — `docs/iftsta/02-carlo-event-contract.md` — but **what triggers the flow off
the blob is not established**, and that is what the missing profiler hinges on.

**The target API is documented in `docs/carlo/`** — how to call it, all 54 schemas, the
`$filter` property ids, and the behaviour its OpenAPI document does not describe. Start at
`docs/carlo/README.md`.

**Each mapping is a single self-contained script.** The data-transformer evaluates the uploaded
file on its own and resolves no imports off Blob Storage, so nothing may be imported from a
shared module — the helpers the inbound three need (date conversion, `camelKeys`, the
position-agnostic segment navigation, `messagesOfType`) are inlined verbatim into each file. That
is three copies on purpose: **change one and change all three.** Each inbound mapping's header
names the blob it is deployed as, which is the `dwlPath` of its profile's transformer step — the
platform's naming differs from the repo filename, so the pairing is stated in both places.

`OutboundIftsta.dwl` is self-contained on the same terms but shares none of that block: running
the other way it has no interchange to navigate and no Carlo document to camel-case, so it
carries its own, smaller set of helpers. Nothing needs to be kept in step between it and the
inbound three.

Each mapping takes the **whole interchange** and returns an array, because one interchange can
legitimately carry several messages — that is exactly what a BASF master-sub is.

IFTMIN and IFTMBF are not handed the interchange on its own. Their flow opens with the "GET
dossier by CustomerRef" `dataDelivery` step, which hands the transformer an envelope of two
sibling nodes — the interchange on `originalPayload` and the GET response on `payload`. See
`docs/carlo/06-dossier-lookup.md`.

## Deploying

`config/` holds the Cosmos DB documents that add these three integrations to Fracht Connect —
one `dataProfiler` per message type wiring getter → transformer → delivery, plus a placeholder
`dataGetter` for the inbound transport. **Read `config/README.md` before loading them**: several
things in there are inferred rather than documented, including how the interchange gets parsed
to JSON.

Upload each mapping to the `transforms` container under the name its `dwlPath` carries — see the
table in `config/README.md` check 2:

```
az storage blob upload --account-name saeus2integrationdev001 --container-name transforms \
  --name "Fracht-Belgium/basf/basf-inbound-iftmin-to-carlo.dwl" --file ./src/main/dw/InboundIftmin.dwl
```

## Running the tests

```
cd basf
mvn -o test
```

253 tests. Every EDIFACT interchange in `docs/example-orders/inbound` is exercised by the mapping for
its message type: 35 IFTMIN, 13 IFTMBF, 6 IFCSUM. Outbound, all 14 approved IFTSTA messages
(7 message types × FCL and LCL) are reproduced from the Carlo events that raise them.

The suites run each mapping the way the data-transformer does — `evalPath` evaluates the
uploaded script itself against a `payload` context and asserts on the JSON Carlo would receive.
Nothing is imported from a mapping, so the tests stay honest about the self-contained files.

The IFTMIN and IFTMBF suites feed the mapping the same envelope the pipeline does — the
interchange on `originalPayload`, a captured GET response on `payload` — so the dossier-addressing
rules are exercised against real data. `docs/get-responses/*.json` are
captures of the "GET dossier by CustomerRef" call — one per scenario, plus a not-found response —
and `src/test/resources/get-responses/` is the classpath copy the suites load. Because they are
real server responses rather than hand-written expectations, the dossier ids and reference fields
asserted in the tests are the records the integration actually created.

Two fixtures go one step further and are **whole envelopes captured from a live FrachtConnect
run** — `docs/documentation-input/inbound/mulesoft-{iftmin,iftmbf}-get-existing-append-original.json`,
copied onto the classpath at `src/test/resources/envelopes/`. They are the transformer's input
verbatim, so they are the only fixtures that can catch a wrong node name: nothing in the suite
builds them. Both are order `2800209301_RV1`, whose GET found the `BL00` dossier (CarLo id
`1564415`) an earlier run created.

## Fixtures

Test fixtures are **generated, not hand-written** — with two exceptions that are *captured*
rather than generated and are copied in by hand: `src/test/resources/get-responses/` (CarLo GET
responses) and `src/test/resources/envelopes/` (whole transformer inputs). Their sources live
under `docs/`, and the copies must be kept in step with them.

```
python tools/edifact_to_json.py --all          # docs/example-orders/inbound -> src/test/resources/example-orders/inbound
python tools/edifact_to_json.py --outbound     # docs/example-orders/outbound -> src/test/resources/example-orders/outbound
python tools/edifact_to_json.py <in.txt>       # one file, to stdout
```

`--outbound` does double duty for IFTSTA. It parses the 14 approved messages into the shape
`OutboundIftsta.dwl` emits — which is how the suite gets an expectation it did not write itself —
and copies the Carlo events that are the mapping's input. The mapping builds that shape from a
Carlo event in DataWeave; the converter builds it from EDIFACT in Python; the test asserts the
two agree.

**Regenerate whenever `docs/example-orders/inbound` changes, and commit the result.** The fixture set had
drifted once: the sources were reorganised without re-running the converter, so fixture names no
longer matched their content — `fcl/ifcsum-2013354401.json` held an IFTMIN, `ms/2800231445-iftmbf-2.json`
held a two-message IFTMIN, and four names had no source at all. The suites went on passing because
the manifest is generated from the same stale tree, so nothing contradicted anything. Only adding
new examples surfaced it. A fixture set that is regenerated on every change cannot drift like that;
one that is regenerated occasionally silently can.

`tools/edifact_to_json.py` reproduces the Fracht Connect EDI parser: the position-prefixed
segment keys (`"0020_BGM"`, `"0890_Segment_group_18"`), the `<TAG><ee>` / `<TAG><ee><cc>`
element naming, omitted empty components, numeric elements as JSON numbers, and the
directory-specific quirks (`NAD07` is simple in D99A and composite in D08A; D08A renders the
repeating `COM01` composite as `[{C07601, C07602}]` where D99A gives flat `COM0101`/`COM0102`).

It also reproduces the **mojibake**: BASF sends UTF-8 and the parser decodes it as latin-1, so
`40′ Reefer` reaches the mapping as `40Â´ Reefer`. Fixtures that did not reproduce that would
not be testing what production actually receives.

### How faithful is it?

Verified by re-parsing the source interchange for each of the four real parser captures that
happen to be in the example set and diffing against the capture:

| Capture | Differences |
|---|---|
| IFTMIN D99A `fcl/2800209301_FCL_IFTMIN_ERST_9.json` | **0** |
| IFTMBF D08A `fcl/2013357254_IFCSUM.txt` | 11, all U+FFFD |
| IFCSUM D08A `fcl/TRS-000001_30062026_1658 (1).xml` | **0** |
| IFCSUM D08A `fcl/TRS-000001_30062026_1658.xml` | 1, U+FFFD |

The non-zero rows are all the same thing: the capture itself was saved through a lossy step and
holds U+FFFD where the source still carries a real character. The structure is identical in
every case.

Positions the captures never exercised are marked `ESTIMATED` in the structure tables. They
cannot affect correctness — IFTMBF and IFCSUM navigate by segment-name suffix, and every
position IFTMIN reads is a verified one.

### `manifest.json`

The converter also writes `src/test/resources/example-orders/inbound/manifest.json`: one row per
fixture recording its message type, directory, message count, master-sub flag, and per-message
BASF BL / BGM code / CustomerReference / equipment count — plus, for IFCSUM, the cargo lines it
should produce.

The mapping tests are driven from it. Because the manifest is built by walking the parsed tree
with explicit key lookups while the mappings walk it by segment-name suffix, the two reach the
same answer by different routes; the manifest is a cross-check, not a restatement.

## Watch out: the example filenames are wrong

Nearly every file in `docs/example-orders/inbound` is mislabelled. Classify by content, never by name:

- `fcl/2013357254_IFCSUM.txt` is a parsed **IFTMBF** JSON capture
- `fcl/TRS-000001_*.xml` are parsed **IFCSUM** JSON captures
- `fcl/20260625-*.xml`, `fcl/TrisSquid_Message_Sequence (1).docx` and `ms/messages.png` are
  **EDIFACT interchanges**
- `ms/2800237044 IFTMBF.txt` is a **PNG image**
- `fcl/2800209952_IFTMIN_ERST_9.txt` and the three `fcl/2800244026 *.txt` are legacy **TRS XML**
  output, not input messages — including the one named "IFTMIN Cancel", which is why no code 1
  example exists
- the `IFTMIN`/`IFTMBF` and `ERST`/`ABSCH` parts of the `.txt` names frequently disagree with
  the `UNH` and `BGM` inside

`is_edifact()` in the converter and the manifest both go by content for this reason.

## Message codes

`BGM03` carries the EDIFACT message function. Only 4 and 9 occur in the example set.

| Code | IFTMIN | IFTMBF | IFCSUM |
|---|---|---|---|
| 9 (original) | `updateorcreate` | `updateorcreate` | `update` |
| 4 (change) | `update` | `update` | `update` |
| 1 (cancel) | identity-only recycle, one per dossier | flow stops, nothing sent | flow stops, nothing sent |

The asymmetry is deliberate and follows `docs/00-basf.md`: a cancelled *instruction* withdraws the
shipment, but a cancelled *booking* or *consolidation summary* does not — see each spec's cancel
section.

A cancelled IFTMIN sets `isInRecycleBin: true` and upserts rather than deleting, per
`00-basf.md` *"IFTMIN / Canceling"*, so the dossier stays in Carlo and simply drops out of every
later lookup. Because a cancel names an order and a master-sub order is several dossiers, one
message recycles each of them.

## Open items

Collected from the four specs; each is written up where it belongs.

0. **IFTSTA is not deployable yet**, for two independent reasons.

   *The output shape is unconfirmed.* The EDI JSON it writes is reconstructed from the inbound
   parser's output rather than captured from the platform's EDI *writer*. Unlike the inbound
   three — which navigate by segment name and cannot be hurt by a wrong position — this one emits
   the position keys, so they are load-bearing. Capture one outbound transformer envelope and
   diff it against the structure table at the top of `OutboundIftsta.dwl`.

   *The pipeline is half-known.* Carlo POSTs to `…/fra-e-inbound/carlo_be/basf_iftsta`, which
   writes the payload to Azure blob storage — but what then picks the blob up and triggers
   MuleSoft is not established, so the outbound `dataProfiler` `config/` still lacks cannot be
   written. The input contract itself is settled (`docs/iftsta/02-carlo-event-contract.md`).

   `docs/iftsta/01-IFTSTA_mapping_spec.md` §10 has the rest, including the leading-zero risk on
   `UNB0402` and the vessel flag Carlo does not supply.

1. ~~**The "GET dossier by CustomerRef" step is wired but not yet loadable.**~~ Resolved — it is
   the `dataDelivery` at sequence 3 of both the IFTMIN and IFTMBF profiles, fed by the
   `dataPipeline` at sequence 2 that injects `BGM0201` into its `$filter`. It does **not** extend
   the payload: it hands the transformer an envelope of two sibling nodes, `originalPayload` and
   `payload`, and both mappings read the two halves off that envelope. The CarLo call is verified
   against the live server (`docs/carlo/06-dossier-lookup.md`).

   This was the live 16-09-2026 defect: "master-sub update still only updates the first shipment"
   was never a mapping bug — the CustomerRef + BL addressing was implemented and tested — it was
   this step not running, so the mappings never left fallback mode.
2. **The IFTMIN cancel shape is still unattested by an example message** — `00-basf.md` now
   specifies the mechanism (recycle and upsert, keyed on `customerrefSet`), but no code 1
   EDIFACT message exists anywhere in the example set, so the branch is covered only by
   synthetic interchanges. `00-basf.md` also still marks step 1b "HOW TO BE CONFIRMED by
   Robin/Niels".
3. ~~**24 fields the IFTMIN mapping emits are not attested in any contract sample.**~~ Resolved —
   checked against Carlo's Swagger, see `docs/carlo/07-contract-conformance.md`. Every field all
   three mappings emit exists in the v3 contract. The two exceptions are `SendDate` and
   `ExportItemReference` in `carloHeader`, which is **dead code** — never called, a leftover of
   the legacy TRS `<Header>` element that v3 has no equivalent of. It can be deleted.
   (`expected_output_SeaHouseShipment.json` and the v3 XML sample are still export dumps rather
   than schemas; `docs/carlo/` is generated from the OpenAPI document itself.)
4. **Multi-container IFCSUM** would lose its VGM data — see `docs/ifcsum` §7.1.
5. **LCL bookings lose `HaulageType` and `EstimatedDispatchDate`** — the sheet's rules need an
   `EQD`, and an LCL booking has none. See `docs/iftmbf` §7.6.
6. **`PickupLocation/PickupLocation/UnLocationCode`** is taken verbatim from the IFTMBF sheet
   and is not attested in the v3 sample — see `docs/iftmbf` §7.1.
7. **The upstream `?'` escaping defect is still live in production.** The converter handles it,
   so real IFTMBF captures are usable as fixtures here, but the production parser still rejects
   those messages. See `docs/iftmbf` §10 — it belongs with BASF.
8. **There is no IFCSUM mapping sheet**; that mapping is derived from `00-basf.md`, the
   contract and the captures.

9. **FCL is switched off.** `PROCESS_FCL` ships `false` in `InboundIftmin.dwl` and
   `InboundIftmbf.dwl`, because go-live carries LCL only. Both must hold the same value; flipping it
   means editing and re-uploading both blobs. See `docs/00-basf.md` *"FCL switch"*. Two
   consequences: an FCL interchange maps to `{ "seaHouseShipment": [] }` and **nothing in
   `config/` says whether the delivery step POSTs that or short-circuits**; and open item 5 below
   stops being an edge case, since LCL is now the only path.

10. **Vacating `portOfLoading` / `portOfDischarge` / `placeOfDelivery` needs a second opinion.**
    Spec v1.1 §5–§7 move POL, POD and Place of Delivery onto the customer UDFs, and rule 6 says
    the standard field must not be populated instead — which is also what vessel and voyage
    already did. But `portOfLoading` was resolving CarLo master data (real records come back with
    `designation: "Antwerpen"`, `cityCode: "ANR"`), so something downstream may read it. Confirm
    with the analyst.
