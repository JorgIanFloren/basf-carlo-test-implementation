# Calling the CarLo API

Everything in this page was checked against the live test server on 2026-09-16. Where a claim is
inferred rather than observed it says so.

## 1. Endpoint

```
https://api-carlo-test.fracht.be:4712/api/PolytraSeafreightHouseShipment_BASF/v3/<Resource>
```

The host serves **many** contracts side by side — one per integration — and each is a separate
path prefix, a separate Swagger document and a separate set of configured permissions. The
contract name is part of the URL, so there is no notion of calling "the CarLo API" generically:
you call `PolytraSeafreightHouseShipment_BASF/v3` or you call something else.

The port is non-standard (`4712`) and the certificate on the test host does not validate against
the public roots, so `curl` needs `-k` and a JVM/HTTP client needs the certificate in its trust
store. That is a property of the test environment, not of the API.

Resources on this contract: [`SeaHouseShipment`](02-seahouseshipment.md) and
[`ShipmentCargo`](03-shipmentcargo.md), each with the same four operations:

| Operation | Path | Meaning |
|---|---|---|
| `POST` | `/<Resource>` | write — create, update or upsert, decided per entry by `actionAttribute` |
| `GET` | `/<Resource>/{id}` | read one by `id`, or `id=0` plus a `$filter` to search |
| `PUT` | `/<Resource>/{id}` | update the record with that `id` |
| `DELETE` | `/<Resource>/{id}` | delete the record with that `id` |

`POST` is the one this repo uses for writes: it takes an array, so it covers create and update
both, and it needs no `id` — which matters because the mappings do not have one. `PUT` and
`DELETE` need CarLo's internal `id`, which only a lookup can supply.

Two sibling service documents exist outside the contract prefix:

- `POST /login` — exchange credentials for a JWT (§2)
- `GET /reset` — make the server drop its cached model configuration and reload it from the CarLo
  database. An administrative action; call it only after the contract itself has been changed
  server-side, never as part of normal traffic.

## 2. Authentication

Three schemes, all declared at the document level, so any one of them authorises any request:

| Scheme | How |
|---|---|
| API key | `X-API-Key: <key>` |
| Bearer | `Authorization: Bearer <jwt>` |
| Basic | `Authorization: Basic base64(user:password)` |

**API key is what this repo uses.** The test key is in `config/dataProfiler-basf-*.json` under
`dataDelivery.headers`; keys are issued per integration by the CarLo administrator, and the key
carries the permissions — which contract, and which of read/create/update/delete on it. A key
without create rights on a resource gets `400`, not `403`.

A missing or wrong key is `401` with an **empty body**. There is nothing to parse, so a client
that only logs response bodies will log nothing at all for an auth failure; branch on the status
code.

For a bearer token instead:

```
POST /login
Content-Type: application/x-www-form-urlencoded

username=<user>&password=<password>&organizationNumber=0
```

`organizationNumber: 0` means "the first organisation this user belongs to". The response is
`{ "access_token": "...", "expires_in": <seconds>, "token_type": "Bearer" }`. Not verified here —
no credentials were available — so the field names come from the `login` Swagger document.

## 3. Headers

| Header | When | Notes |
|---|---|---|
| `X-API-Key` | every request | or one of the other two schemes |
| `Accept: application/json` | **required on GET** | see below |
| `Content-Type: application/json` | **required on POST/PUT** | see below |

**`Accept` on GET is not optional.** Without it the server answers `500` with
`{"message":"Specify a supported data format."}`. `*/*` — what `curl` and many HTTP clients send
by default — does not count. Supported: `application/json`, `application/xml`. `text/csv` is
advertised in the Swagger document but answers `406`.

**`Content-Type` on POST is not optional either**, and its failure mode is different: a POST with
a body and no `Content-Type` is `415` with an ASP.NET *ProblemDetails* body
(`{"type":"https://tools.ietf.org/html/rfc9110...","title":"Unsupported Media Type","status":415}`)
rather than the API's own envelope. Two different error shapes come out of this API and this is
the boundary between them: anything the framework rejects before the contract handler runs looks
like ProblemDetails; everything after looks like §6.

`Accept` is *not* needed on POST — a write answers JSON regardless.

The XML representation is real, not a stub: `Accept: application/xml` on a GET returns
`<SeaHouseShipmentData xmlns="PolytraSeafreightHouseShipment_BASF.v3">` with **PascalCase**
element names, served as `Content-Type: text/plain`. JSON is the better target; the XML form is
worth knowing only because `docs/API v3 Sample_20260612-140452_101.xml` in this repo is exactly
that.

