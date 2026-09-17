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

Each profile wires the same steps, differing only in subject, DWL and target path. IFCSUM wires
three; IFTMIN and IFTMBF wire five, because both of those flows open with "GET DOSSIER by
CustomerRef" and both mappings consume its result.

```
BASF EDIFACT interchange
  -> dataProfiler    seq 1  sender basf_ocean / receiver FrachtConnect / subject iftmin|iftmbf
  -> dataPipeline    seq 2  manipulate-metadata: reads BGM0201 and injects it into seq 3
  -> dataDelivery    seq 3  HTTPS GET to Carlo; hands on { originalPayload, payload }
                            (IFTMIN and IFTMBF only - IFCSUM needs no lookup)
  -> dataTransformer seq 4  Fracht-Belgium/basf/basf-inbound-{iftmin,iftmbf,ifcsum}-to-carlo.dwl
  -> dataDelivery    seq 5  HTTPS POST to Carlo
```

**The lookup step is a `dataDelivery`, and it does not extend the payload.** That was the earlier
assumption and it was wrong: FrachtConnect never populates a `lookup` key. The step passes on an
envelope of two sibling nodes — the message as it entered the system, under the node named by
`originalPayloadNodeName` on the step, and the GET response under `payload`:

```json
{ "originalPayload": { "EDI": { "Messages": { "…": { "IFTMIN": [ … ] } } } },
  "payload":         { "seaHouseShipment": [ … ] } }
```

`InboundIftmin.dwl` and `InboundIftmbf.dwl` both read the two halves off that envelope — see "The
pipeline envelope" in either mapping and `docs/carlo/06-dossier-lookup.md`. Only the directory and
message type differ between the two (`D99A`/`IFTMIN`, `D08A`/`IFTMBF`).

Write targets: `…/v3/SeaHouseShipment` for IFTMIN and IFTMBF, `…/v3/ShipmentCargo` for IFCSUM.
The lookup step reads from `…/v3/SeaHouseShipment/0`.

There is no `isedifact` / `isx12` flag on the transformer step. Those flags make the transformer
*write* EDI, which is the outbound direction; these three integrations are inbound and produce
JSON. What matters here is that the input blob is **read** as EDIFACT — see check 1.

## Before you load these

Six things are inferred rather than documented. Checks 1–5 are each a one-line fix if they turn
out wrong; check 6 is the lookup step, which is now wired on both profiles and needs nothing
further. The integration will not work until checks 1-5 are confirmed.

