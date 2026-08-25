/**
* BASF IFTMBF (firm booking, parsed JSON) -> Carlo / Soloplan v3 `seaHouseShipment` library.
*
* Sibling of IftminModule.dwl, aimed at the same Carlo endpoint. Where IFTMIN *creates* the
* shipment, IFTMBF *updates* it, so the mapping sheet (docs/iftmbf/IFTMBF_mapping_v1.xlsx,
* single worksheet "Update") maps only a handful of fields. Carlo finds the shipment through
* DUNSCustomer + CustomerReference (BGM0201), which the sheet flags as "(searchfield)".
* Everything the sheet leaves unmapped is deliberately NOT emitted, so the update cannot
* blank out data the IFTMIN message already put on the shipment.
*
* Input  : one parsed IFTMBF message object, i.e. an element of
*          `payload.EDI.Messages.D08A.IFTMBF`.
* Output : the body of one Carlo `seaHouseShipment` entry, authored in PascalCase; the
*          mapping entry point (src/test/dw/BasfIftmbf.dwl) renders it with `camelKeys`.
*
* Flow (docs/00-basf.md, "IFTMBF / Needed flow"): a code 1 message stops the integration
* flow, so `toCarloBookingUpdates` drops it and emits nothing at all. The GET/PUT-vs-POST
* decision the document describes is Carlo-side: `actionAttribute: "updateorcreate"` makes
* the single call an upsert, so a booking that arrives before its IFTMIN still lands.
*
* --- Why this module navigates by segment NAME, not by position key -------------------------
* The EDI parser prefixes every key with the message-structure position ("0020_BGM",
* "0460_Segment_group_10"). Those numbers are directory-specific: IFTMBF D08A renumbers
* practically every group relative to IFTMIN D99A, and two numbers even collide with a
* different meaning (`Segment_group_32` = goods-item DGS in D99A but the equipment group in
* D08A; `Segment_group_18` = the goods item in D99A but the item MEA group in D08A). Hard-coded
* keys copied from IftminModule.dwl would therefore silently select the wrong data, and would
* break again on the next directory bump. The helpers in CommonModule match on the `_<SEGMENT>`
* suffix and walk groups structurally instead, so the mapping is immune to renumbering.
*/

import * from CommonModule

// ===========================================================================
// Low-level helpers
// ===========================================================================

/** Scalar as a trimmed String ("" for null). The parser emits some codes as JSON numbers
 *  (e.g. UNB0401), so every code comparison goes through this instead of `== "20"`. */
fun str(v) = if (v == null) "" else trim(v as String)

// segs / seg1 / subGroups / groupsWith - the position-agnostic navigation this module is
// built on - live in CommonModule, which IfcsumModule shares.

// ---- transport stages (SG7: TDT + DTM + TSR + SG8/LOC) ---------------------

fun stages(doc) = groupsWith(body(doc), "TDT")
/** The stage group for TDT01 `q` (10 = pre-carriage, 20 = main carriage, 30 = on-carriage). */
fun stage(doc, q) = (stages(doc) filter ((st) -> str(seg1(st, "TDT").TDT01) == q))[0]
fun mainStage(doc) = stage(doc, "20")

/** Every LOC of a stage - both directly under it and inside its LOC sub-group (SG8). */
fun locsOf(st): Array<Any> =
    segs(st, "LOC") ++ (groupsWith(st, "LOC") map ((g) -> seg1(g, "LOC")))

/** The first LOC with qualifier `q` across all transport stages. */
fun anyLoc(doc, q) = ((stages(doc) flatMap ((st) -> locsOf(st))) filter ((l) -> str(l.LOC01) == q))[0]
/** DTM value (DTM0102) of a stage for date qualifier `q` (132 = ETA, 133 = ETD, 180 = closing). */
fun stageDtm(st, q) = ((segs(st, "DTM")) filter ((d) -> str(d.DTM0101) == q))[0].DTM0102

// ---- header parties (SG10: NAD) --------------------------------------------

/** Header-level NAD segments. Equipment parties (SG33) sit two levels deeper and are excluded. */
fun parties(doc) = groupsWith(body(doc), "NAD") map ((g) -> seg1(g, "NAD"))
fun nad(doc, q) = (parties(doc) filter ((n) -> str(n.NAD01) == q))[0]

// ---- equipment (SG32: EQD + EQN + TMD + FTX + SG33/NAD) --------------------

fun equipments(doc) = groupsWith(body(doc), "EQD")
fun firstEquipment(doc) = equipments(doc)[0]

// ===========================================================================
// Derivations
// ===========================================================================

fun pad2(v) = do {
    var t = str(v)
    ---
    if (sizeOf(t) == 1) "0" ++ t else t
}

