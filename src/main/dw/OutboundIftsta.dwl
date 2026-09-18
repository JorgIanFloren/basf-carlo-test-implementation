%dw 2.0
output application/json encoding="UTF-8"

/**
* Carlo / Soloplan v3 shipment-change event -> BASF IFTSTA (status report, EDI JSON)
* - self-contained mapping.
*
* The first **outbound** mapping. InboundIftmin/Iftmbf/Ifcsum turn a BASF EDIFACT interchange
* into a Carlo API call; this one runs the other way. Carlo raises a shipment-change event, this
* mapping builds the EDI JSON representation of an IFTSTA D96A interchange, and Fracht Connect
* serialises that to EDIFACT text (the `isedifact` flag on the transformer step - see
* config/README.md, which notes those flags are what make a transformer *write* EDI).
*
* No `dwlPath` is named here because no outbound profiler exists yet; the inbound three name
* theirs. See docs/iftsta/01-IFTSTA_mapping_spec.md §10.3.
*
* Like the inbound three this file is evaluated on its own by the data-transformer, which
* resolves no imports off Blob Storage, so it carries everything it needs and **must not import
* anything**. An `import` added here fails at runtime, not at build time.
*
* Input  : `payload` = the Carlo event document, `{ shipmentChangeEventLogEntry: [ ... ] }`.
* Output : `{ "EDI": { "Messages": { "D96A": { "IFTSTA": [ <message> ] } }, ... } }` - the same
*          shape tools/edifact_to_json.py produces when it parses an IFTSTA, which is how the
*          test suite gets an expectation it did not write itself.
*
* Spec: docs/iftsta/01-IFTSTA_mapping_spec.md. Source of truth for every rule below is
* docs/iftsta/IFTSTA_mapping_v1.xlsx - one sheet per message, plus Sheet1 as the index.
*
* --- Seven messages, one shape -------------------------------------------------------------
* Carlo's `eventType.matchcode` selects the message. Six matchcodes are the message's own name;
* **IFTSTA6819 is raised by matchcode `FRA9`** (Sheet1 column C). An event whose matchcode is in
* no sheet produces no message at all.
*
* Each message is a header followed by one repeated block per `cargo[]` entry. Everything in the
* block except the CNI and the EQD is identical in every repeat - the sheets say so on every row
* ("Value is always the same for each array element"). That repetition is the message format,
* not redundancy to collapse.
*
* --- Nothing is constructed ----------------------------------------------------------------
* Every value is Carlo's, passed through bare (analyst-confirmed 18-09-2026). In particular LOC
* carries the plain `designation` - `LOC+9+BEANR:::Antwerpen`, not the `Antwerpen (BE ANR)` the
* older BASF samples show and which is derivable from the matchcode. Placeholder-looking source
* data is passed through too, so no change is needed when real values arrive.
*
* The one value with no Carlo source is the interchange message ID; see MESSAGE_ID.
*/


// ===========================================================================
// The target structure
//
// RECONSTRUCTED, NOT VERIFIED - and unlike the inbound mappings, these keys are load-bearing.
// The inbound three *navigate* by "_<SEGMENT>" suffix and never read a position, so a wrong
// position cannot affect them. This mapping *writes* the positions, so a wrong one is a wrong
// message.
//
// No captured outbound envelope exists. Two things constrain the table and neither is proof:
// tools/edifact_to_json.py parses all 14 approved messages into it with nothing left over
// (`build_message` raises on a leftover segment), and the nested TDT -> LOC grouping is how
// IFTMIN SG8/SG9, IFTMBF SG7/SG8 and IFCSUM SG9 all model carriage.
//
// Everything positional lives here so that correcting it against a real capture is one edit.
// docs/iftsta/01-IFTSTA_mapping_spec.md §10.1.
// ===========================================================================

