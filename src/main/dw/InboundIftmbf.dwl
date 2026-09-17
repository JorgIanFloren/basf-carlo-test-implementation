%dw 2.0
output application/json encoding="UTF-8"

/**
* BASF IFTMBF (firm booking, parsed JSON) -> Carlo / Soloplan v3 `seaHouseShipment` -
* self-contained mapping.
*
* Deployed as `Fracht-Belgium/basf/basf-inbound-iftmbf-to-carlo.dwl`, which is the name
* `dwlPath` carries on the seq 4 transformer step of config/dataProfiler-basf-iftmbf.json -
* the deployed blob is this file under the platform's naming. The data-transformer evaluates
* this file on its own and resolves no imports off Blob Storage, so it carries everything it
* needs: the shared helpers are inlined below rather than imported, and the document body at
* the foot of the file renders the result. Keep it that way - an `import` added here fails at
* runtime, not at build time. See config/README.md check 2.
*
* Sibling of InboundIftmin.dwl, aimed at the same Carlo endpoint. Where IFTMIN *creates* the
* shipment, IFTMBF *updates* it, so the mapping sheet (docs/iftmbf/IFTMBF_mapping_v1.xlsx,
* single worksheet "Update") maps only a handful of fields. Carlo finds the shipment through
* DUNSCustomer + CustomerReference (BGM0201), which the sheet flags as "(searchfield)".
* Everything the sheet leaves unmapped is deliberately NOT emitted, so the update cannot
* blank out data the IFTMIN message already put on the shipment.
*
* Input  : `payload` = the envelope the seq 3 `dataDelivery` step hands on, two sibling nodes:
*          `payload.originalPayload` is the whole parsed interchange,
*          `{ EDI: { Messages: { D08A: { IFTMBF: [...] } } } }`, and `payload.payload` is the
*          response of the "GET dossier by CustomerRef" call - see "The pipeline envelope"
*          and "Existing dossiers" below for that contract. A GET whose response is not a
*          `seaHouseShipment` object is treated as no lookup at all, and the mapping behaves
*          exactly as it did before the GET step existed.
* Output : `{ "seaHouseShipment": [ ... ] }` in camelCase, one entry per dossier the update
*          has to reach. The mapping is authored in PascalCase to match the mapping sheet's
*          XPaths, and `camelKeys` renders that as the camelCase Carlo's case-sensitive JSON
*          deserializer expects.
*
* Flow (docs/00-basf.md, "IFTMBF / Needed flow"): a code 1 message stops the integration
* flow, so `toCarloBookingUpdates` drops it and emits nothing at all. Step 1 GETs the
* dossiers of the order and step 2 PUTs each one - so one booking becomes as many calls as
* the lookup found records, which is what `toCarloBookingUpdates` fans out. A booking that
* found nothing still lands as a single `actionAttribute: "updateorcreate"` upsert, which
* covers the case of the booking arriving before its IFTMIN (step 3, POST).
*
* --- Why this module navigates by segment NAME, not by position key -------------------------
* The EDI parser prefixes every key with the message-structure position ("0020_BGM",
* "0460_Segment_group_10"). Those numbers are directory-specific: IFTMBF D08A renumbers
* practically every group relative to IFTMIN D99A, and two numbers even collide with a
* different meaning (`Segment_group_32` = goods-item DGS in D99A but the equipment group in
* D08A; `Segment_group_18` = the goods item in D99A but the item MEA group in D08A). Hard-coded
* keys copied from InboundIftmin.dwl would therefore silently select the wrong data, and would
* break again on the next directory bump. The suffix-navigation helpers below match on the
* `_<SEGMENT>` suffix and walk groups structurally instead, so the mapping is immune to
* renumbering.
*/


// ===========================================================================
// Feature switches
// ===========================================================================

/**
* Whether FCL orders are processed at all.
*
* The same switch as in InboundIftmin.dwl, and it must hold the same value in both: a booking
* that created an FCL dossier the instruction then ignores is the state issue 3 of
* docs/00-basf.md describes, so enabling FCL means flipping this to `true` and re-uploading
* *both* mappings. LCL is unconditional; FCL is switchable because BASF go-live carries LCL
* only. A cancelled booking already emits nothing, so this only ever gates an update or a
* create. See docs/00-basf.md "FCL switch".
*/
var PROCESS_FCL = false