/**
* Pull a date out of free text and normalise it to ISO `YYYY-MM-DD`.
* The sheet lists the accepted source spellings: DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY, DD MM YYYY.
* ISO is emitted (not the sheet's display notation "DD/MM/YYYY") so the value is unambiguous on
* the wire and consistent with every other date this integration sends.
*/
fun dateFromText(txt) = do {
    // (?<!\d) stops a longer number from yielding a bogus tail match ("112.04.2026" -> 12 April).
    var m = (str(txt) scan /(?<!\d)(\d{1,2})[-.\/ ](\d{1,2})[-.\/ ](\d{4})/)[0] default []
    var day = str(m[1]) as Number default 0
    var month = str(m[2]) as Number default 0
    ---
    if (sizeOf(m) < 4 or day < 1 or day > 31 or month < 1 or month > 12) null
    else str(m[3]) ++ "-" ++ pad2(m[2]) ++ "-" ++ pad2(m[1])
}

/**
* EstimatedDispatchDate = the loading date in the equipment FTX+ITR free text (first occurrence).
* Rendered as a dateTime: the contract sample carries `<EstimatedDispatchDate>2025-12-02T15:00:00`,
* so the date-only source is padded with T00:00:00 (like the sample's LatestDeliveryDate).
*/
fun dispatchDate(doc) = do {
    var texts = (equipments(doc) flatMap ((eq) ->
        (segs(eq, "FTX") filter ((f) -> str(f.FTX01) == "ITR")) map ((f) -> ftxParts(f) joinBy "")))
    var d = dateFromText(texts[0])
    ---
    if (d == null) null else d ++ "T00:00:00"
}

/** Scenario matchcode: containers booked (EQD present) -> FCL, otherwise LCL. */
fun scenario(doc) = if (isEmpty(equipments(doc))) "BASF LCL" else "BASF FCL"

/**
* HaulageType matchcode "<pre-carriage>/<on-carriage>", first occurrence only:
*   pre-carriage - TMD+..+1 (carrier's haulage) -> CAR, TMD+..+2 (merchant's haulage) -> MER
*   on-carriage  - LOC+20 (place of delivery) present -> CAR, absent -> MER
*/
fun haulageType(doc) = do {
    var tmd = seg1(firstEquipment(doc), "TMD")
    var code = str(tmd.TMD03)
    // The sheet's rule is binary, so anything that is not an explicit "1" falls back to the C219
    // description and then to MER - rather than dropping the field and leaving Carlo's value stale.
    var pre =
        if (code == "1") "CAR"
        else if (code == "2") "MER"
        else if (str(tmd.TMD0102) contains "Carrier") "CAR"
        else "MER"
    var on = if (anyLoc(doc, "20") != null) "CAR" else "MER"
    ---
    if (tmd == null) null else pre ++ "/" ++ on
}

/**
* Import action from BGM03, same table as IftminModule.dwl: 1 = delete, 4/5 = update, 9 = original.
* Emitted as the first field of the shipment (`actionAttribute`), which is how Carlo decides
* create-vs-update. The IFTMBF sample carries BGM03 = 9 -> "updateorcreate", i.e. update the
* shipment IFTMIN already created, or create it if the booking arrives first.
*/
fun shipmentAction(doc) = do {
    var fn = str(seg1(body(doc), "BGM").BGM03)
    ---
    fn match {
        case "1" -> "delete"
        case "4" -> "update"
        case "5" -> "update"
        else -> "updateorcreate"
    }
}

// ===========================================================================
// Top-level builder consumed by BasfIftmbf.dwl
// ===========================================================================

/** CustomerReference (BGM0201) - the sheet's declared search field, i.e. the shipment identity. */
fun bookingRef(doc) = seg1(body(doc), "BGM").BGM0201

