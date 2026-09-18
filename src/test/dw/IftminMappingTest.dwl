/**
* BASF IFTMIN mapping, exercised against every IFTMIN interchange in
* docs/example-orders/inbound (39 fixtures: 25 FCL, 3 LCL, 11 master-sub/ms).
*
* The mapping is run the way the data-transformer runs it: `evalPath` executes
* src/main/dw/InboundIftmin.dwl - the whole self-contained script, output header and document
* body included - against a `payload` context and returns the parsed JSON Carlo would
* receive. Nothing is imported from the mapping, so no part of it is restated here and there
* is nothing to keep in sync.
*
* One consequence is worth knowing when reading the derivation tests at the bottom: the old
* suite called `loadType` / `houseType` / `shipmentAction` directly, and this one reaches
* those branches by feeding a synthetic *interchange* through the whole mapping and reading
* the field they produce. `masterSub` in particular is a property of the interchange (more
* than one IFTMIN message), not of a message, so it can only be exercised this way.
*
* The bulk of the suite is data-driven from example-orders/inbound/manifest.json, which
* tools/edifact_to_json.py writes when it converts the examples. Each manifest row records
* what the *message* says - its BASF BL, its BGM message-function code, its
* CustomerReference and whether it carries equipment - read straight off the parsed tree.
* The expectations below are derived from those facts independently of the mapping, so a
* wrong flow decision (FCL taken for LCL, a master-sub not split, a missing Coloadin) fails
* here rather than being restated.
*
* No code 1 (cancel) message exists anywhere in the example set, so the cancel branch is
* covered by synthetic interchanges at the end.
*/
%dw 2.0
import * from dw::test::Tests
import * from dw::test::Asserts

var MAPPING = "InboundIftmin.dwl"

var manifest = readUrl("classpath://example-orders/inbound/manifest.json", "application/json")
var iftmin = manifest filter ((e) -> e.messageType == "IFTMIN")

/**
* Run the mapping script over a whole parsed interchange and return the Carlo document.
* This is the only route the suite has into the mapping - the same call the data-transformer
* makes - so a break in the output header, the document body or any helper surfaces here.
*
* Every helper here takes the *interchange* and wraps it in the envelope the seq 3
* `dataDelivery` step hands the transformer (`originalPayload` + `payload`); `envelope` below
* is the single place that shape is built, so the suite feeds the mapping exactly what
* FrachtConnect does and nothing restates the wiring.
*/
fun document(interchange) = documentWith(interchange, true)

/**
* Run the mapping with the FCL switch explicitly set.
*
* The mapping ships with `PROCESS_FCL = false`, because BASF go-live carries LCL only. Nearly
* every example interchange is FCL, so a suite that could only ever see the shipped state
* would assert almost nothing - and the FCL behaviour is what has to keep working for the day
* the switch is flipped. `processFcl` in the mapping reads `payload.config.processFcl` and
* falls back to the constant, which is the seam this uses; nothing in the pipeline sets that
* key, so production is always the constant.
*
* So `document` - and everything built on it - describes the mapping with **FCL enabled**.
* The shipped default is covered on its own terms by `documentAsShipped`, under
* "the FCL switch" below.
*/
fun documentWith(interchange, fcl) = documentOfLookup(interchange, null, fcl)

/**
* The envelope the data-transformer is handed: the interchange on `originalPayload` (the node
* name `originalPayloadNodeName` configures on the seq 3 step of the profile) and the GET
* response on `payload`. `config` is the FCL test seam and is never present in production.
*
* `lk` is null wherever a test describes the pre-lookup fallback, which is also what a GET
* whose response the mapping cannot recognise comes down to.
*/
fun envelope(interchange, lk) = { originalPayload: interchange, payload: lk }

fun documentOfLookup(interchange, lk, fcl) =
    evalPath(MAPPING, { payload: envelope(interchange, lk) ++ { config: { processFcl: fcl } } },
             "application/json")

/** Run the mapping exactly as shipped, letting `PROCESS_FCL` in the file decide. */
fun documentAsShipped(interchange) =
    evalPath(MAPPING, { payload: envelope(interchange, null) }, "application/json")

/** An interchange built from the given synthetic messages. */
fun interchangeOf(msgs) = { EDI: { Messages: { D99A: { IFTMIN: msgs } } } }

/** The document for an interchange built from the given synthetic messages. */
fun documentOf(msgs) = document(interchangeOf(msgs))

fun load(fixture) = readUrl("classpath://example-orders/inbound/" ++ fixture, "application/json")
fun shipmentsOf(fixture) = document(load(fixture)).seaHouseShipment

// --- what the mapping produced ------------------------------------------------------------
fun actual(fixture) = shipmentsOf(fixture) map ((s) -> {
    bl: s.bASFBL,
    ref: s.customerReference,
    load: s.loadType,
    house: s.houseType,
    action: s.actionAttribute,
    // The Carlo contract's required top-level set. `customer` and `master` are objects, so
    // presence is what matters here; their contents are covered by the field tests below.
    complete: s.customerReference != null and s.deliveryTerms != null and s.shipmentDate != null
        and s.objectOwner.organisationalUnitId != null and s.customer != null and s.master != null
})

// --- what the message says it should be ----------------------------------------------------
fun expectedLoad(m) = if (m.equipment > 0) "FCL" else "LCL"
fun expectedAction(code) = code match {
    case "1" -> "delete"
    case "4" -> "update"
    case "5" -> "update"
    else -> "updateorcreate"
}
fun expected(e) = e.messages map ((m) ->
    if (m.code == "1")
        // A cancel is an identity-only recycle - `recycleShipment` emits the address plus
        // IsInRecycleBin and nothing else, so there is no load type, no house type and none
        // of the business fields `complete` checks for. Pushing order values onto a dossier
        // being withdrawn would overwrite live data. With no lookup the action is the BGM03
        // default, since there is no dossier to address.
        { bl: m.bl, ref: m.customerReference, load: null, house: null,
          action: "updateorcreate", complete: false }
    else
        { bl: m.bl,
          ref: m.customerReference,
          load: expectedLoad(m),
          // Co-load only where the flow says: a master-sub interchange whose block is LCL.
          house: if (e.masterSub and expectedLoad(m) == "LCL") "Coloadin" else "BackToBack",
          action: expectedAction(m.code),
          complete: true })

// --- synthetic messages for the branches the examples never reach ---------------------------
fun bgm(code, ref) = bgm(code, ref, "BL00")
fun bgm(code, ref, bl) = {
    Interchange: { UNB0201: "BASFAG2" },
    MessageHeader: { UNH03: bl },
    Heading: { "0020_BGM": { BGM0101: "705", BGM0201: ref, BGM03: code } }
}
fun withEquipment(msg) = msg update {
    case h at .Heading -> h ++ { "1640_Segment_group_37": [{ "1650_EQD": { EQD01: "CN", EQD0201: "ABCU1234567" } }] }
}

/** The single shipment a one-message synthetic interchange maps to. */
fun only(msg) = documentOf([ msg ]).seaHouseShipment[0]