## 4. `$filter`

`GET /<Resource>/0?$filter=…` searches. The `id` path segment still has to be there and has to be
`0` — that is what makes it a search rather than a fetch.

CarLo's filter language looks like OData but addresses fields by **numeric property id**, never
by name:

```
$filter=700071 eq '2800209301'          customerReference equals that
$filter=700071 eq '2800209301' and 700199 eq 'BL00'
$filter=startswith(700071,'28002093')
$filter=186056 ge datetime'2026-01-01' and 186057 le datetime'2026-12-31'
```

Operators: `eq`, `ge`, `le`, and the functions `startswith`, `endswith`, `contains` — per
property, per [05-filter-properties.md](05-filter-properties.md). Strings take single quotes,
dates take `datetime'…'`, numbers are bare. `and` and `or` combine clauses.

### Encode spaces as `%20`, never `+`

This is the sharp edge. Form-style encoding, where a space becomes `+`, produces:

```
HTTP 500
{"message":"The filter expression \"$filter=700071+eq+'2800209301'\" did not produce any
            applicable filter criteria. (Parameter 'filterString')"}
```

`curl --data-urlencode` and most HTTP-client query-parameter builders encode spaces that way by
default, which makes this the first thing to check when a filter that looks right returns
nothing. The failure is a `500`, so it does not read as "your input was wrong".

The `$` itself may be sent literally or as `%24`; both work.

A filter naming a property id the contract does not expose is not an error either — it is
dropped, and you get the unfiltered result set silently. Take the ids from
[05-filter-properties.md](05-filter-properties.md) rather than guessing.

### `$top` defaults to 50

`$top` caps the result count and **defaults to 50**, with no indication in the response that
anything was cut off — no total, no next-page link, no flag. There is no `$skip`, so 50 is not the
first page of anything: it is just the first 50 rows CarLo happened to return, in no defined
order. Any filter that can legitimately match more than a handful of records needs `$top` set
explicitly, and a filter that must be exhaustive needs to be narrow enough that it is.

### A miss is `200`, not `404`

`GET /SeaHouseShipment/1` for an `id` that does not exist returns `200` with
`{"seaHouseShipment": []}`. So does a filter that matches nothing. `404` is documented in the
Swagger for the write operations but a read never produces it — check the array's length, not the
status code.

## 5. Request bodies

Both resources take the same shape: an object with one key, named after the resource with a
lower-case first letter, holding an **array**.

```json
{ "seaHouseShipment": [ { … }, { … } ] }
```

```json
{ "shipmentCargo": [ { … } ] }
```

The array is required even for a single record, on `POST` and `PUT` alike, and `GET` answers in
the same envelope.

### Field naming

The JSON contract is PascalCase with the **first letter lower-cased**, and it applies that rule
mechanically — which is why the acronym fields look wrong but are right:

```
hSCode   mRN   bASFBL   eDIID   gTIN   tEU   lCNumber   aCIDNumber
vGMDate  aMSHouseBillOfLadingNumber   sIClosing   cOOInvoiceRequired
```

CarLo ignores a field it does not recognise, without a warning, so `HSCode` or `hsCode` is not an
error — it is a value that silently never arrives. (This is what `camelKeys` in the three
mappings exists to get right, and why the mappings are written in PascalCase and lower-cased on
the way out.)

### Quantities

Weights, volumes, counts, temperatures and amounts are declared `type: object` with no properties
in the Swagger document — `totalGrossWeight`, `verifiedGrossMass`, `tareWeight`,
`totalNumberOfPackages`, `goodsValue`, `insuranceAmount`, `flashpoint`, and the rest. That is an
artefact of how the document was generated from CarLo's internal quantity type. On the wire they
are **plain JSON numbers**:

```json
"verifiedGrossMass": 4350.0,
"totalNumberOfPackages": 35.0,
"goodsValue": 0
```

The unit is fixed by the field, not carried with the value. Sending `{}` or `{"value":…}` is a
field CarLo discards.

### `actionAttribute`

Every object in the contract — the root entries and every nested type — carries an optional
`actionAttribute` that decides what CarLo does with it:

| Value | Meaning |
|---|---|
| `create` | insert; fails if a matching record exists |
| `update` | update the matching record; **fails if none exists** |
| `updateorcreate` | upsert |
| `delete` | delete the matching record |

Omitted, CarLo applies its own default per type, which is not documented. Set it explicitly.

"The matching record" is the thing to be careful about: for `SeaHouseShipment` the match is on
**`customerReference`**, which the server says out loud when it misses —