var K = {
    bgm:    "0020_BGM",
    dtm:    "0030_DTM",
    tsr:    "0040_TSR",
    sg1:    "0070_Segment_group_1",      // header references
    sg1Rff: "0080_RFF",
    sg4:    "0150_Segment_group_4",      // one repeat per cargo line
    sg4Cni: "0160_CNI",
    sg5:    "0170_Segment_group_5",      // the status and everything hanging off it
    sg5Sts: "0180_STS",
    sg5Rff: "0190_RFF",
    sg5Dtm: "0200_DTM",
    sg6:    "0220_Segment_group_6",      // carriage
    sg6Tdt: "0230_TDT",
    sg7:    "0250_Segment_group_7",      // ports
    sg7Loc: "0260_LOC",
    sg7Dtm: "0270_DTM",
    sg8:    "0280_Segment_group_8",      // equipment
    sg8Eqd: "0290_EQD"
}

// ===========================================================================
// The seven messages
//
// Keyed by the Carlo matchcode that raises each one, which is what the sheets gate their status
// segment on ("eventType.matchcode = IFTSTA6808 then STS+1+68+8"). `useCase` is the name the
// message is known by where that differs - only FRA9 -> IFTSTA6819.
//
//   bgm    the BGM segment; IFTSTA24 is the only one that is not 23+1+9
//   sts    the status segment, the whole point of the message
//   bn     where RFF+BN goes: "header", "block" (IFTSTA6828 only) or "none" (IFTSTA24)
//   bm     emit RFF+BM (master B/L)       - IFTSTA6808 does not
//   dtm95  emit DTM+95 (B/L date of issue) - IFTSTA6808 does not
//   dates  the voyage dates this message reports, in the sheet's order, which is not
//          ascending-qualifier order
// ===========================================================================

var MESSAGES = {
    "IFTSTA21": {
        useCase: "IFTSTA21",
        bgm: { BGM0101: "23", BGM0201: "1", BGM03: "9" },
        sts: { STS0101: "1", STS0201: "21" },
        bn: "header", bm: true, dtm95: true,
        dates: ["133", "186", "132", "178"]
    },
    "IFTSTA24": {
        useCase: "IFTSTA24",
        bgm: { BGM0101: "44" },
        sts: { STS0101: "1", STS0201: "24", STS0301: "40" },
        bn: "none", bm: true, dtm95: true,
        dates: ["132", "186"]
    },
    "IFTSTA29": {
        useCase: "IFTSTA29",
        bgm: { BGM0101: "23", BGM0201: "1", BGM03: "9" },
        sts: { STS0101: "1", STS0201: "29" },
        bn: "header", bm: true, dtm95: true,
        dates: ["133", "186", "132", "178"]
    },
    "IFTSTA6808": {
        useCase: "IFTSTA6808",
        bgm: { BGM0101: "23", BGM0201: "1", BGM03: "9" },
        sts: { STS0101: "1", STS0201: "68", STS0301: "8" },
        bn: "header", bm: false, dtm95: false,
        dates: ["132", "186"]
    },
    "IFTSTA6817": {
        useCase: "IFTSTA6817",
        bgm: { BGM0101: "23", BGM0201: "1", BGM03: "9" },
        sts: { STS0101: "1", STS0201: "68", STS0301: "17" },
        bn: "header", bm: true, dtm95: true,
        dates: ["133", "132"]
    },
    // Vessel change. The one message whose matchcode is not its own name - Sheet1 column C.
    "FRA9": {
        useCase: "IFTSTA6819",
        bgm: { BGM0101: "23", BGM0201: "1", BGM03: "9" },
        sts: { STS0101: "1", STS0201: "68", STS0301: "19" },
        bn: "header", bm: true, dtm95: true,
        dates: ["133", "132"]
    },
    "IFTSTA6828": {
        useCase: "IFTSTA6828",
        bgm: { BGM0101: "23", BGM0201: "1", BGM03: "9" },
        sts: { STS0101: "1", STS0201: "68", STS0301: "28" },
        bn: "block", bm: true, dtm95: true,
        dates: ["133", "132"]
    }
}