/**
* The switch as the mapping actually reads it.
*
* `PROCESS_FCL` is the operative setting - nothing in the pipeline puts a `config` key on the
* payload. The override is the seam the test suite needs, because `evalPath` runs this file as
* shipped and there is no other way to exercise both states. See the same function in
* InboundIftmin.dwl.
*/
fun processFcl(payload) = payload.config.processFcl default PROCESS_FCL

// ===========================================================================
// The pipeline envelope
// ===========================================================================

/**
* Where each half of the transformer's input lives.
*
* The data-transformer at sequence 4 is not handed the parsed interchange directly. Sequence 3
* is the "GET dossier by CustomerRef" `dataDelivery` step, and a `dataDelivery` step hands the
* next step an envelope of two sibling nodes rather than a payload it extended in place:
*
*     {
*       "originalPayload": { "EDI": { "Messages": { "D08A": { "IFTMBF": [ ... ] } } } },
*       "payload":         { "seaHouseShipment": [ ... ] }
*     }
*
*   - `originalPayload` is the message as it entered FrachtConnect - here the parsed
*     interchange, i.e. what the transformer used to receive as the whole payload. The node
*     name is configurable and is set by `originalPayloadNodeName` on the seq 3 step of
*     config/dataProfiler-basf-iftmbf.json; change it there and change it here.
*   - `payload` is the GET response, verbatim.
*
* These two accessors are the only place that shape is known. Everything below takes the
* envelope and goes through them, so a rename on the step is a one-line change here.
*
* This is a real change of contract, not a synonym: the earlier wiring was assumed to *extend*
* the payload and put the response on `payload.lookup` beside `payload.EDI`. FrachtConnect does
* not work that way - `payload.lookup` is never populated - so a mapping reading it silently
* saw no dossiers and fell back to a single unaddressed upsert, which for a booking means one
* update landing on one dossier of a master-sub order instead of one per record.
*
* The same section, with the same two functions, is in InboundIftmin.dwl - only the directory,
* the message type and the profile file name differ. Change one and change the other.
*/
fun interchange(payload) = payload.originalPayload

/** The GET response the seq 3 `dataDelivery` step put on the envelope, or null. */
fun lookupResponse(payload) = payload.payload

/**
* Helpers shared by the three BASF inbound mappings (IFTMIN, IFTMBF, IFCSUM).
*
* This block is inlined verbatim into InboundIftmin.dwl, InboundIftmbf.dwl and InboundIfcsum.dwl
* rather than imported: each file is uploaded to Blob Storage on its own and the
* data-transformer resolves no imports there, so a shared module cannot be reached at
* runtime. Change one copy and change all three.
*
* Two navigation styles live here and both are needed:
*
*   - Positional selectors ("0020_BGM") are what InboundIftmin.dwl uses. They are exact for a
*     known directory and read naturally, but the position numbers are directory-specific.
*   - Suffix navigation (`segs`/`seg1`/`groupsWith`) matches a segment by its "_<TAG>" key
*     suffix and walks groups structurally, so it survives a directory change. InboundIftmbf.dwl
*     and InboundIfcsum.dwl use it, because D08A renumbers almost every group relative to D99A
*     and two group numbers collide with a *different* meaning across the two directories.
*
* DataWeave 2.9 notes that this file depends on: `input` is a reserved word; the strict
* type-checker rejects concrete return-type annotations on functions whose bodies are
* Any-typed JSON selectors, so most helpers are left un-annotated - except `asArray` and
* `kvs`, which must be annotated `Array<Any>` for the `flatMap` chains below to type-check.
*/

// ===========================================================================
// Scalars
// ===========================================================================

/** True when `v` is neither null nor blank. */
fun present(v) = v != null and (trim(v as String default "")) != ""

/** Numeric value of `v`, or 0 when absent/unparseable. */
fun num(v) = if (v == null) 0 else (trim(v as String) as Number default 0)

/** Empty / all-blank text -> null, else the value. */
fun nz(v) = if (present(v)) v else null

/** CCYYMMDD... -> YYYY-MM-DD (null when too short). */
fun toIsoDate(v) = do {
    var str = (v default "") as String
    ---
    if (sizeOf(str) < 8) null
    else (str[0 to 3] default "") ++ "-" ++ (str[4 to 5] default "") ++ "-" ++ (str[6 to 7] default "")
}

