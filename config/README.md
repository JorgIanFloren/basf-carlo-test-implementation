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
  -> dataProfiler   seq 1   sender BASF / receiver CARLO / subject IFTMIN|IFTMBF|IFCSUM
  -> dataPipeline   seq 2   pass-thru
  -> dataTransformer seq 3  basf/Basf{Iftmin,Iftmbf,Ifcsum}.dwl
  -> dataDelivery   seq 4   HTTPS POST to Carlo
```

Targets: `…/v3/SeaHouseShipment` for IFTMIN and IFTMBF, `…/v3/ShipmentCargo` for IFCSUM.

There is no `isedifact` / `isx12` flag on the transformer step. Those flags make the transformer
*write* EDI, which is the outbound direction; these three integrations are inbound and produce
JSON. What matters here is that the input blob is **read** as EDIFACT — see check 1.

## Before you load these

Five things are inferred rather than documented. Each is a one-line fix if it turns out wrong,
but the integration will not work until they are confirmed.

**1. `inputMimeType: "application/edifact"` is what parses the interchange.**
The mappings expect the parsed structure `payload.EDI.Messages.<DIRECTORY>.<TYPE>[]`, which is
the `mule-edifact-extension` reader's output shape. Setting `inputMimeType` on the profiler,
pipeline and transformer steps is the mechanism this repo assumes produces it. **Confirm the
exact mime-type string the platform uses for inbound EDIFACT** — if the transformer receives raw
text instead, every mapping returns an empty array rather than failing loudly.

**2. The DWL files import modules, so they are not self-contained.**
`BasfIftmin.dwl` does `import * from CommonModule` / `IftminModule`. `ee:dynamic-evaluate`
resolves imports off the application classpath, not off Blob Storage, so uploading the three
mapping files alone is **not** enough. Either:

- publish this project (it is a `dw-library`) to Anypoint Exchange and add it as a dependency of
  `data-transformer` — uncomment `distributionManagement` in `pom.xml`; or
- inline the module sources into each mapping before upload, producing three self-contained
  scripts.

Whichever route, upload to the `transforms` container under `basf/`:

```
az storage blob upload --account-name saeus2integrationdev001 --container-name transforms \
  --name "basf/BasfIftmin.dwl" --file ./src/test/dw/BasfIftmin.dwl
```

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

## No cancel path is configured separately

All three mappings express cancellation inside the payload rather than through a different call:
IFTMIN code 1 emits `actionAttribute: "delete"` on the same POST, and IFTMBF / IFCSUM code 1
produce an empty array. So one delivery step per profile covers create, update and cancel. The
`HTTP DELETE` branch drawn in `new_solution_flowchart_as_sequence_diagram.txt` is not used — see
`docs/iftmin/01-IFTMIN_mapping_spec.md` §1.

## Cache lag

`dataProfiler` documents are cached 30 minutes, `dataOrchestrator` one hour. After loading or
editing, either wait or restart the orchestrator in CloudHub.
