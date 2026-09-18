/**
* BASF IFTSTA mapping, exercised over all 14 approved messages - seven message types in both
* load types.
*
* The mapping is run the way the data-transformer runs it: `evalPath` executes
* src/main/dw/OutboundIftsta.dwl - the whole self-contained script, output header and document
* body included - against a `payload` context and returns the EDI JSON document Fracht Connect
* would serialise. Nothing is imported from the mapping, so no part of it is restated here.
*
* --- Where the expectation comes from ------------------------------------------------------
* The suite does not hand-write what the mapping should produce. Every case is checked against
* the **approved EDIFACT** in docs/example-orders/outbound/iftsta/basf, reached by a second and
* independent route: `tools/edifact_to_json.py --outbound` parses each approved .txt into the
* same EDI JSON shape the mapping emits, and the two documents are compared whole.
*
* So one side is built from a Carlo event by DataWeave and the other is parsed from EDIFACT by
* Python, and they have to agree. That is the same cross-check-not-restatement principle the
* inbound suites get from manifest.json, and it is why a whole-document assertion is worth
* making here where the inbound suites assert field by field.
*
* On top of the 14 document comparisons, the per-message rules are asserted directly - which
* message drops RFF+BM, where RFF+BN lives, what each one's date set is - so a regression names
* the rule it broke instead of only printing a document diff.
*
* Regenerate the fixtures whenever docs/example-orders/outbound changes:
*     python tools/edifact_to_json.py --outbound
*/
%dw 2.0
import * from dw::test::Tests
import * from dw::test::Asserts

var MAPPING = "OutboundIftsta.dwl"

/**
* The seven messages, by the Carlo matchcode that raises each one and the BASF message it
* produces. They differ only for the vessel-change message: matchcode FRA9 -> IFTSTA6819.
* Carlo fixtures are named by matchcode, approved messages by use case, which is exactly how
* docs/example-orders/outbound is laid out.
*/
var MESSAGES = [
    { matchcode: "IFTSTA21",   useCase: "IFTSTA21" },
    { matchcode: "IFTSTA24",   useCase: "IFTSTA24" },
    { matchcode: "IFTSTA29",   useCase: "IFTSTA29" },
    { matchcode: "IFTSTA6808", useCase: "IFTSTA6808" },
    { matchcode: "IFTSTA6817", useCase: "IFTSTA6817" },
    { matchcode: "FRA9",       useCase: "IFTSTA6819" },
    { matchcode: "IFTSTA6828", useCase: "IFTSTA6828" }
]

var CASES = ["fcl", "lcl"] flatMap ((variant) ->
    MESSAGES map ((m) -> m ++ { variant: variant }))

fun carloEvent(variant, matchcode) =
    readUrl("classpath://example-orders/outbound/iftsta/carlo/" ++ variant ++ "/" ++ matchcode ++ ".json",
            "application/json")

fun approved(variant, useCase) =
    readUrl("classpath://example-orders/outbound/iftsta/basf/" ++ variant ++ "/" ++ useCase ++ ".json",
            "application/json")

/**
* Run the mapping script over a Carlo event and return the EDI document. This is the only route
* the suite has into the mapping - the same call the data-transformer makes - so a break in the
* output header, the document body or any helper surfaces here.
*/
fun document(payload) = evalPath(MAPPING, { payload: payload }, "application/json")

/**
* Blank the interchange message ID on both sides before comparing.
*
* The mapping sets it from the clock, as the sheets require ("the equivalent of
* Datetime.Now.Ticks, set at the start of the script execution"), so it cannot equal the fixed
* value the approved message carries. It is asserted separately below instead - and it appears
* exactly once in the document, because UNZ is the serialiser's to write.
*/
fun anonymised(doc) = doc update {
    case id at .EDI.Messages.D96A.IFTSTA[0].Interchange.UNB05 -> "<message-id>"
}

// --- accessors into the emitted document ---------------------------------------------------
// Spelled out once here so the assertions below read as rules rather than as key paths. The
// keys are the reconstructed IFTSTA D96A positions; see the structure table in the mapping.

