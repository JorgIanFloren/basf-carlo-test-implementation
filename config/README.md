# Cosmos DB configuration — BASF → Carlo

Documents for the `integration-store` database, `configurations` collection. One per file; the
`id` of each is a random UUID, as requested.

| File | Type | `id` | Ready to load |
|---|---|---|---|
| `dataProfiler-basf-iftmin.json` | `dataProfiler` | `8bb0a796-a4e9-412c-9d03-6cdf58da34d5` | after the checks below |
| `dataProfiler-basf-iftmbf.json` | `dataProfiler` | `51028866-5dcb-4c62-827d-92031cf414eb` | after the checks below |
| `dataProfiler-basf-ifcsum.json` | `dataProfiler` | `e1946007-460e-44ea-8de0-02c006b0fbca` | after the checks below |
| `dataGetter-basf-inbound.json` | `dataGetter` | `f3e0ae13-344e-43f6-8c67-3b26cff002f5` | **no** — `active: false`, placeholder transport |

`name` and `description` are informational. The platform reads only `id`, `active` and
`configuration`; extra top-level fields are ignored.

## The chain

Each profile wires the same four steps, differing only in subject, DWL and target path:

```
BASF EDIFACT interchange
  -> dataGetter      seq 1  sender BASF / receiver CARLO / subject IFTMIN|IFTMBF|IFCSUM
  -> dataTransformer seq 2  basf/Basf{Iftmin,Iftmbf,Ifcsum}.dwl
  -> dataDelivery    seq 3  HTTPS POST to Carlo
```

The `dataPipeline` pass-thru step that used to sit at seq 2 is gone; the three steps are
resequenced accordingly.

**This chain is now one step short of what the IFTMIN and IFTMBF mappings need.** Both flows in
`docs/00-basf.md` begin with "GET DOSSIER by CustomerRef", and both mappings consume its result;
there is no step here that performs it. See check 6 — it is the one outstanding piece of wiring,
and until it is added those two mappings run in their pre-lookup fallback mode.

Targets: `…/v3/SeaHouseShipment` for IFTMIN and IFTMBF, `…/v3/ShipmentCargo` for IFCSUM.

There is no `isedifact` / `isx12` flag on the transformer step. Those flags make the transformer
*write* EDI, which is the outbound direction; these three integrations are inbound and produce
JSON. What matters here is that the input blob is **read** as EDIFACT — see check 1.

## Before you load these

Six things are inferred rather than documented. Checks 1–5 are each a one-line fix if they turn
out wrong; check 6 is a missing step rather than a wrong value. The integration will not work
until they are confirmed.

**1. `inputMimeType: "application/edifact"` is what parses the interchange.**
The mappings expect the parsed structure `payload.EDI.Messages.<DIRECTORY>.<TYPE>[]`, which is
the `mule-edifact-extension` reader's output shape. Setting `inputMimeType` on the profiler,
pipeline and transformer steps is the mechanism this repo assumes produces it. **Confirm the
exact mime-type string the platform uses for inbound EDIFACT** — if the transformer receives raw
text instead, every mapping returns an empty array rather than failing loudly.

**2. ~~The DWL files import modules, so they are not self-contained.~~ Resolved — keep it that way.**
`ee:dynamic-evaluate` resolves imports off the application classpath, not off Blob Storage, so a
mapping that imports anything cannot run from an upload. The second of the two routes was taken:
the shared helpers are **inlined into each mapping**, and `src/main/dw/BasfIftmin.dwl`,
`BasfIftmbf.dwl` and `BasfIfcsum.dwl` are now three self-contained scripts with no `import` of a
project module. `CommonModule.dwl` and the old thin wrappers under `src/test/dw/` are deleted.

The cost is three copies of the helper block. Change one, change all three — the test suites run
each file as a whole script, so a copy that drifts fails rather than passing quietly.

Upload each to the `transforms` container under `basf/`, using the same name its `dwlPath`
carries:

```
az storage blob upload --account-name saeus2integrationdev001 --container-name transforms \
  --name "basf/BasfIftmin.dwl" --file ./src/main/dw/BasfIftmin.dwl
```

Repo filename, blob name and `dwlPath` are deliberately identical so they cannot drift apart.
Do not add an `import` to these files: it compiles and tests green locally (where the classpath
resolves it) and fails only at runtime in the transformer.

