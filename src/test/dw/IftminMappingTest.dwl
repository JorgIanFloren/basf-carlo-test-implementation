/**
* BASF IFTMIN mapping, exercised against every IFTMIN interchange in
* docs/example-orders (21 fixtures: 9 FCL, 3 LCL, 9 master-sub/ms).
*
* The bulk of the suite is data-driven from example-orders/manifest.json, which
* tools/edifact_to_json.py writes when it converts the examples. Each manifest row records
* what the *message* says - its BASF BL, its BGM message-function code, its
* CustomerReference and whether it carries equipment - read straight off the parsed tree.
* The expectations below are derived from those facts independently of the mapping, so a
* wrong flow decision (FCL taken for LCL, a master-sub not split, a missing Coloadin) fails
* here rather than being restated.
*
* No code 1 (cancel) message exists anywhere in the example set, so the cancel branch is
* covered by synthetic messages at the end.
*/
%dw 2.0
import * from dw::test::Tests
import * from dw::test::Asserts
import camelKeys from CommonModule
import toCarloShipments, toCarloShipment, cancelShipment, houseType, loadType, isCancel, shipmentAction from IftminModule

var manifest = readUrl("classpath://example-orders/manifest.json", "application/json")
var iftmin = manifest filter ((e) -> e.messageType == "IFTMIN")

fun load(fixture) = readUrl("classpath://example-orders/" ++ fixture, "application/json")

/** The document expression of BasfIftmin.dwl, mirrored so the wrapper shape is pinned too
 *  (a mapping file cannot be imported, so the entry point itself is covered by compilation). */
fun document(payload) = { seaHouseShipment: toCarloShipments(payload) map ((s) -> camelKeys(s)) }

// --- what the mapping produced ------------------------------------------------------------
fun actual(fixture) = toCarloShipments(load(fixture)) map ((s) -> {
    bl: s.BASFBL,
    ref: s.CustomerReference,
    load: s.LoadType,
    house: s.HouseType,
    scenario: s.Scenario.Matchcode,
    action: s.actionAttribute,
    // The Carlo contract's required top-level set. `Customer` and `Master` are objects, so
    // presence is what matters here; their contents are covered by the field tests below.
    complete: s.CustomerReference != null and s.DeliveryTerms != null and s.ShipmentDate != null
        and s.ObjectOwner.OrganisationalUnitId != null and s.Customer != null and s.Master != null
})

// --- what the message says it should be ----------------------------------------------------
fun expectedLoad(m) = if (m.equipment > 0) "FCL" else "LCL"
fun expectedAction(code) = code match {
    case "1" -> "delete"
    case "4" -> "update"
    case "5" -> "update"
    else -> "updateorcreate"
}
fun expected(e) = e.messages map ((m) -> {
    bl: m.bl,
    ref: m.customerReference,
    load: expectedLoad(m),
    // Co-load only where the flow says: a master-sub interchange whose block is LCL.
    house: if (e.masterSub and expectedLoad(m) == "LCL") "Coloadin" else "BackToBack",
    scenario: "BASF " ++ expectedLoad(m),
    action: expectedAction(m.code),
    complete: true
})