fun message(doc) = doc.EDI.Messages.D96A.IFTSTA[0]
fun heading(doc) = message(doc).Heading
fun headerRffs(doc) = (heading(doc)."0070_Segment_group_1" default []) map ((g) -> g."0080_RFF")
fun blocks(doc) = heading(doc)."0150_Segment_group_4" default []
fun status(block) = block."0170_Segment_group_5"[0]
fun blockRffs(block) = status(block)."0190_RFF" default []
fun blockDtms(block) = status(block)."0200_DTM" default []
fun carriage(block) = status(block)."0220_Segment_group_6"[0]
fun ports(block) = carriage(block)."0250_Segment_group_7"
fun voyageDtms(block) = ports(block)[1]."0270_DTM" default []
fun equipment(block) = status(block)."0280_Segment_group_8"

fun qualifiersOf(dtms) = dtms map ((d) -> d.DTM0101)
fun refQualifiers(rffs) = rffs map ((r) -> r.RFF0101)

/** The document for one case, evaluated through the mapping. */
fun docFor(variant, matchcode) = document(carloEvent(variant, matchcode))

// Evaluated once each and reused: `var` is cached, so a case the assertions below return to
// repeatedly costs one run of the mapping rather than one per assertion.
var fcl21 = docFor("fcl", "IFTSTA21")
var fcl24 = docFor("fcl", "IFTSTA24")
var fcl6808 = docFor("fcl", "IFTSTA6808")
var fcl6819 = docFor("fcl", "FRA9")
var fcl6828 = docFor("fcl", "IFTSTA6828")
var lcl21 = docFor("lcl", "IFTSTA21")
var lcl6828 = docFor("lcl", "IFTSTA6828")

/** A Carlo event carrying one cargo line, so a single field can be varied in isolation. */
fun eventOf(matchcode, loadType, cargo) = {
    shipmentChangeEventLogEntry: [{
        eventType: { matchcode: matchcode },
        localTime: "2026-09-18T13:33:42",
        eventHouseShipment: {
            frachtShipmentRef: "76000143",
            customerReference: "2800209301_training",
            dUNSCustomer: "315000554",
            loadType: loadType,
            master: {
                externalReferences: [{ referenceType: 9, value: "Ref2345" }],
                mainCarriageAsOcean: {
                    masterBillOfLadingNumber: "master bl number",
                    voyageNumber: "123",
                    carrier: { name1: "CARRIER" },
                    vessel: { matchcode: "9720483", designation: "MSC CHLOE" },
                    portOfDeparture: { matchcode: "BEANR", designation: "Antwerpen" },
                    portOfArrival: { matchcode: "BRSSZ", designation: "Santos" },
                    estimatedTimeOfDeparture: "2026-04-20T00:00:00",
                    estimatedTimeOfArrival: "2026-05-08T00:00:00",
                    actualTimeOfDeparture: "2026-04-20T00:00:00",
                    actualTimeOfArrival: "2026-04-21T00:00:00"
                }
            },
            cargo: cargo,
            billOfLading: { dateOfIssue: "2026-09-06T00:00:00" }
        }
    }]
}

var oneLine = [{ containerTransport: { containerNumber: "APLU1234567" },
                 deliveryNoteSAP: "3550879847", deliveryPositionNumber: "000010" }]

/**
* The fields each scenario does **not** map, which are exactly the ones Carlo may leave null at
* the point that scenario fires. Read down the seven and the shipment lifecycle falls out:
*
*   before departure   6817, 6819, 6828   ETD + ETA, no actuals - nothing has happened yet
*   at/after departure 24, 6808           ATD + ETA, no ETD, no ATA
*   on arrival         29, 21             all four
*
* Plus two that are not about dates: a departure confirmation carries no booking reference, and
* an ETA change carries no master B/L or issue date.
*/
var NULLABLE = {
    "IFTSTA21":   [],
    "IFTSTA24":   ["etd", "ata", "booking"],
    "IFTSTA29":   [],
    "IFTSTA6808": ["etd", "ata", "bl", "issue"],
    "IFTSTA6817": ["atd", "ata"],
    "FRA9":       ["atd", "ata"],
    "IFTSTA6828": ["atd", "ata"]
}