/** The shipments a two-message (i.e. master-sub) synthetic interchange maps to. */
fun bothOf(msgA, msgB) = documentOf([ msgA, msgB ]).seaHouseShipment

// --- the "GET dossier by CustomerRef" lookup ----------------------------------------------
/**
* A captured lookup response from docs/get-responses, by file stem.
*
* These are real server responses rather than hand-written expectations, which is the whole
* point of using them: the field names and shape the mapping navigates - `customerReference`,
* `bASFBL`, `eDIID`, `id`, `isInRecycleBin` - are the ones Carlo actually returns, and the
* dossier ids asserted below are the records the integration really created.
* `docs/get-responses` is the source of truth; `src/test/resources/get-responses` is the
* classpath copy the suite reads.
*
* The mapping reads the response off the `payload` node of the envelope, so a test supplies it
* the way the seq 3 `dataDelivery` step does: beside the interchange, verbatim.
*/
fun lookup(name) = readUrl("classpath://get-responses/" ++ name ++ ".json", "application/json")

/** The shipments a fixture interchange maps to when evaluated together with a lookup. */
fun shipmentsWith(fixture, name) =
    documentOfLookup(load(fixture), lookup(name), true).seaHouseShipment

/** The shipments synthetic messages map to when evaluated with an explicit lookup value. */
fun shipmentsWithLookup(msgs, lk) =
    documentOfLookup(interchangeOf(msgs), lk, true).seaHouseShipment

/** A lookup response carrying the given dossiers. */
fun found(dossiers) = { seaHouseShipment: dossiers }

/**
* A whole envelope captured from a real FrachtConnect run, by file stem.
*
* Unlike every other helper here this one does not build the envelope: the file *is* the
* transformer's input, exactly as the seq 3 `dataDelivery` step handed it over - the parsed
* interchange on `originalPayload` and the live GET response on `payload`. That makes it the
* one fixture that can catch a wrong node name, since nothing in the suite restates it.
*
* `docs/documentation-input/inbound/mulesoft-*-get-existing-append-original.json` are the
* originals; `src/test/resources/envelopes/` is the classpath copy. Captured 2026-09-17.
*/
fun envelopeCapture(name) =
    readUrl("classpath://envelopes/" ++ name ++ ".json", "application/json")

/** Run the mapping over a captured envelope, with the FCL switch set. */
fun documentOfCapture(name, fcl) =
    evalPath(MAPPING, { payload: envelopeCapture(name) ++ { config: { processFcl: fcl } } },
             "application/json")

/**
* The address a shipment carries: which record it updates and how.
* `id` reads 0 rather than null when absent - i.e. no record was resolved, so this is a
* create - which keeps these comparisons free of nulls.
*/
fun addressOf(s) = { bl: s.bASFBL, ediid: s.eDIID, id: s.id default 0, action: s.actionAttribute }

/** The key names of an object, in order. */
fun keysOf(o) = o pluck ((v, k) -> k as String)

/**
* True when no key appears twice.
* Worth asserting because DataWeave objects tolerate duplicate keys and the JSON writer
* emits both, so a merge that produced one would not fail here - it would ship two copies of
* a field and leave Carlo reading whichever it saw last.
*/
fun hasNoDuplicateKeys(o) = sizeOf(keysOf(o)) == sizeOf(keysOf(o) distinctBy ((k) -> k))

