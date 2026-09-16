# The dossier lookup

This page specifies the **"GET dossier by CustomerRef"** call that `BasfIftmin.dwl` and
`BasfIftmbf.dwl` read off `payload.lookup`. It is wired as a `dataDelivery` step at sequence 2 of
the IFTMIN and IFTMBF profiles — that step type can fetch from another source and *extend* the
payload rather than replace it. See `config/README.md` check 6 for the two field names on that
step that are still unconfirmed; this page is only about what the call itself has to look like,
and everything here is verified against the live test server.

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
      &$top=200
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
- `$top` must be set. It defaults to 50 and truncates silently, and a master-sub order plus the
  re-runs an order accumulates can exceed that.

Verified against the test server: this returns HTTP `200` and the full 115-field dossier objects.

### Do not filter on the BL

It is tempting to narrow the call to one dossier, either by adding `and 700199 eq '<bl>'`
(`bASFBL`) or by filtering `700147` (`eDIID`, which is `customerReference ++ bASFBL`). Both work —
both were verified — but neither is the right call here:

- One interchange carries **several** messages, each with its own BL, and the mappings expect the
  whole order in one `payload.lookup`. Per-BL filtering would mean one GET per message.
- The cancel path needs *every* dossier of the order, because a cancel recycles all of them.
- An IFTMBF that arrived before its IFTMIN created a dossier with **no** BL at all, and
  `bookingOnlyDossier` in both mappings looks for exactly that record. A BL filter hides it.

Filter on `customerReference` and let the mapping do the matching.

## What the mappings need from the response

The response goes onto the payload **unchanged**, under a `lookup` key, beside the parsed
interchange:

```json
{ "EDI":    { "Messages": { "…": { "IFTMIN": [ … ] } } },
  "lookup": { "seaHouseShipment": [ … ] } }
```

`payload.lookup` was chosen because the data-transformer evaluates a mapping against `payload`
and nothing else, so there is nowhere else for it to arrive.

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

1. **Return the server's response verbatim** as `{ "seaHouseShipment": [ … ] }`. Both mappings
   read `payload.lookup.seaHouseShipment` directly; any other shape is silently wrong.
2. **`{ "seaHouseShipment": [] }` must mean "found nothing".** The cancel path reads an empty
   array as "no dossier to recycle" and emits no call at all, so an empty array must never stand
   in for an error.
3. **Do not disturb `EDI`.** The mapping still has to find the parsed interchange where it was.
4. **An absent `payload.lookup` is not an error.** Both mappings fall back to the single-upsert
   behaviour they had before the lookup existed, which is what lets them deploy without this step
   and gain the addressing when it lands.

A failed GET must therefore be distinguishable from an empty one — propagate the failure, or omit
`lookup` entirely so the fallback engages. Returning `{ "seaHouseShipment": [] }` for an HTTP
`500` would turn a cancel into a silent no-op.

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
