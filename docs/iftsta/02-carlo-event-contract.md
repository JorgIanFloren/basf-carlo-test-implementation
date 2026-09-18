# The Carlo event contract — what arrives, and how

The input side of `OutboundIftsta.dwl`. The mapping spec (`01-IFTSTA_mapping_spec.md`) says what
each field becomes; this says what Carlo sends and how it reaches the transformer.

| | |
|---|---|
| Sender | Carlo (Soloplan), calling Fracht Connect |
| Entry point | `POST https://api-ch2.fracht-connect.com/dev/s/v1/fra-e-inbound/carlo_be/basf_iftsta` |
| Body | one `shipmentChangeEventLogEntry` document — §2 |
| Attested by | `docs/example-orders/outbound/iftsta/carlo/{fcl,lcl}/*.json` |

## 1. The path from Carlo to the mapping

```
Carlo ──POST──▶ fra-e-inbound/carlo_be/basf_iftsta
                        │
                        ▼
                Azure blob storage          the endpoint writes the incoming JSON
                        │                   payload to blob, unchanged
                        ▼
                    ??? trigger             NOT ESTABLISHED - something picks the
                        │                   blob up and starts the MuleSoft flow
                        ▼
                OutboundIftsta.dwl ──▶ EDI JSON ──▶ EDIFACT ──▶ BASF
```

Two things are known: the endpoint **writes the incoming JSON payload to an Azure blob storage
location**, and MuleSoft is then **triggered to process that file**. What performs the trigger —
an Event Grid subscription, a polling source, a scheduler, a `dataGetter` of the kind
`config/dataGetter-basf-inbound.json` is a placeholder for — is **not established**. It is
recorded here as unknown rather than guessed at, because it decides the shape of the outbound
profiler that `config/` still lacks.

### What the transformer receives

The mapping binds the Carlo document directly as `payload`:

```
payload = { "shipmentChangeEventLogEntry": [ … ] }
```

**Not** the two-node envelope IFTMIN and IFTMBF get. Those two open with a "GET dossier by
CustomerRef" `dataDelivery` that hands the transformer `originalPayload` and `payload` as
siblings (`docs/carlo/06-dossier-lookup.md`). IFTSTA has no lookup step — it addresses nothing
in Carlo, it only reports — so there is nothing to put beside the payload. That is the
expectation the mapping is written to, and it is the natural one for a flow whose only input is
the blob, but it has not been confirmed against a live run. If the trigger turns out to wrap the
document, only the two accessors in `messages()` change.

## 2. The contract

Derived from the FCL example, which is the fullest form Carlo sends. The FCL and LCL examples
are **key-identical** — every path below is present in both — so this is one contract with two
value profiles, not two contracts.

Types are as they appear on the wire: `loadType` and `referenceType` are JSON numbers, everything
else is a string, and timestamps are local wall-clock ISO 8601 with no zone (`2026-09-18T13:33:42`).

```
shipmentChangeEventLogEntry[]                        array - one event; see §4
├── eventType.matchcode                      string  selects the message (spec §1)
├── localTime                                string  the event timestamp
└── eventHouseShipment
    ├── preferredModeOfTransport             string  "Ocean" - not mapped
    ├── frachtShipmentRef                    string  UNH / UNT reference
    ├── customerReference                    string  RFF+SI
    ├── dUNSCustomer                         string  UNB recipient
    ├── loadType                             number  1 = FCL, 2 = LCL -> TSR
    ├── master
    │   ├── preferredModeOfTransport         string  "Ocean" - not mapped
    │   ├── externalReferences[]             array
    │   │   ├── referenceType                number  9 selects the booking reference
    │   │   └── value                        string  RFF+BN
    │   └── mainCarriageAsOcean
    │       ├── masterBillOfLadingNumber     string  RFF+BM
    │       ├── voyageNumber                 string  TDT02
    │       ├── carrier.matchcode            string  not mapped
    │       ├── carrier.name1                string  TDT0504
    │       ├── vessel.matchcode             string  TDT0801
    │       ├── vessel.designation           string  TDT0804
    │       ├── portOfDeparture.matchcode    string  LOC+9  LOC0201
    │       ├── portOfDeparture.designation  string  LOC+9  LOC0204
    │       ├── portOfArrival.matchcode      string  LOC+12 LOC0201
    │       ├── portOfArrival.designation    string  LOC+12 LOC0204
    │       ├── estimatedTimeOfDeparture     string  DTM+133
    │       ├── actualTimeOfDeparture        string  DTM+186
    │       ├── estimatedTimeOfArrival       string  DTM+132
    │       └── actualTimeOfArrival          string  DTM+178   nullable
    ├── cargo[]                              array   one CNI block each
    │   ├── containerTransport.containerNumber  string  EQD - **null on LCL**
    │   ├── deliveryNoteSAP                  string  CNI0201
    │   └── deliveryPositionNumber           string  CNI0203
    └── billOfLading.dateOfIssue             string  DTM+95
```

