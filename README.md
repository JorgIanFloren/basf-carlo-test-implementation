# BASF → Carlo integration

Three DataWeave mappings that turn BASF's inbound EDIFACT messages into calls on Carlo
(Soloplan) v3. Deployed on Fracht Connect, where the EDI parser hands each mapping the **parsed
JSON** representation of an interchange — the mappings never see EDIFACT.

| Message | Mapping | Transform library | Target contract | Spec |
|---|---|---|---|---|
| IFTMIN (instruction) | `src/test/dw/BasfIftmin.dwl` | `src/main/dw/IftminModule.dwl` | `docs/expected_output_SeaHouseShipment.json` | `docs/iftmin/01-IFTMIN_mapping_spec.md` |
| IFTMBF (firm booking) | `src/test/dw/BasfIftmbf.dwl` | `src/main/dw/IftmbfModule.dwl` | ″ | `docs/iftmbf/01-IFTMBF_mapping_spec.md` |
| IFCSUM (consolidation summary) | `src/test/dw/BasfIfcsum.dwl` | `src/main/dw/IfcsumModule.dwl` | `docs/expected_output_ShipmentCargo.json` | `docs/ifcsum/01-IFCSUM_mapping_spec.md` |

`src/main/dw/CommonModule.dwl` holds what all three share: date conversion, `camelKeys`, the
position-agnostic segment navigation, and `messagesOfType`.

Each mapping takes the **whole interchange** and returns an array, because one interchange can
legitimately carry several messages — that is exactly what a BASF master-sub is.

## Deploying

`config/` holds the Cosmos DB documents that add these three integrations to Fracht Connect —
one `dataProfiler` per message type wiring profiler → pipeline → transformer → delivery, plus a
placeholder `dataGetter` for the inbound transport. **Read `config/README.md` before loading
them**: five things in there are inferred rather than documented, including how the interchange
gets parsed to JSON and the fact that the DWL files import modules and so are not self-contained
uploads.

## Running the tests

```
cd basf
mvn -o test
```

116 tests. Every EDIFACT interchange in `docs/example-orders` is exercised by the mapping for
its message type: 21 IFTMIN, 9 IFTMBF, 4 IFCSUM.

## Fixtures

Test fixtures are **generated, not hand-written**:

```
python tools/edifact_to_json.py --all          # docs/example-orders -> src/test/resources/example-orders
python tools/edifact_to_json.py <in.txt>       # one file, to stdout
```

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

The converter also writes `src/test/resources/example-orders/manifest.json`: one row per
fixture recording its message type, directory, message count, master-sub flag, and per-message
BASF BL / BGM code / CustomerReference / equipment count — plus, for IFCSUM, the cargo lines it
should produce.

The mapping tests are driven from it. Because the manifest is built by walking the parsed tree
with explicit key lookups while the mappings walk it by segment-name suffix, the two reach the
same answer by different routes; the manifest is a cross-check, not a restatement.

## Watch out: the example filenames are wrong

Nearly every file in `docs/example-orders` is mislabelled. Classify by content, never by name:

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
| 1 (cancel) | identity-only delete | flow stops, nothing sent | flow stops, nothing sent |

The asymmetry is deliberate and follows `docs/00-basf.md`: a cancelled *instruction* removes the
shipment, but a cancelled *booking* or *consolidation summary* does not — see each spec's cancel
section.

## Open items

Collected from the three specs; each is written up where it belongs.

1. **The IFTMIN cancel shape is unconfirmed** — no example message exists, and `00-basf.md`
   marks step 1b as to be confirmed by Robin/Niels.
2. **24 fields the IFTMIN mapping emits are not attested in any contract sample.** They come
   from the Create sheet's XPaths but appear in neither `expected_output_SeaHouseShipment.json`
   nor the v3 XML sample — both of which are export dumps rather than schemas. Carlo ignores
   unknown fields silently. Check them against Carlo's Swagger.
   (`expected_output_ShipmentCargo.json` *is* a schema, so IFCSUM is fully verified against it.)
3. **Multi-container IFCSUM** would lose its VGM data — see `docs/ifcsum` §7.1.
4. **LCL bookings lose `HaulageType` and `EstimatedDispatchDate`** — the sheet's rules need an
   `EQD`, and an LCL booking has none. See `docs/iftmbf` §7.6.
5. **`PickupLocation/PickupLocation/UnLocationCode`** is taken verbatim from the IFTMBF sheet
   and is not attested in the v3 sample — see `docs/iftmbf` §7.1.
6. **The upstream `?'` escaping defect is still live in production.** The converter handles it,
   so real IFTMBF captures are usable as fixtures here, but the production parser still rejects
   those messages. See `docs/iftmbf` §10 — it belongs with BASF.
7. **There is no IFCSUM mapping sheet**; that mapping is derived from `00-basf.md`, the
   contract and the captures.
