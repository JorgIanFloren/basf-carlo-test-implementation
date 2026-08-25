/**
* BASF IFTMBF mapping, exercised against every IFTMBF interchange in docs/example-orders
* (9 fixtures: 4 FCL, 1 LCL, 4 master-sub/ms).
*
* IFTMBF updates a shipment IFTMIN already created, so the interesting property is as much
* what the mapping does NOT emit as what it does: anything outside the "Update" worksheet
* would overwrite live shipment data with booking-stage values. "nothing unmapped leaks"
* below is the test that guards that, across every fixture.
*
* The per-fixture expectations come from example-orders/manifest.json, which records the
* message's own BGM code, CustomerReference and equipment count.
*/
%dw 2.0
import * from dw::test::Tests
import * from dw::test::Asserts
import camelKeys from CommonModule
import every from dw::core::Arrays
import toCarloBookingUpdates, toCarloBookingUpdate, isCancel, scenario, haulageType, dateFromText, dispatchDate, shipmentAction from IftmbfModule

var manifest = readUrl("classpath://example-orders/manifest.json", "application/json")
var iftmbf = manifest filter ((e) -> e.messageType == "IFTMBF")

fun load(fixture) = readUrl("classpath://example-orders/" ++ fixture, "application/json")

/** The document expression of BasfIftmbf.dwl, mirrored so the wrapper shape is pinned. */
fun document(payload) = { seaHouseShipment: toCarloBookingUpdates(payload) map ((s) -> camelKeys(s)) }

/** Every field name the "Update" worksheet maps, plus the three contract-required extras.
 *  A booking that emitted anything else would be overwriting shipment data. */
var allowedFields = [
    "actionAttribute", "DUNSCustomer", "CustomerReference", "Customer", "EstimatedDispatchDate",
    "PickupLocation", "ObjectOwner", "Scenario", "HaulageType", "DeliveryTerms", "ShipmentDate", "Master"
]

fun actual(fixture) = toCarloBookingUpdates(load(fixture)) map ((s) -> {
    ref: s.CustomerReference,
    action: s.actionAttribute,
    scenario: s.Scenario.Matchcode,
    terms: s.DeliveryTerms,
    owner: s.ObjectOwner.OrganisationalUnitId,
    hasMaster: s.Master != null,
    onlyMappedFields: (s pluck ((v, k) -> k as String)) every ((k) -> allowedFields contains k)
})

fun expectedAction(code) = code match {
    case "4" -> "update"
    case "5" -> "update"
    else -> "updateorcreate"
}
fun expected(e) = e.messages map ((m) -> {
    ref: m.customerReference,
    action: expectedAction(m.code),
    scenario: if (m.equipment > 0) "BASF FCL" else "BASF LCL",
    terms: "Prepaid",
    owner: 5,
    hasMaster: true,
    onlyMappedFields: true
})

