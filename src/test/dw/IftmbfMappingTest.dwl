/**
* BASF IFTMBF mapping, exercised against every IFTMBF interchange in docs/example-orders
* (9 fixtures: 4 FCL, 1 LCL, 4 master-sub/ms).
*
* The mapping is run the way the data-transformer runs it: `evalPath` executes
* src/main/dw/BasfIftmbf.dwl - the whole self-contained script, output header and document
* body included - against a `payload` context and returns the parsed JSON Carlo would
* receive. Nothing is imported from the mapping, so no part of it is restated here and there
* is nothing to keep in sync.
*
* The derivation tests at the bottom used to call `dateFromText` / `haulageType` / `scenario`
* directly. They now build a synthetic *interchange* carrying just the segments that branch
* depends on and read the field it produces, so they assert the value Carlo receives rather
* than the value a helper returns. Note the consequence for dates: `dispatchDate` pads the
* parsed date with T00:00:00, so a date that parses shows up as "2026-04-08T00:00:00" and one
* that does not is absent from the document entirely.
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
import every from dw::core::Arrays

var MAPPING = "BasfIftmbf.dwl"

var manifest = readUrl("classpath://example-orders/manifest.json", "application/json")
var iftmbf = manifest filter ((e) -> e.messageType == "IFTMBF")

/**
* Run the mapping script over a whole parsed interchange and return the Carlo document.
* This is the only route the suite has into the mapping - the same call the data-transformer
* makes - so a break in the output header, the document body or any helper surfaces here.
*/
fun document(payload) = evalPath(MAPPING, { payload: payload }, "application/json")

/** The document for an interchange built from the given synthetic messages. */
fun documentOf(msgs) = document({ EDI: { Messages: { D08A: { IFTMBF: msgs } } } })

/** The single booking update a one-message synthetic interchange maps to. */
fun only(msg) = documentOf([ msg ]).seaHouseShipment[0]

fun load(fixture) = readUrl("classpath://example-orders/" ++ fixture, "application/json")
fun bookingsOf(fixture) = document(load(fixture)).seaHouseShipment

// Evaluated once and reused: the richest FCL fixture backs most of the field assertions.
var fclRich = bookingsOf("fcl/2800209301-iftmin-absch-9.json")
var lcl = bookingsOf("lcl/2800226066-iftmbf-9.json")

/** Every field name the "Update" worksheet maps, plus the contract-required extras and the
 *  three identity fields that address one dossier (`id`, `bASFBL`, `eDIID` - all taken from
 *  the looked-up record, never from the booking, which knows no BL).
 *  A booking that emitted anything else would be overwriting shipment data. */
var allowedFields = [
    "actionAttribute", "id", "dUNSCustomer", "customerReference", "bASFBL", "eDIID",
    "customer", "estimatedDispatchDate", "pickupLocation", "objectOwner", "scenario",
    "haulageType", "deliveryTerms", "shipmentDate", "master"
]