### FCL vs LCL

The only structural difference in the captured pair:

| | FCL | LCL |
|---|---|---|
| `loadType` | `1` | `2` |
| `cargo[].containerTransport.containerNumber` | container number | **`null`** |

Everything else is identical in shape. This is why the mapping needs no load-type branch beyond
the two rules in spec §5: `TSR` keys off `loadType`, `EQD` keys off the container number being
present. An LCL consignment has no container, so the field is null rather than the key being
absent.

## 3. Fields the mapping does not read

Three, and all three are deliberate:

| Field | Why |
|---|---|
| `eventHouseShipment.preferredModeOfTransport` | `"Ocean"` in every example. No sheet maps it. |
| `master.preferredModeOfTransport` | as above |
| `mainCarriageAsOcean.carrier.matchcode` | the sheets map `carrier.name1` into `TDT0504` and nothing into the carrier-code component |

Nothing else in the contract is unused: every other path feeds a segment.

The mapping reads `mainCarriageAsOcean` unconditionally. Both `preferredModeOfTransport` fields
say `"Ocean"` in every example, so there is no evidence any other mode reaches this flow — but if
one can, `TDT` and `LOC` have no source and the sheets do not cover it. See spec §10.7.

## 4. Nullability and cardinality — what the examples do *not* settle

The contract is confirmed as the shape Carlo always sends. Its *value* ranges are not, and three
questions remain open. Each is a real branch in the mapping, so each is worth an answer rather
than an assumption:

1. **Is `shipmentChangeEventLogEntry` ever longer than one?** Both examples carry exactly one
   entry and every mapping sheet describes a single message. The mapping reads `[0]` and ignores
   any tail. If Carlo can batch events, that tail is silently dropped — and the right handling
   (one interchange per event, or several messages in one interchange) is a question for the
   analyst, not a guess. Spec §10.5.
2. **Which fields can be null besides `containerNumber` and `actualTimeOfArrival`?** Those two
   are attested null. The mapping is defensive everywhere — a segment whose source is null or
   blank is omitted rather than emitted empty — so a surprise null degrades to a missing segment
   rather than a malformed one. Whether a *missing* segment is acceptable to BASF is the
   question, and it differs per field: a missing `DTM+178` is routine, a missing `RFF+SI` is not.
3. **Can `externalReferences` carry more than one entry, or a type other than 9?** The examples
   carry exactly one, of type 9. The mapping takes the **first** entry with `referenceType = 9`
   and ignores the rest, which is what the sheets' `externalReferences[0]` notation implies.

None of these blocks the mapping. All three are cheap to confirm with whoever owns the Carlo
side.

## 5. Placeholder values still in the examples

The captured events carry test data in two fields, and the mapping passes both through bare
(spec §6), so no mapping change is expected when real values arrive — but the approved EDIFACT
under `docs/example-orders/outbound/iftsta/basf/` is a fixture set and **will need regenerating**:

| Field | Current value |
|---|---|
| `masterBillOfLadingNumber` | `"master bl number"` |
| `voyageNumber` | `"123"` |

```
python tools/edifact_to_json.py --outbound     # after regenerating the approved .txt
```