// --- synthetic messages -------------------------------------------------------------------
fun booking(code, ref) = {
    Interchange: { UNB0201: "BASFAG2" },
    MessageHeader: { UNH01: "1" },
    Heading: { "0020_BGM": { BGM0101: "335", BGM0201: ref, BGM03: code } }
}
fun withEquipment(tmd) = { Heading: { "1260_Segment_group_32": [{ "1270_EQD": { EQD01: "CN" }, "1290_TMD": tmd }] } }
fun withLoc20() = { "0400_Segment_group_8": [{ "0410_LOC": { LOC01: "20", LOC0201: "USCMH" } }] }
fun withEquipmentAndLoc20(tmd) = {
    Heading: {
        "0360_Segment_group_7": [{ "0370_TDT": { TDT01: "30" } } ++ withLoc20() ],
        "1260_Segment_group_32": [{ "1270_EQD": { EQD01: "CN" }, "1290_TMD": tmd }]
    }
}
fun carrierTmd() = { TMD0101: "3", TMD0102: "Carriers Haulage", TMD03: "1" }
fun merchantTmd() = { TMD0101: "3", TMD0102: "Merchants Haulage", TMD03: "2" }
---
"BASF IFTMBF mapping" describedBy (

    // === every example interchange ==========================================================
    (iftmbf map ((e) -> () ->
        (e.fixture ++ " (" ++ e.scenario ++ ")")
            in (actual(e.fixture) must equalTo(expected(e))))) ++

    [
    // === sheet-mapped values, against the richest FCL fixture ==============================
    () -> "DUNSCustomer comes from UNB0201" in (
        toCarloBookingUpdates(load("fcl/2800209301-iftmin-absch-9.json"))[0].DUNSCustomer
            must equalTo("BASFAG2")),

    () -> "CustomerReference comes from BGM0201" in (
        toCarloBookingUpdates(load("fcl/2800209301-iftmin-absch-9.json"))[0].CustomerReference
            must equalTo("2800209301")),

    () -> "Customer matchcode comes from NAD+CZ" in (
        toCarloBookingUpdates(load("fcl/2800209301-iftmin-absch-9.json"))[0].Customer.Matchcode
            must equalTo("1000")),

    () -> "the pickup place comes from LOC+10" in (
        toCarloBookingUpdates(load("fcl/2800209301-iftmin-absch-9.json"))[0]
            .PickupLocation.PickupLocation.UnLocationCode.Matchcode must equalTo("DELUH")),

    // DTM+132 occurs under both TDT+20 and TDT+30; only the main carriage feeds CustomerETA.
    () -> "CustomerETA comes from DTM+132 of the main carriage, not the on-carriage" in (
        toCarloBookingUpdates(load("fcl/2800209301-iftmin-absch-9.json"))[0]
            .Master.MainCarriageAsOcean.CustomerETA must equalTo("2026-05-08")),

    () -> "CustomerClosing comes from DTM+180" in (
        toCarloBookingUpdates(load("fcl/2800209301-iftmin-absch-9.json"))[0]
            .Master.MainCarriageAsOcean.CustomerClosing must equalTo("2026-04-15")),

    // === the LCL gap the sheet leaves open ==================================================
    // With no EQD there is no equipment group, so neither HaulageType (no TMD) nor
    // EstimatedDispatchDate (no equipment FTX+ITR) can be derived. Omitting a field on an
    // update is the safe failure mode; see docs/iftmbf/01-IFTMBF_mapping_spec.md open item 6.
    () -> "an LCL booking omits HaulageType and EstimatedDispatchDate rather than guessing" in (
        ((toCarloBookingUpdates(load("lcl/2800226066-iftmbf-9.json"))[0] pluck ((v, k) -> k as String))
            filter ((k) -> ["HaulageType", "EstimatedDispatchDate"] contains k)) must equalTo([])),

    () -> "an LCL booking is scenario BASF LCL" in (
        toCarloBookingUpdates(load("lcl/2800226066-iftmbf-9.json"))[0].Scenario.Matchcode
            must equalTo("BASF LCL")),

    // === cancel: the flow stops =============================================================
    () -> "a cancel is recognised" in (isCancel(booking("1", "X")) must equalTo(true)),
    () -> "a cancelled booking produces no call at all" in (
        toCarloBookingUpdates({ EDI: { Messages: { D08A: { IFTMBF: [ booking("1", "2800209301") ] } } } })
            must equalTo([])),
    () -> "a non-cancelled booking does produce a call" in (
        sizeOf(toCarloBookingUpdates({ EDI: { Messages: { D08A: { IFTMBF: [ booking("9", "2800209301") ] } } } }))
            must equalTo(1)),

    // === guards =============================================================================
    () -> "no shipment from a null message" in (toCarloBookingUpdate(null) must equalTo(null)),
    () -> "no shipment from an empty message" in (toCarloBookingUpdate({}) must equalTo(null)),
    () -> "no shipment when BGM0201 is missing" in (
        toCarloBookingUpdate({ Heading: { "0020_BGM": { BGM03: "9" } } }) must equalTo(null)),
    () -> "no shipment when BGM0201 is blank" in (
        toCarloBookingUpdate({ Heading: { "0020_BGM": { BGM0201: "   " } } }) must equalTo(null)),

    // Master is contract-required so it is always present, but a blank carriage node must
    // never be sent - Carlo may replace the node wholesale and wipe what IFTMIN put there.
    () -> "no blank carriage node when the main stage has no dates" in (
        toCarloBookingUpdate({ Heading: { "0020_BGM": { BGM0201: "X" } } }).Master must equalTo({})),

    () -> "MainCarriageAsOcean carries whichever date is present" in (
        toCarloBookingUpdate({ Heading: { "0020_BGM": { BGM0201: "X" },
            "0360_Segment_group_7": [{ "0370_TDT": { TDT01: "20" },
                "0380_DTM": [{ DTM0101: "180", DTM0102: "20260415" }] }] } }).Master
            must equalTo({ MainCarriageAsOcean: { CustomerClosing: "2026-04-15" } })),

    // === derivation units the fixtures cannot all reach =====================================
    () -> "dot date" in (dateFromText("Planned Loading Date: 08.04.2026") must equalTo("2026-04-08")),
    () -> "slash date" in (dateFromText("08/04/2026") must equalTo("2026-04-08")),
    () -> "dash date" in (dateFromText("8-4-2026") must equalTo("2026-04-08")),
    () -> "space date" in (dateFromText("08 04 2026") must equalTo("2026-04-08")),
    () -> "no date" in (dateFromText("no date here") must equalTo(null)),
    () -> "null date" in (dateFromText(null) must equalTo(null)),
    () -> "impossible month rejected" in (dateFromText("08.99.2026") must equalTo(null)),
    () -> "impossible day rejected" in (dateFromText("41.04.2026") must equalTo(null)),
    () -> "a longer number does not yield a tail match" in (dateFromText("112.04.2026") must equalTo(null)),

    () -> "Scenario FCL when EQD present" in (scenario(withEquipment(carrierTmd())) must equalTo("BASF FCL")),
    () -> "Scenario LCL when EQD absent" in (scenario({ Heading: {} }) must equalTo("BASF LCL")),

    () -> "Haulage CAR/CAR (TMD 1 + LOC+20)" in (haulageType(withEquipmentAndLoc20(carrierTmd())) must equalTo("CAR/CAR")),
    () -> "Haulage CAR/MER (TMD 1, no LOC+20)" in (haulageType(withEquipment(carrierTmd())) must equalTo("CAR/MER")),
    () -> "Haulage MER/MER (TMD 2, no LOC+20)" in (haulageType(withEquipment(merchantTmd())) must equalTo("MER/MER")),
    () -> "Haulage MER/CAR (TMD 2 + LOC+20)" in (haulageType(withEquipmentAndLoc20(merchantTmd())) must equalTo("MER/CAR")),
    () -> "Haulage falls back to the C219 description" in (
        haulageType(withEquipment({ TMD0102: "Carriers Haulage" })) must equalTo("CAR/MER")),
    () -> "Haulage defaults to MER on an unknown code" in (
        haulageType(withEquipment({ TMD03: "7" })) must equalTo("MER/MER")),
    () -> "Haulage omitted when there is no TMD (LCL)" in (haulageType({ Heading: {} }) must equalTo(null)),
    () -> "dispatch date null without FTX+ITR" in (dispatchDate(withEquipment(carrierTmd())) must equalTo(null)),

    () -> "BGM03 1 -> delete" in (shipmentAction(booking("1", "X")) must equalTo("delete")),
    () -> "BGM03 4 -> update" in (shipmentAction(booking("4", "X")) must equalTo("update")),
    () -> "BGM03 5 -> update" in (shipmentAction(booking("5", "X")) must equalTo("update")),
    () -> "BGM03 9 -> updateorcreate" in (shipmentAction(booking("9", "X")) must equalTo("updateorcreate")),

    // === wrapper shape ======================================================================
    () -> "the document is a camelCase seaHouseShipment array" in (
        document(load("lcl/2800226066-iftmbf-9.json")).seaHouseShipment[0].customerReference
            must equalTo("2800226066")),

    () -> "an interchange with no IFTMBF message yields an empty array" in (
        document({ EDI: { Messages: {} } }) must equalTo({ seaHouseShipment: [] }))
    ]
)