```
"Search was not successful for the property SeaHouseShipment.
 Search parameter: <ref> Customer Reference: <ref>."
"The action Update for the element of the type SeaHouseShipment cannot be executed as it
 does not exist."
```

— so an `updateorcreate` cannot address one dossier of a BASF master-sub order, where several
dossiers share a `customerReference`. That is what
[06-dossier-lookup.md](06-dossier-lookup.md) solves.

`actionAttribute` on a **nested** object governs that object independently of its parent, which is
how a single shipment update can add one container and leave the others alone.

### Writing several records in one call

The array takes many entries and CarLo processes them in order, reporting one `dataSets[]` entry
per input entry (§6). A master-sub order goes out as one call with one entry per bill of lading.

Whether a failing entry rolls back the ones before it is **not verified here** — establishing it
would mean writing records to the test system. Treat a partial-failure response as partially
applied until someone confirms otherwise: check `dataSets[]` per entry rather than only the
top-level status.

## 6. Responses

### Read

```json
{ "seaHouseShipment": [ … ] }
```

Nothing else — no envelope, no count, no paging. `200` even when the array is empty.

### Write

Every write answers with a **processing log**, whatever the outcome:

```json
{
  "processingResult": "ok",
  "date": "2026-09-16T11:24:28.02+02:00",
  "typeIdentifier": "PolytraSeafreightHouseShipment_BASF.v3-SeaHouseShipment",
  "dataSets": [],
  "readOnlyValidationMessages": [],
  "validationMessages": [],
  "message": null,
  "queueId": null,
  "statusCode": 200
}
```

| Field | Notes |
|---|---|
| `processingResult` | `"ok"` or `"error"` on a write. On a read error it comes back as the number `1` — the field is not reliably typed, so compare against `statusCode` instead |
| `statusCode` | mirrors the HTTP status |
| `dataSets[]` | **one entry per input record** — this is where per-record outcomes live |
| `validationMessages[]` | request-level problems, i.e. ones not attributable to a single record |
| `message` | a single human-readable string; set on the framework-ish failures (bad filter, bad `Accept`) and `null` when `dataSets` carries the detail |
| `queueId` | for asynchronous processing: the handle that correlates the enqueue response with the eventual result. `null` throughout the synchronous flow this repo uses |
| `readOnlyValidationMessages[]` | present on the wire, absent from the Swagger document; a duplicate of `validationMessages` annotated with `defaultVisibility` |

Each `dataSets[]` entry:

```json
{
  "processingResult": "error",
  "action": "update",
  "internalId": null,
  "defaultFilterValues": [],
  "validationMessages": [
    { "code": 0, "level": "warning", "message": "Search was not successful …",
      "relatedPropertyId": 0, "additionalInfo": null, "innerMessageResults": [] },
    { "code": 0, "level": "error",   "message": "The action Update … cannot be executed as it
      does not exist.", "relatedPropertyId": 0, "innerMessageResults": [] }
  ],
  "exceptionMessage": null,
  "responseObject": null
}
```

`level` separates `warning` from `error`; a `warning` alone does not fail the record. `code` and
`relatedPropertyId` were `0` in everything observed — do not build logic on them.

### Status codes

| Code | Meaning | Body |
|---|---|---|
| `200` | processed — including a read that matched nothing | processing log / result array |
| `400` | validation failed, or the key lacks that right on that resource | processing log, detail in `dataSets[]` |
| `401` | no or bad credentials | **empty** |
| `403` | authenticated, forbidden | — |
| `404` | documented for writes; not produced by reads | `ErrorResponse` |
| `415` | `Content-Type` missing or wrong on a write | ProblemDetails, not the API envelope |
| `500` | bad `$filter` encoding, unacceptable `Accept`, or a genuine server fault | processing log with `message` set |

`500` here is routinely *your* fault rather than the server's — §3 and §4 are both `500`s. Read
`message` before escalating.

## 7. A checklist for a new client

1. `X-API-Key` on every request.
2. `Accept: application/json` on every GET.
3. `Content-Type: application/json` on every POST/PUT.
4. Body wrapped in `{"<resource>": [ … ]}`, even for one record.
5. Field names exactly as [04-schemas.md](04-schemas.md) spells them, acronyms included.
6. `$filter` spaces as `%20`; property ids from
   [05-filter-properties.md](05-filter-properties.md).
7. `$top` set explicitly on anything that might match more than 50.
8. `actionAttribute` set explicitly on every entry.
9. Success is `statusCode == 200` **and** no `level: "error"` anywhere in `dataSets[]`.