/** The same Carlo event with the named fields emptied. */
fun without(doc, fields) = doc update {
    case v at .shipmentChangeEventLogEntry[0].eventHouseShipment.master.mainCarriageAsOcean.estimatedTimeOfDeparture -> if (fields contains "etd") null else v
    case v at .shipmentChangeEventLogEntry[0].eventHouseShipment.master.mainCarriageAsOcean.actualTimeOfDeparture -> if (fields contains "atd") null else v
    case v at .shipmentChangeEventLogEntry[0].eventHouseShipment.master.mainCarriageAsOcean.actualTimeOfArrival -> if (fields contains "ata") null else v
    case v at .shipmentChangeEventLogEntry[0].eventHouseShipment.master.mainCarriageAsOcean.masterBillOfLadingNumber -> if (fields contains "bl") null else v
    case v at .shipmentChangeEventLogEntry[0].eventHouseShipment.billOfLading.dateOfIssue -> if (fields contains "issue") null else v
    case v at .shipmentChangeEventLogEntry[0].eventHouseShipment.master.externalReferences -> if (fields contains "booking") [] else v
}
---
"BASF IFTSTA mapping" describedBy (

    // === the approved messages, whole ======================================================
    // One side built from a Carlo event by this mapping, the other parsed from the approved
    // EDIFACT by tools/edifact_to_json.py. Nothing here was written by hand.
    (CASES map ((c) -> () ->
        (c.variant ++ "/" ++ c.useCase ++ " reproduces the approved message") in (
            anonymised(docFor(c.variant, c.matchcode))
                must equalTo(anonymised(approved(c.variant, c.useCase)))))) ++

    [
    // === the message ID ====================================================================
    // The one emitted value with no Carlo source. Set once per run from the clock, which is why
    // the comparisons above blank it.
    () -> "the interchange carries a message id" in (
        message(fcl21).Interchange.UNB05 must notBeNull()),

    () -> "the message id is a long, as the sheets ask" in (
        (message(fcl21).Interchange.UNB05 as Number) must beGreaterThan(0)),

    // === which message the matchcode selects ===============================================
    () -> "each matchcode produces its own status segment" in (
        (MESSAGES map ((m) -> status(blocks(docFor("fcl", m.matchcode))[0])."0180_STS"))
            must equalTo([
                { STS0101: "1", STS0201: "21" },
                { STS0101: "1", STS0201: "24", STS0301: "40" },
                { STS0101: "1", STS0201: "29" },
                { STS0101: "1", STS0201: "68", STS0301: "8" },
                { STS0101: "1", STS0201: "68", STS0301: "17" },
                { STS0101: "1", STS0201: "68", STS0301: "19" },
                { STS0101: "1", STS0201: "68", STS0301: "28" }
            ])),

    // Sheet1 column C: the vessel-change message is the one whose matchcode is not its name.
    () -> "matchcode FRA9 raises the vessel-change status, not an IFTSTA6819 matchcode" in (
        status(blocks(fcl6819)[0])."0180_STS" must equalTo({ STS0101: "1", STS0201: "68", STS0301: "19" })),

    () -> "an unrecognised matchcode produces no message at all" in (
        document(eventOf("IFTSTA9999", 1, oneLine)).EDI.Messages must equalTo({})),

    () -> "an event with no log entries produces no message at all" in (
        document({ shipmentChangeEventLogEntry: [] }).EDI.Messages must equalTo({})),

    // === BGM ===============================================================================
    () -> "IFTSTA24 is the only message that is not BGM+23+1+9" in (
        (MESSAGES map ((m) -> heading(docFor("fcl", m.matchcode))."0020_BGM"))
            must equalTo([
                { BGM0101: "23", BGM0201: "1", BGM03: "9" },
                { BGM0101: "44" },
                { BGM0101: "23", BGM0201: "1", BGM03: "9" },
                { BGM0101: "23", BGM0201: "1", BGM03: "9" },
                { BGM0101: "23", BGM0201: "1", BGM03: "9" },
                { BGM0101: "23", BGM0201: "1", BGM03: "9" },
                { BGM0101: "23", BGM0201: "1", BGM03: "9" }
            ])),

    // === where RFF+BN lives ================================================================
    () -> "most messages carry the booking reference in the header" in (
        refQualifiers(headerRffs(fcl21)) must equalTo(["SI", "BN"])),

    () -> "IFTSTA24 carries no booking reference at all" in (
        refQualifiers(headerRffs(fcl24)) must equalTo(["SI"])),

    // IFTSTA6828 is the message whose whole purpose is to deliver the B/L number, and its sheet
    // is the only one that puts RFF+BN inside the block, after the status.
    () -> "IFTSTA6828 carries the booking reference inside the block, not the header" in (
        fcl6828 must [
            refQualifiers(headerRffs($)) must equalTo(["SI"]),
            refQualifiers(blockRffs(blocks($)[0])) must equalTo(["BN", "BM"])
        ]),

    // === what IFTSTA6808 drops =============================================================
    // Its sheet is the only one with no RFF+BM row and no DTM+95 row. An ETA change after
    // departure reports dates, not paperwork.
    () -> "IFTSTA6808 emits no master B/L and no B/L issue date" in (
        blocks(fcl6808)[0] must [
            blockRffs($) must equalTo([]),
            qualifiersOf(blockDtms($)) must equalTo(["334", "334"])
        ]),

    () -> "every other message emits the master B/L and the issue date" in (
        (["IFTSTA21", "IFTSTA24", "IFTSTA29", "IFTSTA6817", "FRA9", "IFTSTA6828"]
            map ((mc) -> qualifiersOf(blockDtms(blocks(docFor("fcl", mc))[0]))))
            must equalTo([["95", "334", "334"], ["95", "334", "334"], ["95", "334", "334"],
                          ["95", "334", "334"], ["95", "334", "334"], ["95", "334", "334"]])),

    // === the voyage dates, in the sheets' order ============================================
    // The order is the sheets', not ascending qualifier order, and it differs per message.
    () -> "each message reports its own date set in its own order" in (
        (MESSAGES map ((m) -> qualifiersOf(voyageDtms(blocks(docFor("fcl", m.matchcode))[0]))))
            must equalTo([
                ["133", "186", "132", "178"],   // IFTSTA21
                ["132", "186"],                 // IFTSTA24
                ["133", "186", "132", "178"],   // IFTSTA29
                ["132", "186"],                 // IFTSTA6808
                ["133", "132"],                 // IFTSTA6817
                ["133", "132"],                 // IFTSTA6819
                ["133", "132"]                  // IFTSTA6828
            ])),

    () -> "a date Carlo left null is omitted rather than emitted empty" in (
        qualifiersOf(voyageDtms(blocks(document(eventOf("IFTSTA21", 1, oneLine) update {
            case ata at .shipmentChangeEventLogEntry[0].eventHouseShipment.master.mainCarriageAsOcean.actualTimeOfArrival -> null
        }))[0])) must equalTo(["133", "186", "132"])),

    // === FCL and LCL =======================================================================
    // The whole difference between the two load types is TSR and EQD, and both have a reason:
    // TSR+25+3 marks LCL, and an LCL consignment has no container to report.
    () -> "an LCL message carries TSR+25+3 and an FCL message does not" in (
        [heading(lcl21)."0040_TSR", heading(fcl21)."0040_TSR"]
            must equalTo([[{ TSR0101: "25", TSR0201: "3" }], null])),

    () -> "an FCL block carries its container and an LCL block carries none" in (
        [equipment(blocks(fcl21)[0]), equipment(blocks(lcl21)[0])]
            must equalTo([[{ "0290_EQD": { EQD01: "CN", EQD0201: "APLU1234567" } }], null])),

    // Stated as the invariant rather than as two numbers: LCL gains one TSR and loses one EQD
    // per cargo line, so across five lines every LCL message is four segments shorter.
    () -> "an LCL message is one TSR up and five EQDs down on its FCL counterpart" in (
        (MESSAGES map ((m) -> do {
            var f = docFor("fcl", m.matchcode)
            var l = docFor("lcl", m.matchcode)
            ---
            {
                fclEqd: sizeOf(blocks(f) filter ((b) -> equipment(b) != null)),
                lclEqd: sizeOf(blocks(l) filter ((b) -> equipment(b) != null)),
                fclTsr: heading(f)."0040_TSR" != null,
                lclTsr: heading(l)."0040_TSR" != null
            }
        })) must equalTo(MESSAGES map ((m) ->
            { fclEqd: 5, lclEqd: 0, fclTsr: false, lclTsr: true }))),

    // === the repeated block ================================================================
    () -> "one block per cargo line, numbered from one" in (
        (blocks(fcl21) map ((b) -> b."0160_CNI".CNI01)) must equalTo([1, 2, 3, 4, 5])),

    () -> "each block carries its own delivery note" in (
        (blocks(fcl21) map ((b) -> b."0160_CNI".CNI0201))
            must equalTo(["3550879847", "3550879994", "3550879430", "3550880113", "3550879730"])),

    // Everything except the CNI and the EQD repeats verbatim - the sheets say so on every row.
    () -> "every block repeats the same status, references and carriage" in (
        sizeOf((blocks(fcl6828) map ((b) -> { sts: status(b)."0180_STS", rff: blockRffs(b),
                                              tdt: carriage(b)."0230_TDT" })
            distinctBy ((x) -> x))) must equalTo(1)),

    // === segments built from Carlo =========================================================
    () -> "TDT carries the voyage, carrier and vessel and no vessel flag" in (
        carriage(blocks(fcl21)[0])."0230_TDT" must equalTo({
            TDT01: "21",
            TDT02: "123",
            TDT0301: "10",
            TDT0401: "13",
            TDT0503: "11",
            TDT0504: "CMA - CGM C/O CMA CGM & ANL SECURITIES B",
            TDT0801: "9720483",
            TDT0804: "MSC CHLOE"
        })),

    // Nothing is constructed: the place name is Carlo's designation, not "Antwerpen (BE ANR)".
    () -> "LOC carries the bare Carlo designation, not an enriched place name" in (
        (ports(blocks(fcl21)[0]) map ((g) -> g."0260_LOC"))
            must equalTo([
                { LOC01: "9", LOC0201: "BEANR", LOC0204: "Antwerpen" },
                { LOC01: "12", LOC0201: "BRSSZ", LOC0204: "Santos" }
            ])),

    () -> "the event timestamp is split into a date and a time segment" in (
        heading(fcl21)."0030_DTM" must equalTo([
            { DTM0101: "137", DTM0102: "20260918", DTM0103: "102" },
            { DTM0101: "137", DTM0102: "133342", DTM0103: "402" }
        ])),

    () -> "the interchange names the Carlo customer and the event date and time" in (
        message(lcl6828).Interchange must [
            $.UNB0101 must equalTo("UNOY"),
            $.UNB0201 must equalTo("283155273"),
            $.UNB0303 must equalTo("315000554"),
            $.UNB0401 must equalTo(260918),
            $.UNB0402 must equalTo(1339)
        ]),

    () -> "the message header names the Fracht shipment reference" in (
        message(fcl21).MessageHeader must equalTo({
            UNH01: "76000143", UNH0201: "IFTSTA", UNH0202: "D", UNH0203: "96A", UNH0204: "UN"
        })),

    // === what the mapping deliberately does not emit =======================================
    // The serialiser counts the segments and writes UNT and UNZ; neither is part of the parsed
    // shape, so neither belongs in this document. Spec §7.
    () -> "the document carries no UNT and no UNZ" in (
        (heading(fcl21) pluck ((v, k) -> k as String) filter ((k) -> (k contains "UNT") or (k contains "UNZ")))
            must equalTo([])),

    // === the nullable fields ===============================================================
    // A scenario's unmapped fields are the ones Carlo may leave null when it fires. If that is
    // right, emptying exactly those fields cannot change the message - which is what makes the
    // mapping safe against a real event that carries fewer values than the examples do.
    () -> "emptying the fields a scenario does not map leaves its message unchanged" in (
        (MESSAGES map ((m) -> do {
            var full = carloEvent("fcl", m.matchcode)
            ---
            anonymised(document(without(full, NULLABLE[m.matchcode]))) ==
                anonymised(document(full))
        })) must equalTo(MESSAGES map ((m) -> true))),

    // The converse: a field a scenario *does* map is load-bearing, so emptying it must change the
    // message. Without this the assertion above would also pass if the mapping ignored everything.
    () -> "emptying a field a scenario does map changes its message" in (
        anonymised(document(without(carloEvent("fcl", "IFTSTA21"), ["ata"]))) !=
            anonymised(document(carloEvent("fcl", "IFTSTA21"))) must equalTo(true)),

    // === guards ============================================================================
    () -> "a cargo line with no container number yields no EQD" in (
        equipment(blocks(document(eventOf("IFTSTA21", 1,
            [{ containerTransport: { containerNumber: null },
               deliveryNoteSAP: "3550879847", deliveryPositionNumber: "000010" }])))[0])
            must beNull()),

    () -> "an event with no cargo yields a header and no blocks" in (
        document(eventOf("IFTSTA21", 1, [])) must [
            blocks($) must equalTo([]),
            heading($)."0020_BGM" must notBeNull()
        ]),

    // === envelope ==========================================================================
    () -> "the document is the parser-shaped EDI envelope" in (
        (document(eventOf("IFTSTA21", 1, oneLine)).EDI pluck ((v, k) -> k as String))
            must equalTo(["Errors", "Delimiters", "Messages",
                          "FunctionalAcksReceived", "FunctionalAcksGenerated"])),

    () -> "the message is filed under its directory and type" in (
        message(fcl21) must notBeNull())
    ]
)