// Evaluated once and reused. The same master-sub order (BL01 + BL02 of 2800231445) read
// against the two states it can meet: its own dossiers, already created by an earlier
// IFTMIN, and the single BL-less dossier an IFTMBF that arrived first left behind.
var msAfterIftmin = shipmentsWith("ms/2800231445-erst-9.json", "iftmin-before-iftmbf-mastersub-fcl")
var msAfterBooking = shipmentsWith("ms/2800231445-ab-4-5.json", "iftmbf-before-iftmin-mastersub-fcl")
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
        (shipmentsOf("ms/2800231445-erst-9.json") map ((s) -> s.bASFBL))
            must equalTo(["BL01", "BL02"])),

    () -> "an ordinary interchange yields exactly one shipment" in (
        sizeOf(shipmentsOf("fcl/2800209301-iftmin-erst-9.json")) must equalTo(1)),

    // The whole point of the co-load rule: same split, but the blocks carry no equipment.
    () -> "an LCL master-sub marks every block as a co-load" in (
        (shipmentsOf("ms/2800237044-iftmin-erstinfo-9.json") map ((s) -> s.houseType))
            must equalTo(["Coloadin", "Coloadin"])),

    () -> "an FCL master-sub stays back-to-back" in (
        (shipmentsOf("ms/2800231445-ab-4-5.json") map ((s) -> s.houseType))
            must equalTo(["BackToBack", "BackToBack"])),

    () -> "a single LCL shipment is not a co-load" in (
        (shipmentsOf("lcl/2800226066-iftmin-erst-9.json") map ((s) -> s.houseType))
            must equalTo(["BackToBack"])),

    // === cancel (BGM03 = 1) - no example message exists ====================================
    // docs/00-basf.md, "IFTMIN / Canceling": a cancel recycles the dossier rather than
    // deleting it - "set the property isInRecycleBin to true and upsert the record". With no
    // lookup there is nothing to enumerate, so the message maps to one identity-addressed
    // upsert.
    () -> "a cancel maps to an identity-only recycle" in (
        documentOf([ bgm("1", "2800244026") ]) must equalTo({ seaHouseShipment: [{
            actionAttribute: "updateorcreate",
            dUNSCustomer: "BASFAG2",
            bASFBL: "BL00",
            customerReference: "2800244026",
            eDIID: "2800244026BL00",
            isInRecycleBin: true
        }] })),

    // Stated separately from the value assertion above: a cancel must carry no business
    // field at all, because every one of them would overwrite the live shipment.
    () -> "a cancel carries no business fields that could overwrite the shipment" in (
        (only(bgm("1", "2800244026")) pluck ((v, k) -> k as String))
            must equalTo(["actionAttribute", "dUNSCustomer", "bASFBL",
                          "customerReference", "eDIID", "isInRecycleBin"])),

    // A master-sub cancel names an order, which is several dossiers, so it recycles each on
    // its own record - the same per-BL addressing the update path needs.
    () -> "a master-sub cancel recycles every dossier of the order" in (
        (shipmentsWithLookup([ bgm("1", "2800231445", "BL01") ],
            lookup("iftmin-before-iftmbf-mastersub-fcl")) map ((s) -> addressOf(s)))
            must equalTo([
                { bl: "BL01", ediid: "2800231445BL01", id: 1607396, action: "update" },
                { bl: "BL02", ediid: "2800231445BL02", id: 1607444, action: "update" }
            ])),

    // A lookup that ran and found nothing is not the same as no lookup: there is no dossier
    // to recycle, and an upsert would create the very record being cancelled.
    () -> "a cancel whose lookup found nothing emits no call at all" in (
        shipmentsWithLookup([ bgm("1", "2800244026") ], lookup("dossier-not-found"))
            must equalTo([])),

    () -> "a cancel skips a dossier that is already recycled" in (
        shipmentsWithLookup([ bgm("1", "X") ],
            found([{ customerReference: "X", bASFBL: "BL00", id: 1, isInRecycleBin: true }]))
            must equalTo([])),

    () -> "a create is not treated as a cancel" in (
        only(bgm("9", "2800244026")).actionAttribute must equalTo("updateorcreate")),

    () -> "an update is not treated as a cancel" in (
        only(bgm("4", "2800244026")).actionAttribute must equalTo("update")),

    () -> "a cancel without a CustomerReference is dropped - Carlo would have nothing to match" in (
        documentOf([ bgm("1", null) ]) must equalTo({ seaHouseShipment: [] })),

    // === derivation branches, reached through a synthetic interchange ======================
    () -> "LoadType is FCL when equipment is present" in (
        only(withEquipment(bgm("9", "X"))).loadType must equalTo("FCL")),
    () -> "LoadType is LCL when equipment is absent" in (
        only(bgm("9", "X")).loadType must equalTo("LCL")),

    () -> "HouseType is BackToBack for a stand-alone LCL" in (
        only(bgm("9", "X")).houseType must equalTo("BackToBack")),
    // masterSub is `more than one IFTMIN message in the interchange`, so this branch needs
    // a two-message interchange - it cannot be reached with a single message.
    () -> "HouseType is Coloadin for an LCL block of a master-sub" in (
        (bothOf(bgm("9", "X", "BL01"), bgm("9", "Y", "BL02")) map ((s) -> s.houseType))
            must equalTo(["Coloadin", "Coloadin"])),
    () -> "HouseType stays BackToBack for an FCL block of a master-sub" in (
        (bothOf(withEquipment(bgm("9", "X", "BL01")), withEquipment(bgm("9", "Y", "BL02")))
            map ((s) -> s.houseType)) must equalTo(["BackToBack", "BackToBack"])),

    () -> "BGM03 1 -> a recycle, not a business update" in (
        only(bgm("1", "X")).isInRecycleBin must equalTo(true)),
    () -> "BGM03 4 -> update" in (only(bgm("4", "X")).actionAttribute must equalTo("update")),
    () -> "BGM03 5 -> update" in (only(bgm("5", "X")).actionAttribute must equalTo("update")),
    () -> "BGM03 9 -> updateorcreate" in (only(bgm("9", "X")).actionAttribute must equalTo("updateorcreate")),

    // === wrapper shape =====================================================================
    () -> "the document is a camelCase seaHouseShipment array" in (
        (shipmentsOf("lcl/2800226066-iftmin-erst-9.json")[0] pluck ((v, k) -> k as String))[0 to 3]
            must equalTo(["actionAttribute", "preferredModeOfTransport", "dUNSCustomer", "bASFBL"])),

    () -> "an interchange with no IFTMIN message yields an empty array" in (
        document({ EDI: { Messages: {} } }) must equalTo({ seaHouseShipment: [] })),

    // === issue 1: a master-sub update must address each BL's own dossier ===================
    // Both subs of this interchange carry CustomerReference 2800231445 and differ only in
    // their BL, and the lookup returns the two dossiers an earlier IFTMIN created for them.
    // On CustomerReference alone BL02 resolves onto BL01's record - the reported "only
    // updating the first shipment".
    () -> "a master-sub update addresses each BL's own dossier" in (
        (msAfterIftmin map ((s) -> addressOf(s))) must equalTo([
            { bl: "BL01", ediid: "2800231445BL01", id: 1607396, action: "update" },
            { bl: "BL02", ediid: "2800231445BL02", id: 1607444, action: "update" }
        ])),

    // Stated on its own because it is the defect itself: one id for two subs meant the
    // second PUT overwrote the first.
    () -> "the two subs of a master-sub never share a dossier id" in (
        sizeOf((msAfterIftmin map ((s) -> s.id)) distinctBy ((i) -> i)) must equalTo(2)),

    // The GET returns dossiers in no particular order - this LCL capture comes back BL02
    // first - so the match has to be by BL value. Indexing the result would swap the two.
    () -> "a master-sub matches by BL value, not by the order the lookup returned" in (
        (shipmentsWith("ms/2800237044-iftmin-erstinfo-9.json", "iftmin-before-iftmbf-mastersub-lcl")
            map ((s) -> { bl: s.bASFBL, id: s.id default 0 }))
            must equalTo([{ bl: "BL01", id: 1621576 }, { bl: "BL02", id: 1621596 }])),

    // EDIID is what makes the composite identity explicit on the wire, and it is the field
    // the real records carry ("2800231445BL01"). A plain order is CustomerReference + BL00.
    () -> "EDIID is CustomerReference ++ BASFBL" in (
        (shipmentsOf("fcl/2800209301-iftmin-erst-9.json") map ((s) -> s.eDIID))
            must equalTo(["2800209301BL00"])),

    // === issue 3: an IFTMBF arrived before the IFTMIN ======================================
    // The lookup holds one BL-less dossier - only a booking can have created that, since
    // IFTMBF carries no BL. The first sub re-purposes it ("Idealy we would repurpose the
    // existing dossier"), so no record is orphaned and none has to be recycled; every later
    // sub is a new record.
    () -> "the first sub re-purposes the booking's dossier and the rest are created" in (
        (msAfterBooking map ((s) -> addressOf(s))) must equalTo([
            { bl: "BL01", ediid: "2800231445BL01", id: 1621690, action: "update" },
            { bl: "BL02", ediid: "2800231445BL02", id: 0, action: "update" }
        ])),

    // The second half of proposed solution 3. Without this the booking's data survives only
    // on the re-purposed dossier and BL02 is created without it.
    () -> "every sub carries the booking's cached IFTMBF values" in (
        (msAfterBooking map ((s) -> {
            dispatch: s.estimatedDispatchDate,
            eta: s.master.mainCarriageAsOcean.customerETA,
            closing: s.master.mainCarriageAsOcean.customerClosing,
            pickup: s.pickupLocation.pickupLocation.unLocationCode.matchcode
        })) must equalTo([
            { dispatch: "2026-07-06T00:00:00", eta: "2026-08-04", closing: "2026-07-08", pickup: "DEDUS" },
            { dispatch: "2026-07-06T00:00:00", eta: "2026-08-04", closing: "2026-07-08", pickup: "DEDUS" }
        ])),

    // `mergeUnder`, not `++`: the cached fragment and the message both write inside
    // master/mainCarriageAsOcean - the booking contributes the carrier's ETA, the message the
    // ports and ETD. Replacing the node either way would drop half the carriage.
    () -> "cached booking values merge into the carriage node rather than replacing it" in (
        { fromBooking: msAfterBooking[0].master.mainCarriageAsOcean.customerETA,
          fromMessage: msAfterBooking[0].master.mainCarriageAsOcean.customerPOL.matchcode }
            must equalTo({ fromBooking: "2026-08-04", fromMessage: "BEANR" })),

    // Two structural properties of the merge, top level and inside the nodes it reaches into.
    () -> "merging cached values never duplicates a key" in (
        (msAfterBooking map ((s) ->
            hasNoDuplicateKeys(s)
                and hasNoDuplicateKeys(s.master)
                and hasNoDuplicateKeys(s.master.mainCarriageAsOcean)
                and hasNoDuplicateKeys(s.pickupLocation)))
            must equalTo([true, true])),

    // The cache adds and never removes: every field the message mapped on its own has to
    // survive the merge untouched, on the re-purposed sub and the newly created one alike.
    () -> "merging cached values keeps every field the message mapped" in (
        (shipmentsOf("ms/2800231445-ab-4-5.json") map ((plain, i) ->
            keysOf(plain) filter ((k) -> !(keysOf(msAfterBooking[i]) contains k))))
            must equalTo([[], []])),

    // The message always wins where both sides populate a field, so the cache can only fill
    // gaps and can never push booking-stage values over what the order actually says.
    () -> "the message's own value wins over a cached one" in (
        (msAfterBooking map ((s) -> { load: s.loadType, house: s.houseType, terms: s.deliveryTerms }))
            must equalTo([
                { load: "FCL", house: "BackToBack", terms: "Prepaid" },
                { load: "FCL", house: "BackToBack", terms: "Prepaid" }
            ])),

    // A plain (non-master-sub) order takes the same route: one booking dossier, one IFTMIN,
    // so the single shipment re-purposes it instead of creating a second record for the
    // order. This is the "IFTMBF comes first / Fcl - Lcl" scenario.
    () -> "a plain FCL re-purposes the booking's dossier" in (
        (shipmentsWith("fcl/2800209301-iftmin-erst-9.json", "iftmbf-before-iftmin-fcl")
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800209301BL00", id: 1621631, action: "update" }])),

    // The ordinary case, and the other capture of the same order: an instruction re-sent after
    // an earlier IFTMIN already created the dossier addresses that dossier by BL, not the
    // BL-less one of the booking path above.
    () -> "a re-sent FCL addresses the dossier its own earlier run created" in (
        (shipmentsWith("fcl/2800209301-iftmin-erst-9.json", "iftmin-before-iftmbf-fcl")
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800209301BL00", id: 1623824, action: "update" }])),

    // The LCL equivalent. Note what is NOT inherited: this booking dossier really does carry
    // `estimatedDispatchDate: null`, because an LCL booking has no EQD and so no equipment
    // FTX+ITR to read a loading date from - the gap InboundIftmbf.dwl documents, confirmed here
    // against the real record. The cache only carries fields that exist; it invents nothing.
    () -> "a plain LCL re-purposes the booking's dossier and inherits the values it has" in (
        (shipmentsWith("lcl/2800226066-iftmin-erst-9.json", "iftmbf-before-iftmin-lcl")
            map ((s) -> {
                id: s.id default 0,
                pickup: s.pickupLocation.pickupLocation.unLocationCode.matchcode,
                eta: s.master.mainCarriageAsOcean.customerETA,
                closing: s.master.mainCarriageAsOcean.customerClosing,
                dispatch: s.estimatedDispatchDate
            }))
            must equalTo([{ id: 1621666, pickup: "DELUH", eta: "2026-07-15",
                            closing: "2026-06-08", dispatch: null }])),

    // === what the lookup must NOT do =======================================================
    // The create path: nothing found, so nothing is addressed and the call stays an upsert.
    () -> "a lookup that found nothing leaves the shipment a create" in (
        (shipmentsWith("fcl/2800209301-iftmin-erst-9.json", "dossier-not-found")
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800209301BL00", id: 0, action: "updateorcreate" }])),

    // Recycled dossiers stay out of every lookup, or a cancelled order would be resurrected
    // by the next message that mentions it.
    () -> "a recycled dossier is never addressed" in (
        (shipmentsWithLookup([ bgm("9", "X") ], found([
            { customerReference: "X", bASFBL: "BL00", eDIID: "XBL00", id: 99, isInRecycleBin: true }
        ])) map ((s) -> s.id default 0)) must equalTo([0])),

    // The reference has to match exactly: a dossier belonging to a *different* order that
    // merely shares a prefix must never be addressed, or the wrong record gets updated.
    // Driven synthetically because no capture exercises it - every reference in
    // docs/get-responses matches its order exactly.
    () -> "a dossier whose reference only resembles the message's is not addressed" in (
        (shipmentsWithLookup([ bgm("9", "2800209301") ], found([
            { customerReference: "2800209301X", bASFBL: "BL00", eDIID: "2800209301XBL00", id: 77 }
        ])) map ((s) -> s.id default 0)) must equalTo([0])),

    // The BL has to match too, and for the same reason - a dossier of the right order but the
    // wrong BL is still the wrong record. This is issue 1 stated as a guard.
    () -> "a dossier of the right order but the wrong BL is not addressed" in (
        (shipmentsWithLookup([ bgm("9", "X", "BL01") ], found([
            { customerReference: "X", bASFBL: "BL02", eDIID: "XBL02", id: 78 }
        ])) map ((s) -> s.id default 0)) must equalTo([0])),

    // Two BL-less dossiers for one order is a state the flow has no rule for; creating fresh
    // records is safer than picking one of them arbitrarily.
    () -> "an ambiguous pair of BL-less dossiers is left alone" in (
        (shipmentsWithLookup([ bgm("9", "X") ], found([
            { customerReference: "X", id: 1 }, { customerReference: "X", id: 2 }
        ])) map ((s) -> s.id default 0)) must equalTo([0])),

    // The pre-lookup contract: with no GET at all the mapping behaves exactly as before -
    // no dossier is addressed and BGM03 alone decides the action. This is what lets the
    // mapping deploy before the GET step is wired up.
    () -> "without a lookup nothing is addressed and the action comes from BGM03" in (
        (shipmentsOf("ms/2800231445-ab-4-5.json") map ((s) ->
            { id: s.id default 0, action: s.actionAttribute }))
            must equalTo([{ id: 0, action: "update" }, { id: 0, action: "update" }])),

    () -> "without a lookup no cached booking values are invented" in (
        (shipmentsOf("ms/2800231445-ab-4-5.json") map ((s) -> s.estimatedDispatchDate))
            must equalTo([null, null])),

    // === the pipeline envelope =============================================================
    // How the two halves reach the mapping, asserted on the node names themselves rather than
    // through `envelope`, because those names are configuration: `originalPayload` is what
    // `originalPayloadNodeName` is set to on the seq 3 step of the profile, and `payload` is
    // where that step puts the GET response. Change either on the step and this fails.
    () -> "the interchange is read off `originalPayload` and the lookup off `payload`" in (
        (evalPath(MAPPING, { payload: {
            originalPayload: interchangeOf([ bgm("9", "X", "BL01") ]),
            payload: found([{ customerReference: "X", bASFBL: "BL01", eDIID: "XBL01", id: 4711 }])
        } }, "application/json").seaHouseShipment map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL01", ediid: "XBL01", id: 4711, action: "update" }])),

    // The shape this mapping used to expect - interchange at the root, response on `lookup` -
    // is one FrachtConnect never produces. Pinned as "maps to nothing" rather than left
    // undefined: a half-working fallback is what hid the wiring error before, since a payload
    // with no dossiers in it looks exactly like an order that has none.
    () -> "the old extend-the-payload shape yields no shipment at all" in (
        evalPath(MAPPING, { payload: interchangeOf([ bgm("9", "X") ]) ++ { lookup: found([]) } },
                 "application/json")
            must equalTo({ seaHouseShipment: [] })),

    // A GET that failed, or returned something other than a seaHouseShipment object, is the
    // no-lookup case and not the found-nothing case. The difference only shows on a cancel:
    // found-nothing emits no call, this emits the identity-addressed recycle.
    () -> "a GET body carrying no seaHouseShipment is treated as no lookup at all" in (
        (shipmentsWithLookup([ bgm("1", "2800244026") ], { error: "Internal Server Error" })
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800244026BL00", id: 0,
                            action: "updateorcreate" }])),

    // === a real captured envelope ==========================================================
    // The three tests above build the envelope; these run the mapping over one FrachtConnect
    // actually produced - order 2800209301_RV1, whose GET found the BL00 dossier an earlier
    // run created. Nothing here is hand-written: the addressing asserted is a real CarLo
    // record id, and the business content is what the real interchange carries.
    () -> "a captured envelope addresses the dossier its own GET returned" in (
        (documentOfCapture("iftmin-get-existing-append-original", true).seaHouseShipment
            map ((s) -> addressOf(s)))
            must equalTo([{ bl: "BL00", ediid: "2800209301_RV1BL00", id: 1564415,
                            action: "update" }])),

    // Both halves of the envelope, in one assertion: the id can only come from `payload` and
    // the vessel, ports and containers only from `originalPayload`. A mapping reading the
    // wrong node loses one half and this fails.
    () -> "a captured envelope's business content comes off originalPayload" in (
        (documentOfCapture("iftmin-get-existing-append-original", true).seaHouseShipment
            map ((s) -> {
                ref: s.customerReference,
                load: s.loadType,
                house: s.houseType,
                vessel: s.master.mainCarriageAsOcean.customerVessel.vesselName,
                pol: s.master.mainCarriageAsOcean.customerPOL.matchcode,
                pod: s.master.mainCarriageAsOcean.customerPOD.matchcode,
                etd: s.master.mainCarriageAsOcean.customerETD,
                containers: sizeOf(s.container default []),
                cargo: sizeOf(s.cargo default [])
            }))
            must equalTo([{ ref: "2800209301_RV1", load: "FCL", house: "BackToBack",
                            vessel: "COSCO HOPE", pol: "BEANR", pod: "USNYC",
                            etd: "2026-04-20", containers: 3, cargo: 5 }])),

    // The capture is an FCL order, so as shipped it is the switch that decides - which is what
    // production does with this very message today.
    () -> "as shipped, the captured FCL envelope emits nothing" in (
        documentOfCapture("iftmin-get-existing-append-original", false)
            must equalTo({ seaHouseShipment: [] })),

    // === the FCL switch ===================================================================
    // `PROCESS_FCL` in the mapping. LCL is unconditional; FCL is switchable because go-live
    // carries LCL only. These run the file exactly as shipped, so they also assert which way
    // the committed constant is set - flip it and these four fail, which is intended: the
    // switch is a deployment decision and should not move unnoticed.

    () -> "as shipped, an FCL interchange produces no call at all" in (
        sizeOf(documentAsShipped(load("fcl/2800209301-iftmin-erst-9.json")).seaHouseShipment)
            must equalTo(0)),

    () -> "as shipped, an LCL interchange is mapped as usual" in (
        (documentAsShipped(load("lcl/2800226066-iftmin-erst-9.json")).seaHouseShipment
            map ((s) -> s.loadType)) must equalTo(["LCL"])),

    // A master-sub is always uniformly FCL or uniformly LCL, so the per-message filter takes
    // the whole interchange or none of it - never half an order.
    () -> "as shipped, an FCL master-sub is dropped whole and an LCL one is kept whole" in (
        { fcl: sizeOf(documentAsShipped(load("ms/2800231445-erst-9.json")).seaHouseShipment),
          lcl: sizeOf(documentAsShipped(load("ms/2800237044-iftmin-erstinfo-9.json")).seaHouseShipment) }
            must equalTo({ fcl: 0, lcl: 2 })),

    // Cancels are gated with everything else: a load type the integration never created is
    // one it must not address either.
    () -> "the switch gates FCL cancels too, and never LCL ones" in (
        { fcl: sizeOf(documentAsShipped(
                   { EDI: { Messages: { D99A: { IFTMIN: [ withEquipment(bgm("1", "X")) ] } } } }
               ).seaHouseShipment),
          lcl: sizeOf(documentAsShipped(
                   { EDI: { Messages: { D99A: { IFTMIN: [ bgm("1", "X") ] } } } }
               ).seaHouseShipment) }
            must equalTo({ fcl: 0, lcl: 1 })),

    () -> "with the switch on, FCL is processed again" in (
        (documentWith(load("fcl/2800209301-iftmin-erst-9.json"), true).seaHouseShipment
            map ((s) -> s.loadType)) must equalTo(["FCL"])),

    // === spec v1.1 ========================================================================

    // Sections 4-7. These are the BASF customer UDFs, not Carlo's standard vessel and port
    // fields - a real record this integration created carries `vessel: {null, null}` beside a
    // populated `customerVessel` (docs/get-responses). The standard fields stay unset.
    () -> "the customer UDFs carry vessel, voyage, POL, POD and place of delivery" in (
        do {
            var mc = shipmentsOf("fcl/2800209301-iftmin-erst-9.json")[0].master.mainCarriageAsOcean
            ---
            { lloyds: mc.customerVessel.vesselNumber, vessel: mc.customerVessel.vesselName,
              voyage: mc.customerVoyage, pol: mc.customerPOL.matchcode, pod: mc.customerPOD.matchcode,
              delivery: mc.customerPlaceofDelivery.matchcode }
                must equalTo({ lloyds: "9472165", vessel: "COSCO HOPE", voyage: "Ocean Vessel",
                               pol: "BEANR", pod: "USNYC", delivery: "USCMH" })
        }),

    () -> "the standard vessel and port fields are left unset" in (
        do {
            var mc = shipmentsOf("fcl/2800209301-iftmin-erst-9.json")[0].master.mainCarriageAsOcean
            ---
            [ mc.vessel, mc.voyageNumber, mc.portOfLoading, mc.portOfDischarge ]
                must equalTo([null, null, null, null])
        }),

    // The v1 sheet gated vessel and voyage on "Only when Erstinfo 9", which silently dropped
    // them from every Abschlussinfo - exactly the message a corrected vessel arrives on.
    () -> "vessel and voyage are mapped on a code 4 update, not only on a code 9" in (
        do {
            var mc = shipmentsOf("fcl/2800209301-iftmin-erst-4-v2.json")[0].master.mainCarriageAsOcean
            ---
            { code: shipmentsOf("fcl/2800209301-iftmin-erst-4-v2.json")[0].actionAttribute,
              vessel: mc.customerVessel.vesselName, voyage: mc.customerVoyage }
                must equalTo({ code: "update", vessel: "COSCO HOPE", voyage: "Ocean Vessel" })
        }),

    // Section 8. RFF+BN occurs twice per message - header SG1 and again on the main carriage
    // stage - with the same value. Only the first may be mapped, and only one entry created.
    () -> "the booking number is one external reference of type 9, not two" in (
        (shipmentsOf("ms/2800231445-ab-4-5.json") map ((s) -> s.master.externalReferences))
            must equalTo([
                [{ referenceType: 9, value: "272215347" }],
                [{ referenceType: 9, value: "272215347" }]
            ])),

    // ...and a message that carries none grows no entry.
    () -> "no booking number means no external reference" in (
        (shipmentsOf("ms/2800231445-erst-9.json") map ((s) -> s.master.externalReferences))
            must equalTo([null, null])),

    // Section 9. BASF carries RFF+LC on the goods item, not the header.
    () -> "the letter of credit number is read off the goods item" in (
        (shipmentsOf("lcl/2800226066-iftmin-erst-9.json") map ((s) -> s.lCNumber))
            must equalTo(["LCS/2/76/2804"])),

    // Section 12/13. Both are per container in the real messages: the three containers of
    // this interchange carry two different VGM values, so a broadcast would be wrong.
    () -> "VGM is numeric and per container, and the signature rides with it" in (
        (shipmentsOf("fcl/2800209301-iftmin-absch-9.json")[0].container
            map ((c) -> { vgm: c.verifiedGrossMass, sig: c.vgmVerificationSignature }))
            must equalTo([
                { vgm: 24220.0, sig: "MR UNGER JOCHEN, HEAD OF WH" },
                { vgm: 24220.0, sig: "MR UNGER JOCHEN, HEAD OF WH" },
                { vgm: 22273.0, sig: "MR UNGER JOCHEN, HEAD OF WH" }
            ])),

    // A message that carries no VGM must not grow the fields - the interchange below is the
    // same order without the Abschlussinfo measurements.
    () -> "a message with no VGM leaves the container fields unset" in (
        (shipmentsOf("fcl/2800209301-iftmin-erst-9.json")[0].container
            map ((c) -> c.verifiedGrossMass)) must equalTo([null, null, null])),

    // Section 11. The DG package fields are additional - the Cargo ones must survive intact.
    () -> "DG quantity and packaging are added without disturbing the cargo fields" in (
        (shipmentsOf("fcl/2800209301-iftmin-erst-9.json")[0].cargo
            map ((c) -> { packages: c.totalNumberOfPackages, packaging: c.packaging.matchcode,
                          dgQty: c.dangerousGoods[0].quantity,
                          dgPkg: c.dangerousGoods[0].packaging.matchcode }))
            must equalTo([
                { packages: 35,  packaging: "1H1", dgQty: 35,  dgPkg: "1H1" },
                { packages: 50,  packaging: "1H1", dgQty: 50,  dgPkg: "1H1" },
                { packages: 50,  packaging: "1H1", dgQty: 50,  dgPkg: "1H1" },
                { packages: 150, packaging: "1H1", dgQty: 150, dgPkg: "1H1" },
                { packages: 150, packaging: "1H1", dgQty: 150, dgPkg: "1H1" }
            ])),

    // Spec rule 6 of section 11: never copy a value from one GID goods item to another's DG
    // data. The five lines above carry 35 / 50 / 50 / 150 / 150 packages, so a mapping that
    // read the wrong item - or hoisted the first - fails this rather than passing by accident.
    () -> "each DG line takes its quantity from its own goods item" in (
        (shipmentsOf("fcl/2800209301-iftmin-erst-9.json")[0].cargo
            map ((c) -> c.dangerousGoods[0].quantity == c.totalNumberOfPackages))
            must equalTo([true, true, true, true, true])),

    // Section 15. BASF reuses NAD02 for an internal partner number (qualifier 160) and a tax
    // registration (167). Only 167 is a TAX ID.
    () -> "a TAX ID is taken only from a 167-qualified identifier" in (
        (shipmentsOf("fcl/2013386790-iftmin-erstinfo-9.json")
            map ((s) -> { cons: s.consigneeTAXID, n1: s.notify1TAXID }))
            must equalTo([{ cons: "80005230-7", n1: "80005230-7" }])),

    () -> "a 160-qualified identifier is not a TAX ID" in (
        (shipmentsOf("lcl/2800226066-iftmin-erst-9.json")
            map ((s) -> { n1: s.notify1TAXID, n2: s.notify2TAXID }))
            must equalTo([{ n1: null, n2: null }])),

    // Section 14. NAD+N2 sits in the same goods-item party group as NAD+N1.
    () -> "Notify2 is mapped with the Notify1 logic" in (
        (shipmentsOf("lcl/2800226066-iftmin-erst-9.json") map ((s) -> s.notify2.name1))
            must equalTo(["HABIB METROPOLITAN BANK LTD,"])),

    // Section 16. The field is obsolete on BASF's side and real Carlo records carry null.
    () -> "Scenario is no longer emitted" in (
        (shipmentsOf("fcl/2800209301-iftmin-erst-9.json") map ((s) -> s.scenario))
            must equalTo([null])),

    // === PCI / HandlingInfo (issue of 11-09-2026) =========================================
    // PCI02 is composite C210, up to ten 35-character components used as display lines. The
    // earlier mapping emitted only the first two and dropped destination port, batch number,
    // dates, weights and country of manufacture.
    // Asserted line by line rather than as one literal: several components are Spanish and a
    // non-ASCII literal in this file does not survive the test reader's decoding, which would
    // make the test fail on its own encoding rather than on the mapping.
    () -> "HandlingInfo carries every PCI component, not just the first two" in (
        do {
            var lines = (shipmentsOf("fcl/2013386790-iftmin-erstinfo-9.json")[0]
                            .cargo[0].handlingInfo splitBy "\r\n")
            ---
            { count: sizeOf(lines), first: lines[0], second: lines[1],
              seventh: lines[6], eighth: lines[7] }
                must equalTo({ count: 9, first: "BASF", second: "3020994027 / 000010",
                               // 7 and 8 are one sentence the sender split across two
                               // 35-character components, the second padded to line up.
                               seventh: "Neto:        160,000  Kg  Bruto:",
                               eighth: "     181,800  Kg" })
        }),

    () -> "a two-component PCI still yields both lines" in (
        (shipmentsOf("fcl/2800209301-iftmin-erst-9.json")[0].cargo[0].handlingInfo)
            must equalTo("BASF\r\n3020963670 / 000010")),

    // === spec v1.1, against BASF's own reference messages ==================================
    // Section 18 of the specification names three messages as the validation set, and all
    // three are now in the example orders. These assert the v1.1 fields against those rather
    // than against the older examples, and every value below also appears verbatim in the
    // specification - so a drift here is a drift from what BASF themselves documented.

    // ML 2800244245, the Egypt shipment. The only IFTMIN in the whole example set carrying an
    // RFF+ABT, and it settles where BASF puts it: on the goods item (SG22), beside RFF+LC,
    // not in the header.
    () -> "ACID comes off the structured RFF+ABT of the Egypt message" in (
        (shipmentsOf("fcl/2800244245-erstinfo-9.json") map ((s) -> s.aCIDNumber))
            must equalTo(["2101495821022010016"])),

    () -> "every message of the ACID order carries it, on both message codes" in (
        ([ "fcl/2800244245-erstinfo-9.json", "fcl/2800244245-erstinfo-4-1.json",
           "fcl/2800244245-erstinfo-4-2.json", "fcl/2800244245-abschlussinfo-9.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) -> s.aCIDNumber)))
            must equalTo([ "2101495821022010016", "2101495821022010016",
                           "2101495821022010016", "2101495821022010016" ])),

    // ML 2800245098, the Abschlussinfo the spec cites for repeated RFF+BN, VGM and NAD+AM.
    () -> "the booking number of the repeated-RFF+BN message is mapped once" in (
        (shipmentsOf("fcl/2800245098-abschlussinfo-9.json") map ((s) -> s.master.externalReferences))
            must equalTo([[{ referenceType: 9, value: "57681221" }]])),

    // The spec's own VGM example is `MEA+WT+AAB:::VGM+KGM:20897.040` - numeric here, not the
    // string the segment carries, so the trailing zero is gone.
    () -> "VGM and its signature come off the Abschlussinfo" in (
        (shipmentsOf("fcl/2800245098-abschlussinfo-9.json")[0].container
            map ((c) -> { vgm: c.verifiedGrossMass, sig: c.vgmVerificationSignature }))
            must equalTo([{ vgm: 20897.04, sig: "MR WILLMANN, JAN" }])),

    // ML 2800250325, the second-notifier example. NAD+N2 sits in the same goods-item party
    // group as NAD+N1, so Notify2 is the Notify1 logic pointed at the Notify2 fields.
    () -> "Notify2 and its TAX ID come off the second-notifier message" in (
        (shipmentsOf("fcl/2800250325-iftmin.json") map ((s) ->
            { name1: s.notify2.name1, tax: s.notify2TAXID,
              phone: s.phoneNumberNotify2, email: s.emailNotify2 }))
            must equalTo([{ name1: "BASF MEXICANA", tax: "BME8109104S6",
                            phone: "55-57233082", email: "Basf-coatings-MX@basf.com" }])),

    // ML 2800245092, the Brazil order the tax-ID example folder is named after. A whole order
    // rather than a single message - Erstinfo, IFTMBF booking, Abschlussinfo - so the two
    // instructions are read here as the pair they arrive as, and the booking between them is
    // asserted under the same heading in IftmbfMappingTest.dwl.

    // Section 15 again, but on messages where the consignee and the notify party carry
    // *different* identifiers - a 14-digit Brazilian CNPJ each. 2013386790 gives both parties
    // the same tax ID, so a mapping that broadcast one party's identifier over the others
    // would pass there and fail here. Shipper and Notify2/3 have no 167 identifier in this
    // order and must stay unset rather than inherit one.
    () -> "consignee and notify carry their own 167-qualified CNPJ, on both messages" in (
        ([ "fcl/2800245092-erstinfo-create.json", "fcl/2800245092-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) ->
                { cons: s.consigneeTAXID, n1: s.notify1TAXID,
                  ship: s.shipperTAXID, n2: s.notify2TAXID, n3: s.notify3TAXID })))
            must equalTo([
                { cons: "48539407000207", n1: "58156084000137",
                  ship: null, n2: null, n3: null },
                { cons: "48539407000207", n1: "58156084000137",
                  ship: null, n2: null, n3: null }
            ])),

    // The consignee the tax ID belongs to, off the goods-item NAD+DO. `location2` (the LOC+47
    // region) is deliberately not asserted: it reads "Sao Paulo" with a non-ASCII a, and a
    // non-ASCII literal in this file does not survive the test reader's decoding - the same
    // reason the PCI test above is written line by line.
    () -> "the consignee block comes off the goods-item NAD+DO" in (
        (shipmentsOf("fcl/2800245092-erstinfo-create.json") map ((s) ->
            { name1: s.consignee.name1, name2: s.consignee.name2,
              street: s.consignee.address.street, city: s.consignee.address.location1,
              zip: s.consignee.address.zipCode,
              country: s.consignee.address.country.countryID,
              phone: s.consignee.phoneNumber, email: s.consignee.emailAddress }))
            must equalTo([{ name1: "BASF SA", name2: "ENGENHEIRO NEIVA",
                            street: "AVENIDA BRASIL 791", city: "GUARATINGUETA",
                            zip: "12521140", country: "BR", phone: "1231281200",
                            email: "Certificados-BASF-GTA@basf.com" }])),

    // Section 4 and general rule 6. CustomerVoyage is TDT02 verbatim and the standard CarLo
    // Vessel and VoyageNumber stay unset. BASF sends its literal placeholder "Ocean Vessel"
    // there until the carrier has named a voyage and the real code from then on (the same
    // progression as 2800245098 and 2800231445), so a mapping that treated TDT02 as a code -
    // validated it, or dropped what did not look like one - would lose the Erstinfo's value
    // on every order. Both take the same route, and the vessel beside it does not change.
    () -> "CustomerVoyage is TDT02 verbatim - placeholder, then the real voyage code" in (
        ([ "fcl/2800245092-erstinfo-create.json", "fcl/2800245092-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) ->
                { voyage: s.master.mainCarriageAsOcean.customerVoyage,
                  vessel: s.master.mainCarriageAsOcean.customerVessel.vesselName,
                  lloyds: s.master.mainCarriageAsOcean.customerVessel.vesselNumber,
                  stdVessel: s.vessel, stdVoyage: s.voyageNumber })))
            must equalTo([
                { voyage: "Ocean Vessel", vessel: "MAERSK LA PAZ", lloyds: "9526899",
                  stdVessel: null, stdVoyage: null },
                { voyage: "635S", vessel: "MAERSK LA PAZ", lloyds: "9526899",
                  stdVessel: null, stdVoyage: null }
            ])),

    // Sections 12/13 read across one order instead of one message. Both instructions carry
    // MEA+WT+AAB; only the Abschlussinfo's is labelled ":::VGM", and only that one is a
    // verified gross mass - the Erstinfo's 29704 is the planned gross weight and reporting it
    // as a VGM would be a SOLAS declaration BASF never made. The container number is replaced
    // at the same time (BASF names an internal number until the carrier assigns a real one)
    // while the EDIID stays put, which is what lets the update land on the container the
    // Erstinfo created rather than adding a second one.
    () -> "the Abschlussinfo brings the real container, its VGM and its signatory" in (
        ([ "fcl/2800245092-erstinfo-create.json", "fcl/2800245092-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f)[0].container map ((c) ->
                { no: c.containerNumber, ediid: c.eDIID, vgm: c.verifiedGrossMass,
                  sig: c.vgmVerificationSignature })))
            must equalTo([
                { no: "1307794927", ediid: "5002376123/000010", vgm: null, sig: null },
                { no: "MNBU4628658", ediid: "5002376123/000010", vgm: 29650.0,
                  sig: "NICHOLAS GIBBS" }
            ])),

    // RFF+BN occurs twice in the Abschlussinfo (header and main stage), as in 2800245098, and
    // is mapped once. The Erstinfo has none at all - the carrier's booking number does not
    // exist yet - so the field is absent there rather than an empty list.
    () -> "the booking number arrives with the Abschlussinfo and is mapped once" in (
        ([ "fcl/2800245092-erstinfo-create.json", "fcl/2800245092-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) -> s.master.externalReferences)))
            must equalTo([null, [{ referenceType: 9, value: "275861976" }]])),

    // ML 2800248632, the order the "in your name as agent" example folder is named after.
    // Another whole order - Erstinfo, IFTMBF booking, Abschlussinfo - and the second one in
    // the set, so where it repeats 2800245092 it is a second witness rather than a restatement
    // of the same message. Its booking is asserted under the same heading in
    // IftmbfMappingTest.dwl.

    // The point of the folder. BASF's NAD+OS on this order is not a party at all - it is an
    // instruction to the forwarder, "in your name as agent of BASF", with the principal's name
    // and street run together in the second component of the same composite. The mapping
    // carries all of it through verbatim, which is what keeps the shipper block a faithful
    // record of what BASF sent. Tris does not: docs/example-orders/inbound/fcl/
    // in-your-name-as-agent/readme.txt shows it rendering "POLYTRA N.V. as agent of BASF",
    // substituting the forwarder's own name for "in your name". Both halves reach Carlo - the
    // forwarder is mapped separately off NAD+FW, asserted here beside the shipper - so the
    // substitution is composable downstream, but nothing in the mapping performs it today.
    // See docs/00-basf.md; this test pins what the mapping does, not what it should do.
    () -> "the agent shipper line is carried verbatim, on both messages" in (
        ([ "fcl/2800248632-erstinfo-create.json", "fcl/2800248632-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) ->
                { name1: s.shipper.name1, street: s.shipper.address.street,
                  city: s.shipper.address.location1, zip: s.shipper.address.zipCode,
                  country: s.shipper.address.country.countryID, tax: s.shipperTAXID,
                  forwarder: s.forwarderName })))
            must equalTo([
                { name1: "in your name as agent of BASF",
                  street: "Polyurethanes GmbH Elastogranstr.60", city: "49448 Lemfoerde",
                  zip: null, country: "DE", tax: null, forwarder: "POLYTRA N.V." },
                { name1: "in your name as agent of BASF",
                  street: "Polyurethanes GmbH Elastogranstr.60", city: "49448 Lemfoerde",
                  zip: null, country: "DE", tax: null, forwarder: "POLYTRA N.V." }
            ])),

    // Section 4 again, and the case 2800245092 could not show. There the placeholder "Ocean
    // Vessel" is replaced by the real voyage code on the Abschlussinfo, which reads like a
    // progression every order completes. This order never completes it: BASF sends the literal
    // placeholder on the Erstinfo and sends it again on the Abschlussinfo, three weeks later,
    // with the sailing re-dated (ETD 2026-09-17 -> 2026-10-04) and the vessel unchanged. So a
    // mapping that treated a completion message as the point the voyage code becomes known -
    // requiring one, or falling back to something else when TDT02 still looks like a
    // placeholder - would be wrong on this order. TDT02 is copied, whatever it says, and the
    // standard CarLo Vessel and VoyageNumber stay unset either way.
    () -> "the voyage placeholder can survive to the completion message" in (
        ([ "fcl/2800248632-erstinfo-create.json", "fcl/2800248632-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) ->
                { voyage: s.master.mainCarriageAsOcean.customerVoyage,
                  vessel: s.master.mainCarriageAsOcean.customerVessel.vesselName,
                  lloyds: s.master.mainCarriageAsOcean.customerVessel.vesselNumber,
                  etd: s.master.mainCarriageAsOcean.customerETD,
                  stdVessel: s.vessel, stdVoyage: s.voyageNumber })))
            must equalTo([
                { voyage: "Ocean Vessel", vessel: "NAVIOS VERMILION", lloyds: "9324837",
                  etd: "2026-09-17", stdVessel: null, stdVoyage: null },
                { voyage: "Ocean Vessel", vessel: "NAVIOS VERMILION", lloyds: "9324837",
                  etd: "2026-10-04", stdVessel: null, stdVoyage: null }
            ])),

    // Sections 12/13, on a second order. 2800245092 is the only other message pair that shows
    // the labelled/unlabelled MEA+WT+AAB split, so on its own it could not tell the rule from
    // an accident of that one order. Here the same thing happens again with different numbers,
    // and with the unlabelled value the *larger* of the two (24854 planned, 24804 verified) -
    // so a mapping that took the last AAB, or the highest, rather than the labelled one would
    // pass 2800245092's shape and still report a weight BASF never verified. The container is
    // replaced (1309608150 -> ONEU9419864) and re-tared while its EDIID stays put, which is
    // what lets the update land on the container the Erstinfo created.
    () -> "an unlabelled MEA+WT+AAB is not a VGM, on a second order" in (
        ([ "fcl/2800248632-erstinfo-create.json", "fcl/2800248632-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f)[0].container map ((c) ->
                { no: c.containerNumber, ediid: c.eDIID, tare: c.tareWeight,
                  vgm: c.verifiedGrossMass, sig: c.vgmVerificationSignature })))
            must equalTo([
                { no: "1309608150", ediid: "5002375248/000010", tare: "4600.000",
                  vgm: null, sig: null },
                { no: "ONEU9419864", ediid: "5002375248/000010", tare: "4400.000",
                  vgm: 24804.0, sig: "NICHOLAS GIBBS" }
            ])),

    // The other half of what 2800245092 left open. There the booking number is absent from the
    // Erstinfo and present on the Abschlussinfo; this order carries no RFF+BN in either
    // message, so a completion message with no carrier booking number at all is a shape BASF
    // really sends. ExternalReferences is absent rather than an empty list - an empty list
    // would be an instruction to clear whatever the dossier already holds.
    () -> "an order can complete with no booking number at all" in (
        ([ "fcl/2800248632-erstinfo-create.json", "fcl/2800248632-abschlussinfo-create.json" ]
            flatMap ((f) -> shipmentsOf(f) map ((s) -> s.master.externalReferences)))
            must equalTo([null, null])),

    // === cancel, from a real message =======================================================
    // The example set now carries an actual code 1 IFTMIN, which it did not before, so the
    // cancel branch is no longer covered only by synthetic interchanges. A cancel is identity
    // plus IsInRecycleBin and nothing else - no business field may ride along, or a dossier
    // being withdrawn would be overwritten on its way out.
    () -> "a real cancel message emits identity and the recycle flag only" in (
        (shipmentsOf("fcl/2800244026-iftmin-cancel.json") map ((s) ->
            { bl: s.bASFBL, ref: s.customerReference, recycled: s.isInRecycleBin,
              load: s.loadType, terms: s.deliveryTerms, cargo: s.cargo }))
            must equalTo([{ bl: "BL00", ref: "2800244026", recycled: true,
                            load: null, terms: null, cargo: null }]))
    ]
)
