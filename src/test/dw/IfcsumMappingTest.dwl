/**
* BASF IFCSUM mapping, exercised against every IFCSUM interchange in docs/example-orders
* (4 fixtures: 3 FCL, 1 LCL).
*
* The mapping is run the way the data-transformer runs it: `evalPath` executes
* src/main/dw/BasfIfcsum.dwl - the whole self-contained script, output header and document
* body included - against a `payload` context and returns the parsed JSON Carlo would
* receive. Nothing is imported from the mapping, so no part of it is restated here and there
* is nothing to keep in sync; every assertion below is made on the camelCase document that
* actually leaves the transformer.
*
* Every cargo line is checked against example-orders/manifest.json, whose `cargo` rows are
* produced by `ifcsum_cargo()` in tools/edifact_to_json.py. That function walks the parsed
* tree by explicit key lookup where BasfIfcsum.dwl walks it by segment-name suffix, so the
* two arrive at the same answer by different routes - the manifest is a cross-check, not a
* restatement of the mapping.
*
* The two shapes IFCSUM comes in are both covered:
*   FCL - one sea container, its verified gross mass, seal and VGM signatory
*   LCL - a truck (which must NOT land on the cargo line) and a customs MRN per consignment
*/
%dw 2.0
import * from dw::test::Tests
import * from dw::test::Asserts

var MAPPING = "BasfIfcsum.dwl"

var manifest = readUrl("classpath://example-orders/manifest.json", "application/json")
var ifcsum = manifest filter ((e) -> e.messageType == "IFCSUM")

/**
* Run the mapping script over a whole parsed interchange and return the Carlo document.
* This is the only route the suite has into the mapping - the same call the data-transformer
* makes - so a break in the output header, the document body or any helper surfaces here.
*/
fun document(payload) = evalPath(MAPPING, { payload: payload }, "application/json")

/** The same, over an interchange built from one synthetic message. */
fun documentOf(msg) = document({ EDI: { Messages: { D08A: { IFCSUM: [ msg ] } } } })

fun load(fixture) = readUrl("classpath://example-orders/" ++ fixture, "application/json")
fun cargoOf(fixture) = document(load(fixture)).shipmentCargo

// Evaluated once each and reused: `var` is cached, so a fixture the assertions below return
// to repeatedly costs one run of the mapping rather than one per assertion.
var fclVgm = cargoOf("fcl/ifcsum-2013354403.json")
var fclSingle = cargoOf("fcl/ifcsum-2013354401.json")
var lclMrn = cargoOf("lcl/ifcsum-136579804.json")

fun actual(fixture) = cargoOf(fixture) map ((c) -> {
    itemNumber: c.itemNumber,
    deliveryNote: c.deliveryNoteSAP,
    position: c.deliveryPositionNumber,
    mrn: c.mRN,
    container: if (c.container == null) null else {
        containerNumber: c.container.containerNumber,
        containerType: c.container.containerType.matchcode,
        verifiedGrossMass: c.container.verifiedGrossMass,
        sealNumber: c.container.sealNumber,
        vgmPerson: c.container.vGMPersonInChanrge
    }
})

fun expected(e) = e.cargo map ((line) -> {
    itemNumber: line.itemNumber,
    deliveryNote: line.deliveryNote,
    position: line.position,
    mrn: line.mrn,
    container: line.container
})

fun message(code) = {
    MessageHeader: { UNH01: "1" },
    Heading: { "0020_BGM": { BGM0101: "340", BGM0201: "2013449715", BGM03: code } }
}