/** CCYYMMDDHHMM (format 203) -> YYYY-MM-DDTHH:mm:ss; a date-only value -> ...T00:00:00. */
fun toIsoDateTime(v) = do {
    var str = (v default "") as String
    var d = toIsoDate(v)
    ---
    if (d == null) null
    else if (sizeOf(str) >= 12) d ++ "T" ++ (str[8 to 9] default "") ++ ":" ++ (str[10 to 11] default "") ++ ":00"
    else d ++ "T00:00:00"
}

// ===========================================================================
// Carlo JSON rendering
// ===========================================================================

/** PascalCase -> camelCase on a single key (Customer->customer, DUNSCustomer->dUNSCustomer). */
fun lowerFirst(s) = do {
    var str = s as String
    ---
    if (sizeOf(str) <= 1) lower(str)
    else lower(str[0 to 0]) ++ str[1 to -1]
}

/**
* Recursively lower-case the first letter of every object key.
*
* The mappings are authored in PascalCase because that is what the Carlo mapping sheets
* and the v3 XML schema use, but Carlo's JSON deserializer is case-sensitive and expects
* camelCase. Uploading PascalCase JSON makes Carlo silently ignore every field.
*/
fun camelKeys(v) = v match {
    case o is Object -> o mapObject ((val, key) -> { (lowerFirst(key)): camelKeys(val) })
    case a is Array -> a map ((e) -> camelKeys(e))
    else -> v
}

// ===========================================================================
// Suffix navigation (directory-independent)
// ===========================================================================

/** `v` as an array: an array stays, null becomes [], anything else is wrapped. */
fun asArray(v): Array<Any> = v match {
    case a is Array -> a
    case n is Null -> []
    else -> [v]
}

/** The key/value pairs of `node` as an array; null-safe, which makes every chain below null-safe. */
fun kvs(node): Array<Any> = node match {
    case o is Object -> o pluck ((value, key) -> { k: key as String, v: value })
    case n is Null -> []
    else -> []
}

/** Direct-child segments of `node` named `name`, always as an array (possibly empty). */
fun segs(node, name) =
    kvs(node) filter ((e) -> e.k endsWith ("_" ++ name)) flatMap ((e) -> asArray(e.v))

/** The first direct-child segment of `node` named `name`, or null. */
fun seg1(node, name) = segs(node, name)[0]

/** Every direct-child segment-group repeat of `node`, flattened. */
fun subGroups(node) =
    kvs(node) filter ((e) -> e.k contains "_Segment_group_") flatMap ((e) -> asArray(e.v))

/**
* The direct-child group repeats of `node` identified by a segment they carry.
*
* Only *direct* children are considered, so a party group nested two levels down inside an
* equipment group can never be mistaken for a header party group.
*/
fun groupsWith(node, name) = subGroups(node) filter ((g) -> !isEmpty(segs(g, name)))

/** Business-content root of a parsed message: `Heading` in every capture, else the message. */
fun body(doc) = doc.Heading default doc

// ===========================================================================
// Interchange access
// ===========================================================================

/**
* Every parsed message of type `msgType` in the interchange, in order, across whichever
* directory version the sender used.
*
* The parser nests messages as EDI.Messages.<DIRECTORY>.<TYPE>[]. Reading the directory
* level generically rather than hard-coding D99A/D08A means a directory bump does not
* silently yield zero messages - and it is what lets one mapping handle a master-sub
* interchange, which carries several messages of the same type under the same directory.
*/
fun messagesOfType(doc, msgType) =
    kvs(doc.EDI.Messages) flatMap ((dir) -> asArray(dir.v[msgType]))

// ===========================================================================
// FTX free text
// ===========================================================================

/** The non-null text components FTX0401..FTX0405 of one FTX object, in order. */
fun ftxParts(f) =
    [f.FTX0401, f.FTX0402, f.FTX0403, f.FTX0404, f.FTX0405]
        filter ((x) -> x != null) map ((x) -> x as String)

/** The FTX entries in `arr` whose qualifier FTX01 == `q`. */
fun ftxOf(arr, q) = (arr default []) filter ((f) -> f.FTX01 == q)

/**
* Aggregate every FTX carrying qualifier `q`: join one entry's components with `compSep`
* (components are a wrapped continuation of one sentence, so this is normally ""), then
* join repeated entries with `segSep`.
*/
fun ftxAgg(arr, q, compSep, segSep) = do {
    var t = (ftxOf(arr, q) map ((f) -> ftxParts(f) joinBy compSep)) joinBy segSep
    ---
    nz(t)
}