// --- synthetic messages for the branches the examples never reach ---------------------------
fun bgm(code, ref) = {
    Interchange: { UNB0201: "BASFAG2" },
    MessageHeader: { UNH03: "BL00" },
    Heading: { "0020_BGM": { BGM0101: "705", BGM0201: ref, BGM03: code } }
}
fun withEquipment(msg) = msg update {
    case h at .Heading -> h ++ { "1640_Segment_group_37": [{ "1650_EQD": { EQD01: "CN", EQD0201: "ABCU1234567" } }] }
}
---
"BASF IFTMIN mapping" describedBy (

    // === every example interchange, FCL / LCL / master-sub =================================
    // `describedBy` takes thunks. Written as a literal the compiler wraps each `in (...)`
    // for you; built with `map` the wrapping has to be explicit, hence the `() ->`.
    (iftmin map ((e) -> () ->
        (e.fixture ++ " (" ++ e.scenario ++ ", " ++ (e.messageCount as String) ++ " message(s))")
            in (actual(e.fixture) must equalTo(expected(e))))) ++

    [
    // === the flow decisions, called out explicitly ========================================
    () -> "a master-sub interchange yields one shipment per BASF BL" in (
        (toCarloShipments(load("ms/2800231445-ab-9.json")) map ((s) -> s.BASFBL))
            must equalTo(["BL01", "BL02"])),

    () -> "an ordinary interchange yields exactly one shipment" in (
        sizeOf(toCarloShipments(load("fcl/2800209301-fcl-iftmin-erst-9.json"))) must equalTo(1)),

    // The whole point of the co-load rule: same split, but the blocks carry no equipment.
    () -> "an LCL master-sub marks every block as a co-load" in (
        (toCarloShipments(load("ms/trissquid-138083512.json")) map ((s) -> s.HouseType))
            must equalTo(["Coloadin", "Coloadin"])),

    () -> "an FCL master-sub stays back-to-back" in (
        (toCarloShipments(load("ms/2800231445-iftmbf-2.json")) map ((s) -> s.HouseType))
            must equalTo(["BackToBack", "BackToBack"])),

    () -> "a single LCL shipment is not a co-load" in (
        (toCarloShipments(load("lcl/2800226066-iftmin-erst-9.json")) map ((s) -> s.HouseType))
            must equalTo(["BackToBack"])),

    // === cancel (BGM03 = 1) - no example message exists ====================================
    () -> "a cancel is recognised" in (isCancel(bgm("1", "2800244026")) must equalTo(true)),
    () -> "a create is not a cancel" in (isCancel(bgm("9", "2800244026")) must equalTo(false)),
    () -> "an update is not a cancel" in (isCancel(bgm("4", "2800244026")) must equalTo(false)),

    () -> "a cancel maps to an identity-only delete" in (
        toCarloShipments({ EDI: { Messages: { D99A: { IFTMIN: [ bgm("1", "2800244026") ] } } } })
            must equalTo([{
                actionAttribute: "delete",
                DUNSCustomer: "BASFAG2",
                BASFBL: "BL00",
                CustomerReference: "2800244026"
            }])),

    () -> "a cancel carries no business fields that could overwrite the shipment" in (
        (cancelShipment(bgm("1", "2800244026")) pluck ((v, k) -> k as String))
            must equalTo(["actionAttribute", "DUNSCustomer", "BASFBL", "CustomerReference"])),

    () -> "a cancel without a CustomerReference is dropped - Carlo would have nothing to match" in (
        toCarloShipments({ EDI: { Messages: { D99A: { IFTMIN: [ bgm("1", null) ] } } } })
            must equalTo([])),

    // === derivation units ==================================================================
    () -> "LoadType is FCL when equipment is present" in (loadType(withEquipment(bgm("9", "X"))) must equalTo("FCL")),
    () -> "LoadType is LCL when equipment is absent" in (loadType(bgm("9", "X")) must equalTo("LCL")),
    () -> "HouseType is BackToBack for a stand-alone LCL" in (houseType(bgm("9", "X"), false) must equalTo("BackToBack")),
    () -> "HouseType is Coloadin for an LCL block of a master-sub" in (houseType(bgm("9", "X"), true) must equalTo("Coloadin")),
    () -> "HouseType stays BackToBack for an FCL block of a master-sub" in (
        houseType(withEquipment(bgm("9", "X")), true) must equalTo("BackToBack")),
    () -> "BGM03 1 -> delete" in (shipmentAction(bgm("1", "X")) must equalTo("delete")),
    () -> "BGM03 4 -> update" in (shipmentAction(bgm("4", "X")) must equalTo("update")),
    () -> "BGM03 5 -> update" in (shipmentAction(bgm("5", "X")) must equalTo("update")),
    () -> "BGM03 9 -> updateorcreate" in (shipmentAction(bgm("9", "X")) must equalTo("updateorcreate")),

    // === wrapper shape =====================================================================
    () -> "the document is a camelCase seaHouseShipment array" in (
        (document(load("lcl/2800226066-iftmin-erst-9.json")).seaHouseShipment[0]
            pluck ((v, k) -> k as String))[0 to 3]
            must equalTo(["actionAttribute", "preferredModeOfTransport", "dUNSCustomer", "bASFBL"])),

    () -> "an interchange with no IFTMIN message yields an empty array" in (
        document({ EDI: { Messages: {} } }) must equalTo({ seaHouseShipment: [] }))
    ]
)