fun actual(fixture) = bookingsOf(fixture) map ((s) -> {
    ref: s.customerReference,
    action: s.actionAttribute,
    scenario: s.scenario.matchcode,
    terms: s.deliveryTerms,
    owner: s.objectOwner.organisationalUnitId,
    hasMaster: s.master != null,
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
fun booking(code, ref) = booking(code, ref, {})

/** A booking message with `heading` merged into its Heading, alongside the BGM. */
fun booking(code, ref, heading) = {
    Interchange: { UNB0201: "BASFAG2" },
    MessageHeader: { UNH01: "1" },
    Heading: { "0020_BGM": { BGM0101: "335", BGM0201: ref, BGM03: code } } ++ heading
}

/** An equipment group carrying the given TMD - what `haulageType` reads pre-carriage from. */
fun equipment(tmd) = { "1260_Segment_group_32": [{ "1270_EQD": { EQD01: "CN" }, "1290_TMD": tmd }] }

/** An equipment group whose FTX+ITR free text is `txt` - what `dispatchDate` parses. */
fun equipmentWithText(txt) = { "1260_Segment_group_32": [{
    "1270_EQD": { EQD01: "CN" },
    "1280_FTX": [{ FTX01: "ITR", FTX0401: txt }] }] }

/** A place of delivery (LOC+20) - what `haulageType` reads on-carriage from. */
var loc20 = { "0360_Segment_group_7": [{
    "0370_TDT": { TDT01: "30" },
    "0400_Segment_group_8": [{ "0410_LOC": { LOC01: "20", LOC0201: "USCMH" } }] }] }

fun carrierTmd() = { TMD0101: "3", TMD0102: "Carriers Haulage", TMD03: "1" }
fun merchantTmd() = { TMD0101: "3", TMD0102: "Merchants Haulage", TMD03: "2" }

/** HaulageType matchcode for a booking carrying `tmd`, with or without a place of delivery. */
fun haulageFor(tmd) = only(booking("9", "X", equipment(tmd))).haulageType.matchcode
fun haulageForWithLoc20(tmd) = only(booking("9", "X", equipment(tmd) ++ loc20)).haulageType.matchcode

/** EstimatedDispatchDate for a booking whose equipment FTX+ITR reads `txt`. */
fun dispatchFor(txt) = only(booking("9", "X", equipmentWithText(txt))).estimatedDispatchDate

// --- the "GET dossier by CustomerRef" lookup ----------------------------------------------
/**
* A captured lookup response from docs/get-responses, by file stem - real server responses,
* so the dossier ids and reference fields asserted below are the records the integration
* really created. See the same helper in IftminMappingTest.dwl.
*
* Step 1 of the IFTMBF flow GETs the dossiers of the order and step 2 PUTs each one, so what
* this response contains decides how many calls one booking becomes.
*/
fun lookup(name) = readUrl("classpath://get-responses/" ++ name ++ ".json", "application/json")

/** The booking updates a fixture maps to when evaluated together with a lookup. */
fun bookingsWith(fixture, name) =
    document(load(fixture) ++ { lookup: lookup(name) }).seaHouseShipment

/** The booking updates synthetic messages map to when evaluated with an explicit lookup. */
fun bookingsWithLookup(msgs, lk) =
    document({ EDI: { Messages: { D08A: { IFTMBF: msgs } } }, lookup: lk }).seaHouseShipment

/** A lookup response carrying the given dossiers. */
fun found(dossiers) = { seaHouseShipment: dossiers }

/** The address a booking update carries: which record it updates and how. */
fun addressOf(s) = { bl: s.bASFBL, ediid: s.eDIID, id: s.id default 0, action: s.actionAttribute }

/** The sheet-mapped values of a booking update - everything that is not the address. */
fun mappedValuesOf(s) = {
    dispatch: s.estimatedDispatchDate,
    eta: s.master.mainCarriageAsOcean.customerETA,
    closing: s.master.mainCarriageAsOcean.customerClosing,
    pickup: s.pickupLocation.pickupLocation.unLocationCode.matchcode,
    terms: s.deliveryTerms
}

// Evaluated once and reused: the master-sub booking for order 2800231445, read against the
// two dossiers its IFTMIN already created for BL01 and BL02.
var msFanOut = bookingsWith("ms/messages.json", "iftmin-before-iftmbf-mastersub-fcl")
---
"BASF IFTMBF mapping" describedBy (

    // === every example interchange ==========================================================
    (iftmbf map ((e) -> () ->
        (e.fixture ++ " (" ++ e.scenario ++ ")")
            in (actual(e.fixture) must equalTo(expected(e))))) ++

    [
    // === sheet-mapped values, against the richest FCL fixture ==============================
    () -> "DUNSCustomer comes from UNB0201" in (
        fclRich[0].dUNSCustomer must equalTo("BASFAG2")),

    () -> "CustomerReference comes from BGM0201" in (
        fclRich[0].customerReference must equalTo("2800209301")),

    () -> "Customer matchcode comes from NAD+CZ" in (
        fclRich[0].customer.matchcode must equalTo("1000")),

    () -> "the pickup place comes from LOC+10" in (
        fclRich[0].pickupLocation.pickupLocation.unLocationCode.matchcode must equalTo("DELUH")),

    // DTM+132 occurs under both TDT+20 and TDT+30; only the main carriage feeds CustomerETA.
    () -> "CustomerETA comes from DTM+132 of the main carriage, not the on-carriage" in (
        fclRich[0].master.mainCarriageAsOcean.customerETA must equalTo("2026-05-08")),

    () -> "CustomerClosing comes from DTM+180" in (
        fclRich[0].master.mainCarriageAsOcean.customerClosing must equalTo("2026-04-15")),

    // === the LCL gap the sheet leaves open ==================================================
    // With no EQD there is no equipment group, so neither HaulageType (no TMD) nor
    // EstimatedDispatchDate (no equipment FTX+ITR) can be derived. Omitting a field on an
    // update is the safe failure mode; see docs/iftmbf/01-IFTMBF_mapping_spec.md open item 6.
    () -> "an LCL booking omits HaulageType and EstimatedDispatchDate rather than guessing" in (
        ((lcl[0] pluck ((v, k) -> k as String))
            filter ((k) -> ["haulageType", "estimatedDispatchDate"] contains k)) must equalTo([])),

    () -> "an LCL booking is scenario BASF LCL" in (
        lcl[0].scenario.matchcode must equalTo("BASF LCL")),

    // === cancel: the flow stops =============================================================
    () -> "a cancelled booking produces no call at all" in (
        documentOf([ booking("1", "2800209301") ]) must equalTo({ seaHouseShipment: [] })),

    () -> "a non-cancelled booking does produce a call" in (
        sizeOf(documentOf([ booking("9", "2800209301") ]).seaHouseShipment) must equalTo(1)),

    // === guards =============================================================================
    () -> "no shipment from a null message" in (
        documentOf([ null ]).seaHouseShipment must equalTo([])),
    () -> "no shipment from an empty message" in (
        documentOf([ {} ]).seaHouseShipment must equalTo([])),
    () -> "no shipment when BGM0201 is missing" in (
        documentOf([ { Heading: { "0020_BGM": { BGM03: "9" } } } ]).seaHouseShipment must equalTo([])),
    () -> "no shipment when BGM0201 is blank" in (
        documentOf([ { Heading: { "0020_BGM": { BGM0201: "   " } } } ]).seaHouseShipment must equalTo([])),

    // Master is contract-required so it is always present, but a blank carriage node must
    // never be sent - Carlo may replace the node wholesale and wipe what IFTMIN put there.
    () -> "no blank carriage node when the main stage has no dates" in (
        only(booking("9", "X")).master must equalTo({})),

    () -> "MainCarriageAsOcean carries whichever date is present" in (
        only(booking("9", "X", { "0360_Segment_group_7": [{ "0370_TDT": { TDT01: "20" },
            "0380_DTM": [{ DTM0101: "180", DTM0102: "20260415" }] }] })).master
            must equalTo({ mainCarriageAsOcean: { customerClosing: "2026-04-15" } })),

    // === date parsing, read off EstimatedDispatchDate ======================================
    // dispatchDate pads a parsed date with T00:00:00; an unparseable one drops the field.
    () -> "dot date" in (dispatchFor("Planned Loading Date: 08.04.2026") must equalTo("2026-04-08T00:00:00")),
    () -> "slash date" in (dispatchFor("08/04/2026") must equalTo("2026-04-08T00:00:00")),
    () -> "dash date" in (dispatchFor("8-4-2026") must equalTo("2026-04-08T00:00:00")),
    () -> "space date" in (dispatchFor("08 04 2026") must equalTo("2026-04-08T00:00:00")),
    () -> "no date" in (dispatchFor("no date here") must beNull()),
    () -> "null date" in (dispatchFor(null) must beNull()),
    () -> "impossible month rejected" in (dispatchFor("08.99.2026") must beNull()),
    () -> "impossible day rejected" in (dispatchFor("41.04.2026") must beNull()),
    () -> "a longer number does not yield a tail match" in (dispatchFor("112.04.2026") must beNull()),
    () -> "dispatch date absent without FTX+ITR" in (
        only(booking("9", "X", equipment(carrierTmd()))).estimatedDispatchDate must beNull()),

    // === scenario and haulage ==============================================================
    () -> "Scenario FCL when EQD present" in (
        only(booking("9", "X", equipment(carrierTmd()))).scenario.matchcode must equalTo("BASF FCL")),
    () -> "Scenario LCL when EQD absent" in (
        only(booking("9", "X")).scenario.matchcode must equalTo("BASF LCL")),

    () -> "Haulage CAR/CAR (TMD 1 + LOC+20)" in (haulageForWithLoc20(carrierTmd()) must equalTo("CAR/CAR")),
    () -> "Haulage CAR/MER (TMD 1, no LOC+20)" in (haulageFor(carrierTmd()) must equalTo("CAR/MER")),
    () -> "Haulage MER/MER (TMD 2, no LOC+20)" in (haulageFor(merchantTmd()) must equalTo("MER/MER")),
    () -> "Haulage MER/CAR (TMD 2 + LOC+20)" in (haulageForWithLoc20(merchantTmd()) must equalTo("MER/CAR")),
    () -> "Haulage falls back to the C219 description" in (
        haulageFor({ TMD0102: "Carriers Haulage" }) must equalTo("CAR/MER")),
    () -> "Haulage defaults to MER on an unknown code" in (
        haulageFor({ TMD03: "7" }) must equalTo("MER/MER")),
    () -> "Haulage omitted when there is no TMD (LCL)" in (
        only(booking("9", "X")).haulageType must beNull()),

    () -> "BGM03 4 -> update" in (only(booking("4", "X")).actionAttribute must equalTo("update")),
    () -> "BGM03 5 -> update" in (only(booking("5", "X")).actionAttribute must equalTo("update")),
    () -> "BGM03 9 -> updateorcreate" in (only(booking("9", "X")).actionAttribute must equalTo("updateorcreate")),

    // === wrapper shape ======================================================================
    () -> "the document is a camelCase seaHouseShipment array" in (
        lcl[0].customerReference must equalTo("2800226066")),

    () -> "an interchange with no IFTMBF message yields an empty array" in (
        document({ EDI: { Messages: {} } }) must equalTo({ seaHouseShipment: [] })),

    // === issue 2: one booking, one update per dossier of the order =========================
    // An IFTMBF describes the whole order and carries no BL, so for a master-sub order whose
    // IFTMIN already created BL01 and BL02 there are two dossiers the single booking has to
    // reach. Emitting one update left the booking data on only one of them.
    () -> "a master-sub booking fans out to every dossier of the order" in (
        (msFanOut map ((s) -> addressOf(s))) must equalTo([
            { bl: "BL01", ediid: "2800231445BL01", id: 1607396, action: "update" },
            { bl: "BL02", ediid: "2800231445BL02", id: 1607444, action: "update" }
        ])),

    () -> "the fan-out addresses two distinct dossiers" in (
        sizeOf((msFanOut map ((s) -> s.id)) distinctBy ((i) -> i)) must equalTo(2)),

    // The booking knows nothing about BLs, so every copy must carry identical mapped values -
    // only the address differs. If a mapped field varied per dossier it would mean the
    // fan-out was reading something it should not.
    () -> "every dossier receives the same booking values" in (
        mappedValuesOf(msFanOut[1]) must equalTo(mappedValuesOf(msFanOut[0]))),

    // Stated as concrete values too, so the test fails if the fan-out ever starts mapping
    // nothing at all and the equality above holds trivially.
    () -> "the fanned-out values are the ones the booking maps" in (
        mappedValuesOf(msFanOut[0]) must equalTo({
            dispatch: "2026-07-06T00:00:00",
            eta: "2026-08-04",
            closing: "2026-07-08",
            pickup: "DEDUS",
            terms: "Prepaid"
        })),

    // The fan-out must still not leak anything the sheet leaves unmapped - the guard that
    // keeps an update from overwriting live shipment data now has to hold per dossier too.
    () -> "nothing unmapped leaks on a fanned-out update" in (
        (msFanOut map ((s) -> (s pluck ((v, k) -> k as String)) every ((k) -> allowedFields contains k)))
            must equalTo([true, true])),

    // The GET returns dossiers in no particular order - this LCL capture comes back BL02
    // first - so each copy takes its address from the dossier it was built for, in the order
    // the lookup listed them.
    () -> "the fan-out follows the lookup's own order" in (
        (bookingsWith("ms/trissquid-138083510.json", "iftmin-before-iftmbf-mastersub-lcl")
            map ((s) -> { bl: s.bASFBL, id: s.id default 0 }))
            must equalTo([{ bl: "BL02", id: 1621596 }, { bl: "BL01", id: 1621576 }])),

    // A plain order is the same code path with one dossier: addressed, not upserted blindly.
    () -> "a plain booking addresses the single dossier its IFTMIN created" in (
        (bookingsWith("lcl/2800226066-iftmbf-9.json", "iftmin-before-iftmbf-lcl")
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800226066BL00", id: 1623898, action: "update" }])),

    // === the create path and the guards ====================================================
    // Nothing found means the booking arrived before its IFTMIN (step 3, POST). It stays a
    // single upsert with no address, which is what creates the BL-less dossier that
    // BasfIftmin.dwl later re-purposes.
    () -> "a booking that found nothing stays a single unaddressed upsert" in (
        (bookingsWith("lcl/2800226066-iftmbf-9.json", "dossier-not-found")
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: null, ediid: null, id: 0, action: "updateorcreate" }])),

    // A code 4 booking is an update even with nothing to address - the action comes from
    // BGM03 whenever the lookup resolved no record.
    () -> "an unaddressed code 4 booking keeps its BGM03 action" in (
        (bookingsWith("ms/trissquid-138207661.json", "dossier-not-found")
            map ((s) -> s.actionAttribute)) must equalTo(["update"])),

    () -> "a recycled dossier is never addressed" in (
        (bookingsWithLookup([ booking("9", "X") ], found([
            { customerReference: "X", bASFBL: "BL00", eDIID: "XBL00", id: 99, isInRecycleBin: true }
        ])) map ((s) -> s.id default 0)) must equalTo([0])),

    // The FCL counterpart of the plain-booking case above: this booking's order already has a
    // dossier from its IFTMIN, so the booking addresses it rather than upserting blindly.
    () -> "an FCL booking addresses the dossier its IFTMIN created" in (
        (bookingsWith("fcl/2800209301-iftmin-absch-9.json", "iftmin-before-iftmbf-fcl")
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800209301BL00", id: 1623824, action: "update" }])),

    // The reference must match exactly: a dossier belonging to a *different* order that merely
    // shares a prefix must never be addressed, or the wrong record gets updated. Driven
    // synthetically because no capture exercises it - every reference in docs/get-responses
    // matches its order exactly.
    () -> "a dossier whose reference only resembles the booking's is not addressed" in (
        (bookingsWithLookup([ booking("9", "2800209301") ], found([
            { customerReference: "2800209301X", bASFBL: "BL00", eDIID: "2800209301XBL00", id: 77 }
        ])) map ((s) -> s.id default 0)) must equalTo([0])),

    // The pre-lookup contract: with no GET at all the mapping emits exactly the one upsert
    // it always did, so it stays deployable while the GET step is being wired up.
    () -> "without a lookup a booking is still a single upsert" in (
        (bookingsOf("ms/messages.json") map ((s) -> addressOf(s)))
            must equalTo([{ bl: null, ediid: null, id: 0, action: "updateorcreate" }])),

    // A cancel is dropped before the lookup is ever consulted ("IFTMBF / Cancel": ignore
    // this file), so even a booking with two live dossiers produces no call.
    () -> "a cancelled booking produces no call even when dossiers exist" in (
        bookingsWithLookup([ booking("1", "2800231445") ],
            lookup("iftmin-before-iftmbf-mastersub-fcl")) must equalTo([]))
    ]
)