// ===========================================================================
// Existing dossiers - the "GET dossier by CustomerRef" step
// ===========================================================================

/**
* This section is inlined verbatim into InboundIftmin.dwl and InboundIftmbf.dwl - the two mappings
* whose flow starts with a lookup. It is deliberately NOT in InboundIfcsum.dwl, which finds its
* cargo line by RFF+LI id instead. Change one copy and change the other.
*
* Both flows in docs/00-basf.md open with "GET DOSSIER by CustomerRef", and its result is
* what decides create-vs-update and - for a master-sub order - how many records the single
* incoming message has to touch. The data-transformer evaluates a mapping against one
* `payload` context and nothing else (config/README.md), so the lookup result has to travel
* inside it: the GET step hands on an envelope whose `payload` node is that response,
* verbatim, beside the interchange on `originalPayload` - see "The pipeline envelope" above.
*
*     { originalPayload: { EDI: { Messages: {...} } },
*       payload:         { seaHouseShipment: [ ... ] } }
*
* docs/get-responses/*.json are real captures of that response, one per scenario, and are
* what the test suites feed in. A lookup that found nothing is `{ seaHouseShipment: [] }`
* (dossier-not-found.json), which is NOT the same as no lookup at all: an envelope whose
* `payload` node carries no `seaHouseShipment` means no usable GET result reached the mapping
* - a failed call, or a profile without the step - and each mapping then falls back to the
* single-upsert behaviour it had before this step existed. That fallback is what keeps a
* wrongly wired step from looking like "the order has no dossiers": a cancel that reads an
* empty array emits no call at all, so "found nothing" must only ever come from a GET that
* really ran and really found nothing.
*
* Reference fields, verified against all nine captures in docs/get-responses:
*   customerReference - the order. Shared by every BL of a master-sub, so it identifies the
*                       order and never a single dossier.
*   bASFBL            - the BASF BL (UNH03: BL00 for a plain order, BL01/BL02/... for a
*                       master-sub). Empty on a dossier an IFTMBF created on its own.
*   eDIID             - customerReference ++ bASFBL, i.e. the composite that does identify
*                       one dossier ("2800231445BL01").
*   id                - Carlo's own record number.
* The GET returns dossiers in no particular order (iftmin-before-iftmbf-mastersub-lcl.json
* comes back BL02 first), so every match below is by value and never by position.
*/

/**
* True when a usable GET response reached the mapping.
*
* The test is the `seaHouseShipment` key rather than the node itself: the seq 3 step always
* puts *something* on `payload`, so a null test would read an error body - or an empty object
* - as "this order has no dossiers", which is the one reading that must never happen by
* accident (it turns a cancel into a silent no-op). An unrecognised body falls back instead.
*/
fun hasLookup(payload) = lookupResponse(payload).seaHouseShipment != null

/**
* The dossiers the GET returned, minus the recycled ones.
*
* Filtering `isInRecycleBin` is required rather than cosmetic: cancelling marks a dossier
* recycled instead of deleting it (docs/00-basf.md, "IFTMIN / Canceling"), so a cancelled
* order still comes back from a GET by CustomerReference. Without this filter, a re-sent
* order would update - and so resurrect - a dossier that was deliberately cancelled.
*/
fun liveDossiers(payload) =
    asArray(lookupResponse(payload).seaHouseShipment) filter ((d) -> d.isInRecycleBin != true)

/** Trimmed, null-safe string equality - how every reference below is compared. */
fun sameRef(a, b) = trim(a as String default "") == trim(b as String default "")

/** The live dossiers of the order `ref` (all BLs of it, for a master-sub). */
fun dossiersOf(payload, ref) =
    liveDossiers(payload) filter ((d) -> sameRef(d.customerReference, ref))

/**
* The live dossier for one BASF BL of `ref`, or null.
*
* Proposed solution 1 of docs/00-basf.md, and the fix for issue 1: a master-sub order gives
* every one of its BLs the same CustomerReference, so a lookup on CustomerReference alone
* resolves BL02 onto BL01's dossier and the second sub overwrites the first. Only
* CustomerReference + BL ID identifies a record.
*/
fun dossierOf(payload, ref, bl) =
    (dossiersOf(payload, ref) filter ((d) -> sameRef(d.bASFBL, bl)))[0]