/**
* One Carlo `SeaHouseShipment`, containing exactly the fields the "Update" worksheet maps:
*
*   UNB0201                          -> DUNSCustomer
*   BGM0201                          -> CustomerReference                         (searchfield)
*   LOC+10 LOC0201 / LOC0204         -> PickupLocation/PickupLocation/UnLocationCode/Matchcode
*                                       & .../Address/Location1
*   DTM+132 of TDT+20                -> Master/MainCarriageAsOcean/CustomerETA
*   DTM+180 of TDT+20                -> Master/MainCarriageAsOcean/CustomerClosing
*   NAD+CZ NAD0201                   -> Customer/Matchcode                        (with conversion)
*   FTX+ITR of the first EQD         -> EstimatedDispatchDate
*   constant                         -> ObjectOwner/OrganisationalUnitId = 5
*   EQD present?                     -> Scenario/Matchcode = BASF FCL | BASF LCL
*   TMD03 + LOC+20                   -> HaulageType/Matchcode
*
* Plus three fields the sheet does not mention but the Carlo contract needs:
*   - `actionAttribute` (from BGM03) - selects update-vs-create; without it Carlo applies its
*     default and every booking would create a duplicate shipment.
*   - `DeliveryTerms` / `ShipmentDate` - part of the contract's required top-level set
*     (DeliveryTerms, ShipmentDate, ObjectOwner, Customer, Master). Both carry exactly the values
*     IftminModule.dwl already sends for the same shipment, so the update cannot change them.
*
* Of that required set, `DeliveryTerms`, `ObjectOwner` and `Master` are unconditional, but
* `Customer` and `ShipmentDate` are emitted only when their source segment is present (NAD+CZ and
* DTM+133 of TDT+20). That is deliberate: on an update, a `Customer: { Matchcode: null }` could
* blank the customer on the existing shipment, which is worse than the 400 Carlo returns for a
* missing one. A booking without NAD+CZ is a data error and should surface as a rejected call.
* `ShipmentDate` intentionally does NOT reuse IftminModule's DTM+137 fallback - the message date would
* overwrite the real ETD that IFTMIN set.
*
* NOT emitted, on purpose:
*   - TDT+10 "60+11" (pre-carriage mode of transport): the sheet row is highlighted as open,
*     "Mode of transport - waiting Soloplan v3.07"; there is no target XPath yet. TODO once
*     Soloplan ships it.
*   - Every other segment of the message (parties other than CZ, goods items, dangerous goods,
*     containers, ports, CNT totals ...): unmapped in the sheet, and emitting them on an update
*     would risk overwriting shipment data with booking-stage values.
*/
fun toCarloBookingUpdate(doc) = do {
    var main = mainStage(doc)
    var eta = toIsoDate(stageDtm(main, "132"))
    var closing = toIsoDate(stageDtm(main, "180"))
    var etd = toIsoDate(stageDtm(main, "133"))
    var pickup = anyLoc(doc, "10")
    var cz = nad(doc, "CZ")
    var dispatch = dispatchDate(doc)
    var haulage = haulageType(doc)
    ---
    // No CustomerReference means Carlo has nothing to match on, and this endpoint upserts - so
    // rather than posting an identity-less shipment (which would create a junk record), emit
    // nothing. The caller turns null into an empty `seaHouseShipment` array.
    if (!present(bookingRef(doc))) null
    else {
        actionAttribute: shipmentAction(doc),
        (DUNSCustomer: doc.Interchange.UNB0201) if present(doc.Interchange.UNB0201),
        CustomerReference: bookingRef(doc),
        (Customer: { Matchcode: cz.NAD0201 }) if present(cz.NAD0201),
        (EstimatedDispatchDate: dispatch) if (dispatch != null),
        // Loading place of the pre-carriage: UN/LOCODE + the plain-text place name.
        // NOTE: the doubled `PickupLocation` and the `UnLocationCode` / `Address` element names are
        // taken verbatim from the sheet's XPath (cell C26). Neither appears in the v3 export sample
        // (which shows a flat PickupLocation business partner with `LocationCode` and `Addresses`),
        // but that sample is an export dump of a different customer and is already known to omit
        // import-only elements such as DUNSCustomer and CustomerETA. Confirm with Soloplan.
        (PickupLocation: {
            PickupLocation: {
                (UnLocationCode: { Matchcode: pickup.LOC0201 }) if present(pickup.LOC0201),
                (Address: { Location1: pickup.LOC0204 }) if present(pickup.LOC0204)
            }
        }) if (present(pickup.LOC0201) or present(pickup.LOC0204)),
        ObjectOwner: { OrganisationalUnitId: 5 },
        Scenario: { Matchcode: scenario(doc) },
        (HaulageType: { Matchcode: haulage }) if (haulage != null),
        // Contract-required, not sheet-mapped - same values IftminModule.dwl sends for this shipment.
        DeliveryTerms: "Prepaid",
        (ShipmentDate: etd) if (etd != null),
        // Sea main carriage: the carrier's ETA and closing date for the booked vessel.
        // `Master` itself is always present (contract-required), but an empty MainCarriageAsOcean
        // is not emitted - sending a blank node risks Carlo replacing the carriage data wholesale.
        Master: {
            (MainCarriageAsOcean: {
                (CustomerETA: eta) if (eta != null),
                (CustomerClosing: closing) if (closing != null)
            }) if (eta != null or closing != null)
        }
    }
}

// ===========================================================================
// Interchange entry point (docs/00-basf.md "IFTMBF / Needed flow", step 0)
// ===========================================================================

/** True for a cancellation (BGM03 = 1). */
fun isCancel(doc) = str(seg1(body(doc), "BGM").BGM03) == "1"

/**
* Map a whole parsed IFTMBF interchange to the Carlo `seaHouseShipment` array.
*
* Step 0 of the flow says a code 1 booking stops the integration flow, so a cancellation
* contributes nothing - unlike IFTMIN, where a cancellation is an explicit delete. The
* asymmetry is intended: the booking being withdrawn does not mean the shipment is.
*
* Bookings with no CustomerReference are dropped for the same reason as in IFTMIN - the
* endpoint upserts, and an identity-less entry would create a junk shipment.
*/
fun toCarloBookingUpdates(payload) =
    (messagesOfType(payload, "IFTMBF")
        filter ((m) -> !isCancel(m))
        map ((m) -> toCarloBookingUpdate(m)))
        filter ((s) -> s != null)