/** DTM qualifier -> the `mainCarriageAsOcean` field that supplies it. */
var DATE_FIELDS = {
    "133": "estimatedTimeOfDeparture",
    "186": "actualTimeOfDeparture",
    "132": "estimatedTimeOfArrival",
    "178": "actualTimeOfArrival"
}

/** Constants every sheet shows unchanged in the interchange header. */
var SENDER = "283155273"
var RECIPIENT = "878542765"
var RECIPIENT_QUALIFIER = "01"

/**
* The interchange message ID (UNB element 5), which the serialiser repeats in UNZ.
*
* The only emitted value with no Carlo source. The sheets ask for "the equivalent of
* Datetime.Now.Ticks (long)", set once at the start of the run and used wherever referenced -
* so it is set once here, and it appears exactly once in the emitted document (UNZ is the
* serialiser's to write, not this mapping's).
*
* Epoch milliseconds rather than .NET ticks: both are a monotonic long, and DataWeave has no
* tick epoch. The test suite normalises this field, because a mapping that reads the clock
* cannot be compared against a fixed fixture - see IftstaMappingTest.dwl.
*/
var MESSAGE_ID = (now() as Number { unit: "milliseconds" }) as String

// ===========================================================================
// Scalars
// ===========================================================================

/** True when `v` is neither null nor blank. */
fun present(v) = v != null and (trim(v as String default "")) != ""

/** `v` as an array: an array stays, null becomes [], anything else is wrapped. */
fun asArray(v): Array<Any> = v match {
    case a is Array -> a
    case n is Null -> []
    else -> [v]
}

/**
* Date and time are sliced straight out of the ISO string rather than parsed.
*
* Carlo sends "2026-09-18T13:33:42" - a local wall-clock time with no zone. Parsing it to a
* DateTime and formatting it back would invite a zone shift that moves the event by hours; the
* characters are already in the order EDIFACT wants, so slicing them is both simpler and safer.
*/
fun ymd(t) = do {                                   // -> CCYYMMDD, EDIFACT format 102
    var s = t as String
    ---
    if (sizeOf(s) < 10) null else s[0 to 3] ++ s[5 to 6] ++ s[8 to 9]
}

fun yymd(t) = do {                                  // -> YYMMDD, the UNB date
    var s = t as String
    ---
    if (sizeOf(s) < 10) null else s[2 to 3] ++ s[5 to 6] ++ s[8 to 9]
}

fun hhmm(t) = do {                                  // -> HHmm, the UNB time
    var s = t as String
    ---
    if (sizeOf(s) < 16) null else s[11 to 12] ++ s[14 to 15]
}

fun hhmmss(t) = do {                                // -> HHmmss, EDIFACT format 402
    var s = t as String
    ---
    if (sizeOf(s) < 19) null else s[11 to 12] ++ s[14 to 15] ++ s[17 to 18]
}

// ===========================================================================
// Segments
//
// One function per segment, each returning the element keys the parser produces for it:
// "<TAG><ee>" for a simple data element, "<TAG><ee><cc>" for a component of a composite.
// An absent component is omitted rather than emitted empty - that is what the parser does,
// so it is what a document compared against a parsed message has to do.
// ===========================================================================

fun dtmSeg(qualifier, value, format) = { DTM0101: qualifier, DTM0102: value, DTM0103: format }

fun rffSeg(qualifier, value) = { RFF0101: qualifier, RFF0102: value }

fun locSeg(qualifier, place) = {
    LOC01: qualifier,
    (LOC0201: place.matchcode) if present(place.matchcode),
    // The plain designation. Not enriched with the UN/LOCODE - see the header.
    (LOC0204: place.designation) if present(place.designation)
}