/**
* The lone BL-less dossier of `ref`, or null.
*
* This is the record an IFTMBF that arrived before its IFTMIN created: IFTMBF carries no BL
* at all, so the dossier it creates has `bASFBL` empty (issue 3). Deliberately null when
* there is more than one such dossier - that is not a state this flow knows how to resolve,
* and creating fresh records is safer than picking one arbitrarily.
*/
fun bookingOnlyDossier(payload, ref) = do {
    var blLess = dossiersOf(payload, ref) filter ((d) -> !present(d.bASFBL))
    ---
    if (sizeOf(blLess) == 1) blLess[0] else null
}

/**
* Deep-merge `fallback` underneath `base`: `base` wins wherever both carry a key, nested
* objects merge key by key, and keys only `fallback` has are added.
*
* Used to lay cached IFTMBF values under a freshly mapped IFTMIN shipment. A shallow `++`
* will not do, and neither will replacing whole nodes: IFTMBF writes
* `pickupLocation.pickupLocation` while IFTMIN writes `pickupLocation.exportCarrier`, so the
* two have to combine *inside* `pickupLocation` rather than one displacing the other - and
* the same holds for `master.mainCarriageAsOcean`, where IFTMBF contributes the carrier's
* ETA and closing date and IFTMIN the vessel, ports and ETD.
*
* Both sides must already be camelCase, so this runs after `camelKeys`, never before.
* Fallback-only keys are selected with `namesOf` rather than a null test, so a key whose
* value is explicitly null is still treated as present and cannot be emitted twice.
*/
fun mergeUnder(base, fallback) = base match {
    case b is Object -> fallback match {
        case f is Object ->
            (b mapObject ((bv, bk) -> { (bk): mergeUnder(bv, f[bk as String]) }))
                ++ (f filterObject ((fv, fk) -> !(namesOf(b) contains (fk as String))))
        else -> b
    }
    case n is Null -> fallback
    else -> base
}

// ===========================================================================
// Low-level helpers
// ===========================================================================

/** Scalar as a trimmed String ("" for null). The parser emits some codes as JSON numbers
 *  (e.g. UNB0401), so every code comparison goes through this instead of `== "20"`. */
fun str(v) = if (v == null) "" else trim(v as String)

// segs / seg1 / subGroups / groupsWith - the position-agnostic navigation this mapping is
// built on - are defined in the "Suffix navigation" section at the top of this file.

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