**3. The routing keys are a choice, not a given.**
`sender: "BASF"`, `receiver: "CARLO"`, `subject: "IFTMIN"|"IFTMBF"|"IFCSUM"`. Matching is exact
equality on all three, with no wildcards, so these must be byte-identical to whatever the inbound
API or key-extraction script produces. `CARLO` names the destination system; the platform's own
examples use `FRACHT` as the receiver for inbound flows, so **check which convention this team
follows** — a mismatch sends every message to the error queue with `No matching profile found`.

**4. The Carlo endpoint is the test host, and carries no authentication.**
`api-carlo-test.fracht.be:4712`, taken from `docs/new_solution_flowchart_as_sequence_diagram.txt`.
Substitute the production host before go-live. That flowchart shows plain calls, so no `authType`
is set; if Carlo requires credentials, add to the `dataDelivery` step:

```json
"authType": "Basic",
"username": "…",
"password": "…"
```

The `…/v3/ShipmentCargo` path for IFCSUM is inferred from the SeaHouseShipment path and the
contract's root element — **verify it against Carlo's Swagger.**

**5. The transport is unknown.**
Nothing in `docs/example-orders` says how BASF delivers these interchanges. The `dataGetter`
document is an SFTP-polling placeholder, shipped `active: false` with `CONFIRM_WITH_BASF` in place
of the username. If BASF instead pushes to an Azure Storage Queue, delete it and create a
`dataOrchestrator` document plus a key-extraction DWL; if BASF posts to the FrachtConnect inbound
API directly, delete it and nothing replaces it — the three `dataProfiler` documents are all that
is needed.

Note the SFTP path deletes each file from the partner server after successful pickup. Do not
enable it until BASF expects that.

**6. Nothing here performs the "GET dossier by CustomerRef" step, and both `seaHouseShipment`
mappings now consume its result.**
`BasfIftmin.dwl` and `BasfIftmbf.dwl` read the lookup response off **`payload.lookup`**, as the
server returned it:

```json
{ "EDI": { "Messages": { "…": { "IFTMIN": [ … ] } } },
  "lookup": { "seaHouseShipment": [ … ] } }
```

So a step is needed between seq 1 and the transformer that GETs
`…/v3/SeaHouseShipment?customerReference=<BGM0201>` and merges the response under `lookup`
without disturbing `EDI`. `payload.lookup` was chosen over a second context variable because the
transformer evaluates a mapping against `payload` and nothing else (check 2's constraint applies
here too), so there is nowhere else for it to arrive.

Three things this decides, none of which work without the step:

| Scenario | With the lookup | Without it |
|---|---|---|
| Master-sub IFTMIN update | each BL updates its own dossier | every BL upserts on `CustomerReference`, so the last one wins |
| IFTMBF for a master-sub order | one update per dossier of the order | one update, landing on one dossier |
| IFTMIN cancel | each dossier of the order is recycled | one upsert keyed on `CustomerReference` + BL |

**An absent `payload.lookup` is not an error.** Both mappings fall back to exactly the single-
upsert behaviour they had before the lookup existed, which is what lets them deploy now and
gain the addressing when the step lands. What is *not* safe is a step that runs the GET and
returns something other than `{ seaHouseShipment: [...] }` — `{ seaHouseShipment: [] }` must mean
"found nothing", because the cancel path reads it as "no dossier to recycle" and emits no call at
all. Real captures of every scenario's response are in `docs/get-responses/`, and the test suites
run against them.

The query must match `customerReference` **exactly**, and the mappings treat a near-miss as no
match rather than update the wrong record. Do not let the step "helpfully" widen the search to a
prefix or a `contains`: BASF references are close enough to one another that a loose query would
return a neighbouring order's dossier, which the mapping would then have no way to tell apart
from the right one.

## No cancel path is configured separately

All three mappings express cancellation inside the payload rather than through a different call:
IFTMIN code 1 emits `isInRecycleBin: true` on the same POST — one per dossier the lookup found —
and IFTMBF / IFCSUM code 1 produce an empty array. So one delivery step per profile still covers
create, update and cancel. The `HTTP DELETE` branch drawn in
`new_solution_flowchart_as_sequence_diagram.txt` is not used, and neither is
`actionAttribute: "delete"` any more: `docs/00-basf.md` ("IFTMIN / Canceling") now specifies a
recycle-and-upsert instead, which is what keeps a cancelled dossier out of later lookups rather
than removing it. See `docs/iftmin/01-IFTMIN_mapping_spec.md` §1.

## Cache lag

`dataProfiler` documents are cached 30 minutes, `dataOrchestrator` one hour. After loading or
editing, either wait or restart the orchestrator in CloudHub.
