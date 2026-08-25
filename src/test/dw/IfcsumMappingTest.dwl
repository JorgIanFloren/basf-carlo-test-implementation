/**
* BASF IFCSUM mapping, exercised against every IFCSUM interchange in docs/example-orders
* (4 fixtures: 3 FCL, 1 LCL).
*
* Every cargo line is checked against example-orders/manifest.json, whose `cargo` rows are
* produced by `ifcsum_cargo()` in tools/edifact_to_json.py. That function walks the parsed
* tree by explicit key lookup where IfcsumModule walks it by segment-name suffix, so the
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
import camelKeys from CommonModule
import toCarloCargoUpdates, toCarloCargoUpdate, soleContainer, isCancel from IfcsumModule

var manifest = readUrl("classpath://example-orders/manifest.json", "application/json")
var ifcsum = manifest filter ((e) -> e.messageType == "IFCSUM")

fun load(fixture) = readUrl("classpath://example-orders/" ++ fixture, "application/json")

/** The document expression of BasfIfcsum.dwl, mirrored so the wrapper shape is pinned. */
fun document(payload) = { shipmentCargo: toCarloCargoUpdates(payload) map ((c) -> camelKeys(c)) }

fun actual(fixture) = toCarloCargoUpdates(load(fixture)) map ((c) -> {
    itemNumber: c.ItemNumber,
    deliveryNote: c.DeliveryNoteSAP,
    position: c.DeliveryPositionNumber,
    mrn: c.MRN,
    container: if (c.Container == null) null else {
        containerNumber: c.Container.ContainerNumber,
        containerType: c.Container.ContainerType.Matchcode,
        verifiedGrossMass: c.Container.VerifiedGrossMass,
        sealNumber: c.Container.SealNumber,
        vgmPerson: c.Container.VGMPersonInChanrge
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
---
"BASF IFCSUM mapping" describedBy (

    // === every example interchange, line by line ============================================
    (ifcsum map ((e) -> () ->
        (e.fixture ++ " (" ++ e.scenario ++ ", " ++ (sizeOf(e.cargo) as String) ++ " cargo line(s))")
            in (actual(e.fixture) must equalTo(expected(e))))) ++

    [
    // === identity ===========================================================================
    // RFF+LI is the key docs/00-basf.md names ("Fetch Shipment Cargo Line by RFF-LI id"), and
    // EDIID is the same "<note>/<position>" string IftminModule writes onto the cargo line.
    () -> "a cargo line is keyed by delivery note, position and the IFTMIN join key" in (
        (toCarloCargoUpdates(load("fcl/20260625-093948-681.json"))[0]) must [
            $.DeliveryNoteSAP must equalTo("3550880113"),
            $.DeliveryPositionNumber must equalTo("000010"),
            $.EDIID must equalTo("3550880113/000010")
        ]),

    // The flow has no create path, and an upsert would add a duplicate line whenever the
    // delivery-note match failed.
    () -> "every cargo line is an update, never an upsert" in (
        ((ifcsum flatMap ((e) -> toCarloCargoUpdates(load(e.fixture))) map ((c) -> c.actionAttribute))
            distinctBy ((a) -> a)) must equalTo(["update"])),

    // === FCL: the container and its VGM =====================================================
    () -> "an FCL summary carries the container VGM, seal and signatory" in (
        (toCarloCargoUpdates(load("fcl/20260625-142940-681-v2.json"))[0].Container) must [
            $.ContainerNumber must equalTo("CGMU5666332"),
            $.ContainerType.Matchcode must equalTo("45RT"),
            $.VerifiedGrossMass must equalTo(22273),
            $.SealNumber must equalTo("0024456"),
            $.VGMPersonInChanrge must equalTo("MR UNGER JOCHEN, HEAD OF WH")
        ]),

    () -> "every consignment of an FCL summary lands on the same container" in (
        (toCarloCargoUpdates(load("fcl/20260625-142940-681-v2.json")) map ((c) -> c.Container.ContainerNumber))
            must equalTo(["CGMU5666332", "CGMU5666332", "CGMU5666332"])),

    () -> "an FCL summary has no MRN to report" in (
        (toCarloCargoUpdates(load("fcl/20260625-142940-681-v2.json")) map ((c) -> c.MRN))
            must equalTo([null, null, null])),

    // === LCL: the MRN, and the truck that must not leak through =============================
    () -> "an LCL summary carries a customs MRN per consignment" in (
        (toCarloCargoUpdates(load("lcl/ifcsum-136579804.json")) map ((c) -> c.MRN))
            must equalTo(["26DE590487611538B5", "26DE590487611538B5", "26DE590487611538B5",
                          "26DE590487611535B8", "26DE590487611537B6", "26DE590487611536B7"])),

    // The equipment in an LCL summary is the truck that ran the goods to the terminal
    // ("Truck with removable tarp", no ISO type code) - pre-carriage equipment, not the
    // container the cargo line sits in. Writing it onto the cargo line would be wrong.
    () -> "the pre-carriage truck of an LCL summary is not written onto the cargo line" in (
        (toCarloCargoUpdates(load("lcl/ifcsum-136579804.json")) map ((c) -> c.Container))
            must equalTo([null, null, null, null, null, null])),

    () -> "a truck is not a container" in (soleContainer(load("lcl/ifcsum-136579804.json")
        .EDI.Messages.D08A.IFCSUM[0]) must equalTo(null)),

    () -> "a container with an ISO type code is" in (soleContainer(load("fcl/20260625-093948-681.json")
        .EDI.Messages.D08A.IFCSUM[0]) must notBeNull()),

    () -> "six consignments yield six cargo lines" in (
        sizeOf(toCarloCargoUpdates(load("lcl/ifcsum-136579804.json"))) must equalTo(6)),

    // === cancel: the flow stops =============================================================
    () -> "a cancel is recognised" in (isCancel(message("1")) must equalTo(true)),
    () -> "a create is not a cancel" in (isCancel(message("9")) must equalTo(false)),
    () -> "a cancelled summary produces no cargo update at all" in (
        toCarloCargoUpdates({ EDI: { Messages: { D08A: { IFCSUM: [ message("1") ] } } } })
            must equalTo([])),

    // === guards =============================================================================
    () -> "a message with no consignments yields no cargo lines" in (
        toCarloCargoUpdate(message("9")) must equalTo([])),

    () -> "a consignment with no delivery note is dropped" in (
        toCarloCargoUpdate({ Heading: { "1150_Segment_group_26": [{
            "1160_CNI": { CNI01: 1 },
            "2260_Segment_group_51": [{ "2270_GID": { GID01: 1 } }] }] } })
            must equalTo([])),

    // CNI02 repeats the delivery note; it is the fallback when the GID has no RFF+LI.
    () -> "the delivery note falls back to CNI02 when the goods item has no RFF+LI" in (
        toCarloCargoUpdate({ Heading: { "1150_Segment_group_26": [{
            "1160_CNI": { CNI01: 1, CNI0201: "3550984178" },
            "2260_Segment_group_51": [{ "2270_GID": { GID01: 1 } }] }] } })
            must equalTo([{ actionAttribute: "update", ItemNumber: 1, DeliveryNoteSAP: "3550984178" }])),

    // === wrapper shape ======================================================================
    () -> "the document is a camelCase shipmentCargo array" in (
        document(load("lcl/ifcsum-136579804.json")).shipmentCargo[0] must equalTo({
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