/** Load type: containers booked (EQD present) -> FCL, otherwise LCL. */
fun loadType(doc) = if (isEmpty(equipments(doc))) "LCL" else "FCL"

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
* Import action from BGM03, same table as InboundIftmin.dwl: 1 = delete, 4/5 = update, 9 = original.
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
// Top-level builder consumed by InboundIftmbf.dwl
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
*   EQD present?                     -> FCL | LCL, which the FCL switch gates on
*   TMD03 + LOC+20                   -> HaulageType/Matchcode
*
* Plus three fields the sheet does not mention but the Carlo contract needs:
*   - `actionAttribute` (from BGM03) - selects update-vs-create; without it Carlo applies its
*     default and every booking would create a duplicate shipment.
*   - `DeliveryTerms` / `ShipmentDate` - part of the contract's required top-level set
*     (DeliveryTerms, ShipmentDate, ObjectOwner, Customer, Master). Both carry exactly the values
*     InboundIftmin.dwl already sends for the same shipment, so the update cannot change them.
*
* Of that required set, `DeliveryTerms`, `ObjectOwner` and `Master` are unconditional, but
* `Customer` and `ShipmentDate` are emitted only when their source segment is present (NAD+CZ and
* DTM+133 of TDT+20). That is deliberate: on an update, a `Customer: { Matchcode: null }` could
* blank the customer on the existing shipment, which is worse than the 400 Carlo returns for a
* missing one. A booking without NAD+CZ is a data error and should surface as a rejected call.
* `ShipmentDate` intentionally does NOT reuse InboundIftmin.dwl's DTM+137 fallback - the message date would
* overwrite the real ETD that IFTMIN set.
*
* NOT emitted, on purpose:
*   - TDT+10 "60+11" (pre-carriage mode of transport): the sheet row is highlighted as open,
*     "Mode of transport - waiting Soloplan v3.07"; there is no target XPath yet. TODO once
*     Soloplan ships it.
*   - Every other segment of the message (parties other than CZ, goods items, dangerous goods,
*     containers, ports, CNT totals ...): unmapped in the sheet, and emitting them on an update
*     would risk overwriting shipment data with booking-stage values.
*
* --- Addressing one dossier -----------------------------------------------------------------
* `target` is the existing dossier this update is aimed at, or null when the GET found none
* (or ran at all) and the call is a plain upsert. Nothing the sheet maps depends on it - a
* booking describes the whole order and knows nothing about BLs, so the mapped values are
* identical for every dossier of the order. What `target` adds is the *address*: the BL, the
* composite EDIID and Carlo's record Id, which is what turns "update the order" into "update
* this record". Without it, every sub of a master-sub order matches on CustomerReference
* alone and the one booking lands on whichever dossier Carlo happens to resolve first.
*/
fun toCarloBookingUpdate(doc, target) = do {
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
        // A resolved dossier is by definition an update, whatever BGM03 says: the record
        // demonstrably exists, so leaving the code's "updateorcreate" in place would let a
        // mis-addressed call create a duplicate instead of failing loudly.
        actionAttribute: if (target != null) "update" else shipmentAction(doc),
        (Id: target.id) if (target.id != null),
        (DUNSCustomer: doc.Interchange.UNB0201) if present(doc.Interchange.UNB0201),
        CustomerReference: bookingRef(doc),
        // From the dossier, never from the message - IFTMBF carries no BL of its own.
        (BASFBL: target.bASFBL) if present(target.bASFBL),
        (EDIID: target.eDIID) if present(target.eDIID),
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
        // Scenario is deliberately not emitted. The field is obsolete on BASF's side (IFTMIN
        // spec v1.1 section 16) and real Carlo records carry `scenario.matchcode: null`; it is
        // dropped here too, or every booking update would write back what the instruction
        // stopped sending. See docs/get-responses.
        (HaulageType: { Matchcode: haulage }) if (haulage != null),
        // Contract-required, not sheet-mapped - same values InboundIftmin.dwl sends for this shipment.
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
* contributes nothing ("IFTMBF / Cancel": ignore this file). The asymmetry with IFTMIN, where
* a cancellation recycles the dossier, is intended: the booking being withdrawn does not mean
* the shipment is.
*
* Bookings with no CustomerReference are dropped for the same reason as in IFTMIN - the
* endpoint upserts, and an identity-less entry would create a junk shipment.
*
* --- One booking, one update per dossier ----------------------------------------------------
* This is issue 2 / proposed solution 2, and the reason step 2 of the flow reads "For each
* dossier in the result of step 1 - PUT DOSSIER". An IFTMBF describes the whole order, so a
* master-sub order whose IFTMIN already created BL01 and BL02 has *two* dossiers that the one
* booking has to reach; emitting a single update left the booking data on only one of them.
* The lookup result decides the count:
*
*   n dossiers -> n updates, the mapped booking fields addressed to each in turn
*   0 dossiers -> one upsert, i.e. the booking arrived first and creates the dossier
*                 (docs/get-responses/dossier-not-found.json)
*   no lookup  -> one upsert, the pre-lookup behaviour
*
* Both of the last two cases collapse to `target = null`, which is exactly the plain upsert
* this mapping emitted before the GET step existed.
*/
fun toCarloBookingUpdates(payload) = do {
    // The FCL switch (`PROCESS_FCL`), applied beside the cancel filter: with FCL off an FCL
    // booking contributes nothing, so it can neither create a dossier the instruction will
    // ignore nor update one the instruction never made.
    var msgs = messagesOfType(interchange(payload), "IFTMBF")
        filter ((m) -> !isCancel(m))
        filter ((m) -> processFcl(payload) or loadType(m) == "LCL")
    ---
    (msgs flatMap ((m) -> do {
        var targets = dossiersOf(payload, bookingRef(m))
        ---
        if (isEmpty(targets)) [ toCarloBookingUpdate(m, null) ]
        else targets map ((d) -> toCarloBookingUpdate(m, d))
    })) filter ((s) -> s != null)
}

---
{
    seaHouseShipment: toCarloBookingUpdates(payload) map ((s) -> camelKeys(s))
}