/**
* TDT - main carriage.
*
* The fixed components are the sheets': 21 = main-carriage transport stage, 10 = mode, 13 =
* means-of-transport qualifier, 11 = the carrier code list qualifier.
*
* TDT0805, the vessel flag, is **not emitted**: the BASF samples carry one (`:MT`, `:PA`) but no
* Carlo field supplies it, and the parser omits empty components anyway. See spec §8.2.
*/
fun tdtSeg(carriage) = {
    TDT01: "21",
    (TDT02: carriage.voyageNumber) if present(carriage.voyageNumber),
    TDT0301: "10",
    TDT0401: "13",
    TDT0503: "11",
    (TDT0504: carriage.carrier.name1) if present(carriage.carrier.name1),
    (TDT0801: carriage.vessel.matchcode) if present(carriage.vessel.matchcode),
    (TDT0804: carriage.vessel.designation) if present(carriage.vessel.designation)
}

fun cniSeg(index, cargo) = {
    CNI01: index,
    (CNI0201: cargo.deliveryNoteSAP) if present(cargo.deliveryNoteSAP),
    (CNI0203: cargo.deliveryPositionNumber) if present(cargo.deliveryPositionNumber)
}

fun eqdSeg(containerNumber) = { EQD01: "CN", EQD0201: containerNumber }

// ===========================================================================
// The repeated block
// ===========================================================================

/**
* The references inside one block: RFF+BN for IFTSTA6828 only, then RFF+BM unless the message
* is IFTSTA6808. An empty list means the RFF key is omitted entirely rather than emitted empty.
*/
fun blockRefs(spec, carriage, booking) =
    (if (spec.bn == "block" and present(booking)) [rffSeg("BN", booking)] else []) ++
    (if (spec.bm and present(carriage.masterBillOfLadingNumber))
        [rffSeg("BM", carriage.masterBillOfLadingNumber)] else [])

/** DTM+95 (B/L issue, where the message carries it) then DTM+334 twice - the event stamp. */
fun blockDates(spec, issueDate, localTime) =
    (if (spec.dtm95 and present(issueDate)) [dtmSeg("95", ymd(issueDate), "102")] else []) ++
    [dtmSeg("334", ymd(localTime), "102"), dtmSeg("334", hhmmss(localTime), "402")]

/** The voyage dates this message reports, in the sheet's order, skipping any Carlo left null. */
fun voyageDates(spec, carriage) =
    spec.dates
        filter ((q) -> present(carriage[DATE_FIELDS[q]]))
        map ((q) -> dtmSeg(q, ymd(carriage[DATE_FIELDS[q]]), "102"))

/**
* The ports, as two repeats of the LOC group.
*
* The voyage dates hang off the **second** repeat. That is not a claim that they describe the
* arrival port: the messages put both LOC segments before all four dates, and an EDIFACT
* structure is consumed left to right, so the dates fall into the group repeat that is open
* when they arrive. Parsing the approved messages back produces exactly this.
*/
fun portGroups(spec, carriage) = do {
    var dates = voyageDates(spec, carriage)
    ---
    [
        { (K.sg7Loc): locSeg("9", carriage.portOfDeparture) },
        {
            (K.sg7Loc): locSeg("12", carriage.portOfArrival),
            ((K.sg7Dtm): dates) if !isEmpty(dates)
        }
    ]
}

/** One block: everything the message reports about one cargo line. */
fun cargoBlock(spec, event, cargo, index) = do {
    var shipment = event.eventHouseShipment
    var carriage = shipment.master.mainCarriageAsOcean
    var booking = (asArray(shipment.master.externalReferences)
        filter ((r) -> r.referenceType == 9 and present(r.value)))[0].value
    var refs = blockRefs(spec, carriage, booking)
    var container = cargo.containerTransport.containerNumber
    ---
    {
        (K.sg4Cni): cniSeg(index, cargo),
        (K.sg5): [
            {
                (K.sg5Sts): spec.sts,
                ((K.sg5Rff): refs) if !isEmpty(refs),
                (K.sg5Dtm): blockDates(spec, shipment.billOfLading.dateOfIssue, event.localTime),
                (K.sg6): [
                    {
                        (K.sg6Tdt): tdtSeg(carriage),
                        (K.sg7): portGroups(spec, carriage)
                    }
                ],
                // Omitted when there is no container number - an LCL consignment has none.
                ((K.sg8): [ { (K.sg8Eqd): eqdSeg(container) } ]) if present(container)
            }
        ]
    }
}