**1. `inputMimeType: "application/edifact"` is what parses the interchange.**
The mappings expect the parsed structure `EDI.Messages.<DIRECTORY>.<TYPE>[]` (for IFTMIN and
IFTMBF, under the envelope's `originalPayload` node — see the chain above), which is
the `mule-edifact-extension` reader's output shape. Setting `inputMimeType` on the profiler,
pipeline and transformer steps is the mechanism this repo assumes produces it. **Confirm the
exact mime-type string the platform uses for inbound EDIFACT** — if the transformer receives raw
text instead, every mapping returns an empty array rather than failing loudly.

**2. ~~The DWL files import modules, so they are not self-contained.~~ Resolved — keep it that way.**
`ee:dynamic-evaluate` resolves imports off the application classpath, not off Blob Storage, so a
mapping that imports anything cannot run from an upload. The second of the two routes was taken:
the shared helpers are **inlined into each mapping**, and `src/main/dw/InboundIftmin.dwl`,
`InboundIftmbf.dwl` and `InboundIfcsum.dwl` are now three self-contained scripts with no `import` of a
project module. `CommonModule.dwl` and the old thin wrappers under `src/test/dw/` are deleted.

The cost is three copies of the helper block. Change one, change all three — the test suites run
each file as a whole script, so a copy that drifts fails rather than passing quietly.

Upload each to the `transforms` container under the name its `dwlPath` carries — the platform's
naming, which differs from the repo filename:

| Repo file | `dwlPath` / blob name |
|---|---|
| `src/main/dw/InboundIftmin.dwl` | `Fracht-Belgium/basf/basf-inbound-iftmin-to-carlo.dwl` |
| `src/main/dw/InboundIftmbf.dwl` | `Fracht-Belgium/basf/basf-inbound-iftmbf-to-carlo.dwl` |
| `src/main/dw/InboundIfcsum.dwl` | `basf/InboundIfcsum.dwl` (the IFCSUM profile still carries the old name) |

```
az storage blob upload --account-name saeus2integrationdev001 --container-name transforms \
  --name "Fracht-Belgium/basf/basf-inbound-iftmin-to-carlo.dwl" --file ./src/main/dw/InboundIftmin.dwl
```

Each mapping's header names the blob it deploys as, so the pairing is stated in both places.
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
Nothing in `docs/example-orders/inbound` says how BASF delivers these interchanges. The `dataGetter`
document is an SFTP-polling placeholder, shipped `active: false` with `CONFIRM_WITH_BASF` in place
of the username. If BASF instead pushes to an Azure Storage Queue, delete it and create a
`dataOrchestrator` document plus a key-extraction DWL; if BASF posts to the FrachtConnect inbound
API directly, delete it and nothing replaces it — the three `dataProfiler` documents are all that
is needed.

Note the SFTP path deletes each file from the partner server after successful pickup. Do not
enable it until BASF expects that.

**6. ~~Two field names on the seq 2 lookup step are guesses.~~ Resolved — the step is wired.**
In both `dataProfiler-basf-iftmin.json` and `dataProfiler-basf-iftmbf.json` the GET is the
`dataDelivery` at sequence 3, the reference is injected into its path in place of
`<dynamicReference>` by the `dataPipeline` at sequence 2, and the response reaches the
transformer as the `payload` node of the envelope described above, beside `originalPayload`.
Everything about the CarLo call itself is verified against the live server
(`docs/carlo/06-dossier-lookup.md`) — host, path, method, `$filter` and both required headers.
The envelope shape is verified too, against captures of what each transformer was actually
handed: `docs/documentation-input/inbound/mulesoft-{iftmin,iftmbf}-get-existing-append-original.json`,
which both test suites run against.

No `$top` is set, deliberately. It defaults to 50 and truncates in silence (check the `$top`
section of `docs/carlo/01-calling-the-api.md` before reusing this pattern elsewhere), but this
filter returns the dossiers of one order — a master-sub's BL count, in practice far below 50.
Confirmed by the integration team on 2026-09-17.

The reference the GET filters on comes from the seq 2 `dataPipeline`
(`basf-ocean-iftmin-iftmbf-manipulate-metadata.dwl`, which lives in the blob container rather
than this repo): it reads `BGM0201` and injects it into the seq 3 path where `<dynamicReference>`
sits. `BGM0201` is at `Heading."0020_BGM".BGM0201` of the first message in **both** directories
(D99A/IFTMIN and D08A/IFTMBF), so one expression shape covers both profiles — only the directory
and message-type level differ:

```
EDI.Messages.D99A.IFTMIN[0].Heading."0020_BGM".BGM0201     (iftmin profile)
EDI.Messages.D08A.IFTMBF[0].Heading."0020_BGM".BGM0201     (iftmbf profile)
```

Take the **first** message, not each: every message of a master-sub interchange carries the same
`BGM0201`, so it is one GET per interchange. Prefer a directory-agnostic expression if the
templating supports one — the mappings read the directory level generically precisely because a
bump from D99A would otherwise go unnoticed, and here it would silently yield no reference, no
lookup, and a quiet slide back into fallback mode.

The envelope is how both halves reach the mapping at all: the transformer evaluates a mapping
against `payload` and nothing else (check 2's constraint applies here too), so the interchange
has to travel inside it beside the response — which is exactly what `originalPayloadNodeName`
arranges.

Three things this step decides, none of which work without it:

| Scenario | With the lookup | Without it |
|---|---|---|
| Master-sub IFTMIN update | each BL updates its own dossier | every BL upserts on `CustomerReference`, so the last one wins |
| IFTMBF for a master-sub order | one update per dossier of the order | one update, landing on one dossier |
| IFTMIN cancel | each dossier of the order is recycled | one upsert keyed on `CustomerReference` + BL |

**A response that is not a `seaHouseShipment` object is not an error.** The mapping falls back to
exactly the single-upsert behaviour it had before the lookup existed, which is what let it deploy
while this step was still being wired — and what keeps a misconfigured step from looking like an
order with no dossiers. What is *not* safe is a step that runs the GET and returns
`{ seaHouseShipment: [] }` for something other than a real empty result: that must mean "found
nothing", because the cancel path reads it as "no dossier to recycle" and emits no call at all.
Real captures of every scenario's response are in `docs/get-responses/`, and the test suites run
against them.

**A failed GET must be distinguishable from an empty one.** Propagate the failure, or let the
body be anything other than `{ seaHouseShipment: … }` so the fallback engages. Returning
`{ "seaHouseShipment": [] }` for an HTTP 500 would turn a cancel into a silent no-op.

**Spaces in `$filter` must be `%20`, never `+`.** Sent as `+` this is an HTTP 500, not an empty
result. If the step URL-encodes query parameters itself, check which of the two it produces.

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
