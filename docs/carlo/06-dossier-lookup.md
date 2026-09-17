# The dossier lookup

This page specifies the **"GET dossier by CustomerRef"** call that `InboundIftmin.dwl` and
`InboundIftmbf.dwl` consume. In both profiles it is the `dataDelivery` step at **sequence 3**, and
it does not extend the payload: it hands the next step an envelope of two sibling nodes —
`originalPayload` (the message as it entered FrachtConnect) and `payload` (this GET's response).
See [Where the response lands](#where-the-response-lands) below. This page is otherwise about what
the call itself has to look like, and everything here is verified against the live test server.

## Why it exists

A BASF master-sub order is several house-shipment dossiers sharing one `customerReference`, one
per bill of lading (`BL01`, `BL02`, …). CarLo's `updateorcreate` matches on `customerReference`
alone — it says so in the miss message, see
[§ actionAttribute](01-calling-the-api.md#actionattribute) — so an upsert cannot address one
dossier of such an order: every entry resolves onto the same record and the last one wins.

Only `customerReference` **plus** the BASF BL identifies a dossier. Neither is CarLo's `id`, so
the mapping cannot construct a `PUT` target either. The way out is to read the order's dossiers
first and let the mapping match each message to its own record by value.

## The call

```
GET /api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment/0
      ?$filter=700071%20eq%20'<customerReference>'
Accept:    application/json
X-API-Key: <key>
```

- `700071` is `customerReference` — [05-filter-properties.md](05-filter-properties.md).
- `<customerReference>` is `BGM0201` of the message, the BASF order number (`2800209301`).
- `/0` is required: it is what makes the request a search rather than a fetch by id.
- Spaces **must** be `%20`. Sent as `+` this is an HTTP `500`, not an empty result —
  [§ $filter](01-calling-the-api.md#4-filter).
- `Accept: application/json` is required or the call is an HTTP `500` —
  [§ Headers](01-calling-the-api.md#3-headers).
- **`$top` is deliberately not set**, although it defaults to 50 and truncates in silence
  ([§ $top](01-calling-the-api.md#top-defaults-to-50)). This filter matches the dossiers of *one*
  order, and that is a master-sub's bill-of-lading count — in practice far below 50. Confirmed by
  the integration team on 2026-09-17. The general warning still holds for any other call on this
  API; it is this query's result set that cannot grow. If an order ever did exceed 50, the
  symptom would be a silently short result rather than an error, and the fix is `&%24top=200` on
  the seq 3 path of both profiles.

Verified against the test server: this returns HTTP `200` and the full 115-field dossier objects.

### Do not filter on the BL

It is tempting to narrow the call to one dossier, either by adding `and 700199 eq '<bl>'`
(`bASFBL`) or by filtering `700147` (`eDIID`, which is `customerReference ++ bASFBL`). Both work —
both were verified — but neither is the right call here:

- One interchange carries **several** messages, each with its own BL, and the mappings expect the
  whole order in one response. Per-BL filtering would mean one GET per message.
- The cancel path needs *every* dossier of the order, because a cancel recycles all of them.
- An IFTMBF that arrived before its IFTMIN created a dossier with **no** BL at all, and
  `bookingOnlyDossier` in both mappings looks for exactly that record. A BL filter hides it.

Filter on `customerReference` and let the mapping do the matching.

## Where the response lands

A `dataDelivery` step does not extend the payload it was given — that was an assumption, and it
was wrong. It passes on an envelope of two sibling nodes: the message that entered FrachtConnect,
under the node named by `originalPayloadNodeName` on the step, and this call's response, under
`payload`:

```json
{ "originalPayload": { "EDI": { "Messages": { "…": { "IFTMIN": [ … ] } } } },
  "payload":         { "seaHouseShipment": [ … ] } }
```

That is what the seq 4 data-transformer evaluates the mapping against, so `InboundIftmin.dwl` and
`InboundIftmbf.dwl` each read the interchange off `payload.originalPayload` and the dossiers off
`payload.payload`. Both accessors live in one place in each mapping ("The pipeline envelope"), and
`originalPayload` is a configured name: rename it on the step and rename it there.

This is not inferred. `docs/documentation-input/inbound/mulesoft-iftmin-get-existing-append-original.json`
and its IFTMBF twin are captures of what each mapping was actually handed on 2026-09-17, and both
test suites run against them — see [Captures](#captures).

The reference the call filters on is not taken from this payload by the step itself. The
`dataPipeline` at sequence 2 extracts `BGM0201` and injects it into the seq 3 path in place of
`<dynamicReference>`.

## What the mappings need from the response

Four fields carry the addressing, and both mappings read them by value, never by position — the
GET returns dossiers in no defined order:

| Field | Role |
|---|---|
| `customerReference` | the BASF order number; the same on every dossier of a master-sub |
| `bASFBL` | `BL00` for a plain order, `BL01`/`BL02`/… for a master-sub, **empty** on a dossier an IFTMBF created on its own |
| `eDIID` | `customerReference ++ bASFBL` — the composite that does identify one dossier |
| `id` | CarLo's own record number |
| `isInRecycleBin` | `true` on a cancelled dossier, which still comes back from the GET |

`isInRecycleBin` is filtered client-side by `liveDossiers` in both mappings, and that filter is
load-bearing rather than cosmetic: a cancel marks a dossier recycled instead of deleting it, so a
re-sent order would otherwise update — and so resurrect — a dossier that was deliberately
cancelled.

## Contract the step has to satisfy

1. **Return the server's response verbatim** as `{ "seaHouseShipment": [ … ] }` on the `payload`
   node. Both mappings read `payload.payload.seaHouseShipment`; any other shape is read as "no
   lookup ran" (contract 4), not as an error.
2. **`{ "seaHouseShipment": [] }` must mean "found nothing".** The cancel path reads an empty
   array as "no dossier to recycle" and emits no call at all, so an empty array must never stand
   in for an error.
3. **Keep `originalPayloadNodeName` set.** Without it the interchange never reaches the
   transformer, and every message maps to an empty array — which looks exactly like "nothing to
   send" rather than like a failure.
4. **A response that is not a `seaHouseShipment` object is not an error either.** Both mappings
   fall back to the single-upsert behaviour they had before the lookup existed, so a failed or
   misconfigured GET degrades to the pre-lookup flow instead of silently claiming the order has
   no dossiers.

A failed GET must therefore be distinguishable from an empty one — propagate the failure, or let
the body be anything other than `{ "seaHouseShipment": … }` so the fallback engages. Returning
`{ "seaHouseShipment": [] }` for an HTTP `500` would turn a cancel into a silent no-op.

## Which order number to look up

One GET per **interchange**, on the `customerReference` the messages share — not one per message.
All messages of a master-sub interchange carry the same `BGM0201`; if an interchange ever carried
two different ones, the step would need a GET per distinct value merged into one array, and the
mappings would still work because every match is by value.

## Captures

`docs/get-responses/` holds real captures of this call for each scenario — FCL, LCL, master-sub
FCL, master-sub LCL, in both arrival orders, plus a not-found response — and the mapping test
suites run against them. Because they are real server responses rather than hand-written
expectations, the dossier ids and reference fields the tests assert are records the integration
actually created.

`docs/documentation-input/inbound/mulesoft-{iftmin,iftmbf}-get-existing-append-original.json` are
captures of the whole **envelope** rather than of the response alone — the transformer's input as
the seq 3 step handed it over. Both are order `2800209301_RV1`, an FCL order whose GET returned
the one `BL00` dossier (CarLo id `1564415`). Running the mappings over them confirms end to end
what this page specifies: the instruction resolves onto that record with `actionAttribute:
"update"`, the booking updates the same record, and the vessel, ports, ETD and three containers
come off `originalPayload` while the id comes off `payload`. `src/test/resources/envelopes/` is
the classpath copy the suites load.