// ===========================================================================
// The message
// ===========================================================================

/** The header references: RFF+SI always, RFF+BN unless the message puts it in the block. */
fun headerRefs(spec, shipment) = do {
    var booking = (asArray(shipment.master.externalReferences)
        filter ((r) -> r.referenceType == 9 and present(r.value)))[0].value
    ---
    [ { (K.sg1Rff): rffSeg("SI", shipment.customerReference) } ] ++
    (if (spec.bn == "header" and present(booking))
        [ { (K.sg1Rff): rffSeg("BN", booking) } ] else [])
}

fun heading(spec, event) = do {
    var shipment = event.eventHouseShipment
    ---
    {
        (K.bgm): spec.bgm,
        (K.dtm): [
            dtmSeg("137", ymd(event.localTime), "102"),
            dtmSeg("137", hhmmss(event.localTime), "402")
        ],
        // TSR is the LCL marker. loadType 1 = FCL, 2 = LCL.
        ((K.tsr): [ { TSR0101: "25", TSR0201: "3" } ]) if (shipment.loadType == 2),
        (K.sg1): headerRefs(spec, shipment),
        (K.sg4): asArray(shipment.cargo) map ((cargo, i) -> cargoBlock(spec, event, cargo, i + 1))
    }
}

/**
* The interchange header.
*
* UNB0401/UNB0402 are emitted as **numbers** because that is what the parser makes of them
* (they are in its NUMERIC_KEYS), and this document is compared against parsed messages. It
* costs a leading zero: an event before 10:00 gives UNB0402 = 820 rather than "0820". See spec
* §10.
*/
fun interchange(shipment, localTime) = {
    UNB0101: "UNOY",
    UNB0102: "3",
    UNB0201: SENDER,
    UNB0301: RECIPIENT,
    UNB0302: RECIPIENT_QUALIFIER,
    UNB0303: shipment.dUNSCustomer,
    UNB0401: yymd(localTime) as Number,
    UNB0402: hhmm(localTime) as Number,
    UNB05: MESSAGE_ID
}

/**
* One parsed-shape IFTSTA message. Key order follows the parser's so the document compares
* equal to a parsed message as a whole rather than field by field.
*
* No UNT and no UNZ: the parser consumes UNT without emitting it and never represents UNZ, so
* neither belongs in this document - the serialiser counts the segments and writes both. The
* count rule is documented in spec §7 because the approved messages must match it, not because
* this mapping applies it.
*/
fun message(spec, event) = {
    Interchange: interchange(event.eventHouseShipment, event.localTime),
    Heading: heading(spec, event),
    Id: "IFTSTA",
    MessageHeader: {
        UNH01: event.eventHouseShipment.frachtShipmentRef,
        UNH0201: "IFTSTA",
        UNH0202: "D",
        UNH0203: "96A",
        UNH0204: "UN"
    },
    Name: "International multimodal status report message"
}

/**
* Every message this event produces - one, or none.
*
* Only `shipmentChangeEventLogEntry[0]` is read: every sheet describes a single message and
* every captured example carries a single entry. An event whose matchcode is in no sheet yields
* nothing, the same way an interchange carrying no message of interest yields an empty array in
* the inbound mappings - the flow stops rather than guessing at a status code.
*/
fun messages(doc) = do {
    var event = asArray(doc.shipmentChangeEventLogEntry)[0]
    var spec = MESSAGES[event.eventType.matchcode default ""]
    ---
    if (event == null or spec == null) [] else [message(spec, event)]
}
---
do {
    var built = messages(payload)
    ---
    {
        EDI: {
            Errors: [],
            Delimiters: "+: '?",
            // Keyed by directory then message type, as the parser nests them. An event that
            // matches no sheet leaves this empty rather than emitting a message with no status.
            Messages: if (isEmpty(built)) {} else { D96A: { IFTSTA: built } },
            FunctionalAcksReceived: [],
            FunctionalAcksGenerated: []
        }
    }
}