/** The same, carrying one real consignment - so the BGM code is the only thing that varies. */
fun summary(code) = message(code) update {
    case h at .Heading -> h ++ { "1150_Segment_group_26": [{
        "1160_CNI": { CNI01: 1, CNI0201: "3550984178" },
        "2260_Segment_group_51": [{ "2270_GID": { GID01: 1 } }] }] }
}
---
"BASF IFCSUM mapping" describedBy (

    // === every example interchange, line by line ============================================
    (ifcsum map ((e) -> () ->
        (e.fixture ++ " (" ++ e.scenario ++ ", " ++ (sizeOf(e.cargo) as String) ++ " cargo line(s))")
            in (actual(e.fixture) must equalTo(expected(e))))) ++

    [
    // === identity ===========================================================================
    // RFF+LI is the key docs/00-basf.md names ("Fetch Shipment Cargo Line by RFF-LI id"), and
    // eDIID is the same "<note>/<position>" string BasfIftmin.dwl writes onto the cargo line.
    () -> "a cargo line is keyed by delivery note, position and the IFTMIN join key" in (
        fclSingle[0] must [
            $.deliveryNoteSAP must equalTo("3550879994"),
            $.deliveryPositionNumber must equalTo("000010"),
            $.eDIID must equalTo("3550879994/000010")
        ]),

    // The flow has no create path, and an upsert would add a duplicate line whenever the
    // delivery-note match failed.
    () -> "every cargo line is an update, never an upsert" in (
        ((ifcsum flatMap ((e) -> cargoOf(e.fixture)) map ((c) -> c.actionAttribute))
            distinctBy ((a) -> a)) must equalTo(["update"])),

    // === FCL: the container and its VGM =====================================================
    () -> "an FCL summary carries the container VGM, seal and signatory" in (
        fclVgm[0].container must [
            $.containerNumber must equalTo("CGMU5666332"),
            $.containerType.matchcode must equalTo("45RT"),
            $.verifiedGrossMass must equalTo(22273),
            $.sealNumber must equalTo("0024456"),
            $.vGMPersonInChanrge must equalTo("MR UNGER JOCHEN, HEAD OF WH")
        ]),

    () -> "every consignment of an FCL summary lands on the same container" in (
        (fclVgm map ((c) -> c.container.containerNumber))
            must equalTo(["CGMU5666332", "CGMU5666332", "CGMU5666332"])),

    () -> "an FCL summary has no MRN to report" in (
        (fclVgm map ((c) -> c.mRN)) must equalTo([null, null, null])),

    // === LCL: the MRN, and the truck that must not leak through =============================
    () -> "an LCL summary carries a customs MRN per consignment" in (
        (lclMrn map ((c) -> c.mRN))
            must equalTo(["26DE590487611538B5", "26DE590487611538B5", "26DE590487611538B5",
                          "26DE590487611535B8", "26DE590487611537B6", "26DE590487611536B7"])),

    // The equipment in an LCL summary is the truck that ran the goods to the terminal
    // ("Truck with removable tarp", no ISO type code) - pre-carriage equipment, not the
    // container the cargo line sits in. Writing it onto the cargo line would be wrong.
    // `soleContainer` used to be asserted directly; this is the same rule stated as the
    // consequence Carlo actually sees.
    () -> "the pre-carriage truck of an LCL summary is not written onto the cargo line" in (
        (lclMrn map ((c) -> c.container)) must equalTo([null, null, null, null, null, null])),

    () -> "a container with an ISO type code is written onto the cargo line" in (
        fclSingle[0].container must notBeNull()),

    () -> "six consignments yield six cargo lines" in (sizeOf(lclMrn) must equalTo(6)),

    // === cancel: the flow stops =============================================================
    // Cancelling a consolidation summary does not cancel the underlying cargo, so a code 1
    // message must contribute nothing at all. The pair below differs only in the BGM code,
    // so it isolates the cancel decision from every other reason a line might not appear.
    () -> "a cancelled summary drops a consignment it would otherwise have mapped" in (
        documentOf(summary("1")) must equalTo({ shipmentCargo: [] })),

    () -> "a code 9 summary is mapped rather than filtered out" in (
        sizeOf(documentOf(summary("9")).shipmentCargo) must equalTo(1)),

    // === guards =============================================================================
    () -> "a message with no consignments yields no cargo lines" in (
        documentOf(message("9")).shipmentCargo must equalTo([])),

    () -> "a consignment with no delivery note is dropped" in (
        documentOf({ Heading: { "1150_Segment_group_26": [{
            "1160_CNI": { CNI01: 1 },
            "2260_Segment_group_51": [{ "2270_GID": { GID01: 1 } }] }] } }).shipmentCargo
            must equalTo([])),

    // CNI02 repeats the delivery note; it is the fallback when the goods item has no RFF+LI.
    () -> "the delivery note falls back to CNI02 when the goods item has no RFF+LI" in (
        documentOf({ Heading: { "1150_Segment_group_26": [{
            "1160_CNI": { CNI01: 1, CNI0201: "3550984178" },
            "2260_Segment_group_51": [{ "2270_GID": { GID01: 1 } }] }] } }).shipmentCargo
            must equalTo([{ actionAttribute: "update", itemNumber: 1, deliveryNoteSAP: "3550984178" }])),

    // === wrapper shape ======================================================================
    () -> "the document is a camelCase shipmentCargo array" in (
        lclMrn[0] must equalTo({
            actionAttribute: "update",
            itemNumber: 1,
            deliveryNoteSAP: "3550984178",
            deliveryPositionNumber: "000010",
            eDIID: "3550984178/000010",
            mRN: "26DE590487611538B5"
        })),

    () -> "an interchange with no IFCSUM message yields an empty array" in (
        document({ EDI: { Messages: {} } }) must equalTo({ shipmentCargo: [] }))
    ]
)
