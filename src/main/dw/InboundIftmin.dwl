%dw 2.0
output application/json encoding="UTF-8"

/**
* BASF IFTMIN (parsed JSON) -> Carlo / Soloplan v3 `seaHouseShipment` - self-contained mapping.
*
* Deployed as `basf/InboundIftmin.dwl` in the `transforms` container, which is the name
* `dwlPath` carries in config/dataProfiler-basf-iftmin.json. The data-transformer evaluates
* this file on its own and resolves no imports off Blob Storage, so it carries everything it
* needs: the shared helpers are inlined below rather than imported, and the document body at
* the foot of the file renders the result. Keep it that way - an `import` added here fails at
* runtime, not at build time. See config/README.md check 2.
*
* Input  : `payload` = the whole parsed interchange,
*          `{ EDI: { Messages: { D99A: { IFTMIN: [...] } } } }`. Only `Messages` carries
*          value; `Errors`, `Delimiters` and `FunctionalAcks*` are ignored. Within a message
*          `Heading` carries the business content and `Interchange` / `MessageHeader` the
*          envelope; segment keys are numeric-prefixed ("0020_BGM") and must be quoted.
*          When the pipeline ran the GET of step 1, its response is on `payload.lookup` - see
*          the "Existing dossiers" section. With no lookup the mapping behaves exactly as it
*          did before that step existed.
* Output : `{ "seaHouseShipment": [ ... ] }` in camelCase. The mapping is authored in
*          PascalCase to match the mapping sheet's XPaths, and `camelKeys` renders that as
*          the camelCase Carlo's case-sensitive JSON deserializer expects.
*
* An interchange with no usable IFTMIN message yields an empty array rather than an
* identity-less shipment, which this upsert endpoint would turn into a junk record.
*
* Mapping authority
*   - docs/iftmin/IFTMIN_mapping_v1.xlsx, worksheets "Create", "Feedback round 1" and
*     "Goods switch".
*   - docs/iftmin/02-IFTMIN-additional-rules.md - carrier / subcontractor matchcode
*     derivation and the two DGS field corrections.
*   - docs/00-basf.md - the create / cancel / master-sub / FCL / LCL flow.
*
* The flow of docs/00-basf.md lives in this module rather than in the pipeline, per the
* note on line 50 of that document ("we should be able to process all three kinds of basf
* iftmin messages in one big dwl mapping file"):
*
*     BGM03 = 1                      -> `recycleShipments`, one identity-only
*                                       `isInRecycleBin: true` upsert per dossier of the order
*     BGM03 = 4 / 9                  -> `toCarloShipment`
*         one message  + EQD present -> FCL, HouseType BackToBack
*         one message  + no EQD      -> LCL, HouseType BackToBack
*         many messages (master-sub) -> one shipment per message (per BASF BL), and an
*                                       LCL block becomes HouseType Coloadin (co-load in)
*
* Each entry is addressed at the dossier the "GET dossier by CustomerRef" step resolved for
* its own BL, which is what keeps the subs of a master-sub order off one another's records.
* See the "Existing dossiers" section for how that lookup reaches the mapping, and
* `toCarloShipments` for what it changes.
*
* Every position this module selects is verified against the real parser capture at
* docs/example-orders/inbound/fcl/2800209301_FCL_IFTMIN_ERST_9.json - none of the positions that
* tools/edifact_to_json.py marks ESTIMATED are read here.
*
* Conventions: functions are left un-annotated (strict type-checker); never name a var
* `input`; a `do{}` allows only declarations before `---`; repeated qualified segments are
* filtered by qualifier, never indexed. `FrachtShipmentRef` is intentionally NOT mapped.
*/

import substringAfter, substringBefore from dw::core::Strings

// ===========================================================================
// Feature switches
// ===========================================================================

/**
* Whether FCL orders are processed at all.
*
* LCL is unconditional; FCL is switchable because BASF go-live carries LCL only and FCL
* follows later. With this `false` an FCL message contributes nothing - no create, no
* update, and no cancel either: the switch gates the whole load type, so that an order the
* integration never created is also never addressed.
*
* A master-sub interchange is always uniformly FCL or uniformly LCL, never mixed, so a
* per-message filter drops such an interchange whole rather than half of it. The filter is
* still per-message because that is the only level at which the load type is knowable.
*
* To enable FCL: flip this to `true` and re-upload *both* `InboundIftmin.dwl` and
* `InboundIftmbf.dwl` - the same constant lives in each, and a booking that creates an FCL
* dossier the instruction then ignores is the state issue 3 of docs/00-basf.md describes.
* Re-uploading the blob is how these mappings deploy, so this is a configuration change
* rather than a code change. See docs/00-basf.md "FCL switch".
*/
var PROCESS_FCL = false

/**
* The switch as the mapping actually reads it.
*
* `PROCESS_FCL` is the operative setting: nothing in the pipeline puts a `config` key on the
* payload (the transformer is handed `EDI`, and `lookup` once that step exists - see
* config/README.md check 6), so in production this is always the constant above.
*
* The override exists because the test suite has no other way in. It runs the mapping through
* `evalPath`, which evaluates this file as shipped, and `dw::Runtime::eval` - the only route
* that could patch the constant - types its scope as `Dictionary<String>` and so cannot be
* handed a payload. Without the seam the suite could only ever exercise whichever state
* happened to be committed, and the 21 example interchanges are mostly FCL.
*/
fun processFcl(payload) = payload.config.processFcl default PROCESS_FCL

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
* inside it: the pipeline places the GET response under `payload.lookup`, alongside
* `payload.EDI`, exactly as the server returned it.
*
*     { EDI: { Messages: {...} }, lookup: { seaHouseShipment: [ ... ] } }
*
* docs/get-responses/*.json are real captures of that response, one per scenario, and are
* what the test suites feed in. A lookup that found nothing is `{ seaHouseShipment: [] }`
* (dossier-not-found.json), which is NOT the same as no lookup at all: an absent
* `payload.lookup` means the pipeline ran no GET, and each mapping then falls back to the
* single-upsert behaviour it had before this step existed. That is what keeps these mappings
* deployable - and every pre-lookup test green - while the GET step is still being wired up.
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

/** True when the pipeline performed a GET and put its response on the payload. */
fun hasLookup(payload) = payload.lookup != null

/**
* The dossiers the GET returned, minus the recycled ones.
*
* Filtering `isInRecycleBin` is required rather than cosmetic: cancelling marks a dossier
* recycled instead of deleting it (docs/00-basf.md, "IFTMIN / Canceling"), so a cancelled
* order still comes back from a GET by CustomerReference. Without this filter, a re-sent
* order would update - and so resurrect - a dossier that was deliberately cancelled.
*/
fun liveDossiers(payload) =
    asArray(payload.lookup.seaHouseShipment) filter ((d) -> d.isInRecycleBin != true)

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
// Navigation over Heading / Interchange
// ===========================================================================

fun headerFtx(doc) = doc.Heading."0090_FTX" default []
fun parties(doc) = doc.Heading."0560_Segment_group_11" default []
fun partyEntry(doc, q) = (parties(doc) filter ((e) -> e."0570_NAD".NAD01 == q))[0]
fun nad(doc, q) = partyEntry(doc, q)."0570_NAD"

/** COM value (COM0101) of a header party entry for communication qualifier `q` (TE/FX/EM). */
fun partyCom(entry, q) =
    ((entry."0600_Segment_group_12" default []) flatMap ((g) -> g."0620_COM" default [])
        filter ((c) -> c.COM0102 == q))[0].COM0101

fun goods(doc) = doc.Heading."0890_Segment_group_18" default []
fun firstGood(doc) = (goods(doc))[0]

/** Item-level party entry / NAD (CN, N1, DO, DM) inside a goods item. */
fun itemPartyEntry(item, q) = ((item."1000_Segment_group_19" default []) filter ((e) -> e."1010_NAD".NAD01 == q))[0]
fun itemNad(item, q) = itemPartyEntry(item, q)."1010_NAD"
/** The ZZZ contact-LOC of an item party (carries TEL/FAX/EMAIL in LOC0204/LOC0304/LOC0404). */
fun itemZzz(item, q) = ((itemPartyEntry(item, q)."1030_LOC" default []) filter ((l) -> l.LOC01 == "ZZZ"))[0]
/** The region name (LOC 47) of an item party, e.g. "Ohio". */
fun itemRegion(item, q) = ((itemPartyEntry(item, q)."1030_LOC" default []) filter ((l) -> l.LOC01 == "47"))[0].LOC0204

fun containers(doc) = doc.Heading."1640_Segment_group_37" default []
fun stages(doc) = doc.Heading."0460_Segment_group_8" default []
fun stage(doc, q) = (stages(doc) filter ((st) -> st."0470_TDT".TDT01 == q))[0]
fun mainStage(doc) = stage(doc, "20")
fun stageLoc(st, q) = if (st == null) null else ((st."0500_Segment_group_9" default []) filter ((g) -> g."0510_LOC".LOC01 == q))[0]."0510_LOC"
/** True when any transport stage carries a LOC 20 (place of delivery / on-carriage). */
fun hasLoc20(doc) = (stages(doc) filter ((st) -> !isEmpty((st."0500_Segment_group_9" default []) filter ((g) -> g."0510_LOC".LOC01 == "20")))) != []

/** Item measurement value (SG20) for MEA type `t`. */
fun meaVal(item, t) = ((item."1050_Segment_group_20" default []) filter ((m) -> m."1060_MEA".MEA0201 == t))[0]."1060_MEA".MEA0302
/** Item measurement value by free description MEA0204 (e.g. "Flash Point"). */
fun meaByDesc(item, d) = ((item."1050_Segment_group_20" default []) filter ((m) -> m."1060_MEA".MEA0204 == d))[0]."1060_MEA".MEA0302
/** Container measurement value (plain 1680_MEA array) for MEA type `t`. */
fun contMea(measArr, t) = ((measArr default []) filter ((m) -> m.MEA0201 == t))[0].MEA0302

/**
* Container Verified Gross Mass, in kilograms.
*
* BASF sends this as `MEA+WT+AAB:::VGM+KGM:24220.000` inside the equipment group, so it
* arrives in the same `1680_MEA` array the tare weight is read from and is already per
* container - different containers of one message carry different values. There is no
* standalone `VGM+` segment in any BASF message; the free description `MEA0204 = "VGM"` is
* what distinguishes this measurement from the ordinary gross weight beside it.
*/
fun contVgm(measArr) = ((measArr default []) filter ((m) -> m.MEA0204 == "VGM"))[0].MEA0302

/**
* The VGM verification signature of one equipment group (`NAD+AM` -> NAD0401), or null.
*
* Spec v1.1 section 13 states that `NAD+AM` occurs once per message and should be copied to
* every container. In the actual BASF messages it occurs once *per container*, inside that
* container's own SG39 party group - so it is read per container here, which gives the same
* result whenever the value repeats and the right one when it does not. `anyVgmSignature`
* supplies the spec's broadcast behaviour for a container that carries none of its own.
*/
fun contVgmSignature(entry) =
    ((entry."1840_Segment_group_39" default []) filter ((e) -> e."1850_NAD".NAD01 == "AM"))[0]."1850_NAD".NAD0401

/** The first VGM verification signature anywhere in the message - fallback for a container without one. */
fun anyVgmSignature(doc) =
    (containers(doc) map ((c) -> contVgmSignature(c)) filter ((v) -> present(v)))[0]

/** Item RFF object (SG22) for qualifier `q`. */
fun rffObj(item, q) = ((item."1110_Segment_group_22" default []) filter ((r) -> r."1120_RFF".RFF0101 == q))[0]."1120_RFF"
fun rffVal(item, q) = rffObj(item, q).RFF0102

/** Header-level RFF value (SG1) for qualifier `q` - where RFF+BN sits. */
fun headerRffVal(doc, q) =
    ((doc.Heading."0110_Segment_group_1" default []) filter ((r) -> r."0120_RFF".RFF0101 == q))[0]."0120_RFF".RFF0102

/** Transport-stage RFF value (SG8/SG10) for qualifier `q`, first across every stage. */
fun stageRffVal(doc, q) =
    ((stages(doc) flatMap ((st) -> st."0530_Segment_group_10" default []))
        filter ((g) -> g."0540_RFF".RFF0101 == q))[0]."0540_RFF".RFF0102

/** The first goods-item RFF value for qualifier `q`, across every goods item. */
fun itemRffValAny(doc, q) =
    (goods(doc) map ((g) -> rffVal(g, q)) filter ((v) -> present(v)))[0]

/** The container number this goods item is loaded in (SGP link). */
fun itemContainerNo(item) = item."1360_Segment_group_29"[0]."1370_SGP".SGP0101

/** DGS object of a goods item, or null. */
fun itemDgs(item) = item."1500_Segment_group_32"[0]."1510_DGS"
/** DG FTX array of a goods item (1520_FTX). */
fun itemDgFtx(item) = item."1500_Segment_group_32"[0]."1520_FTX" default []

// ===========================================================================
// Import action (flowchart: BGM03 -> actionAttribute)
// ===========================================================================

fun shipmentAction(doc) = do {
    var fn = doc.Heading."0020_BGM".BGM03 default "9"
    ---
    fn match {
        case "1" -> "delete"
        case "4" -> "update"
        case "5" -> "update"
        else -> "updateorcreate"
    }
}

/** True for a cancellation (BGM03 = 1), which takes the cancel branch of the flow. */
fun isCancel(doc) = (doc.Heading."0020_BGM".BGM03 default "9") == "1"

/**
* A party's TAX ID - its identifier, but only when the identifier qualifier is 167.
*
* Spec v1.1 section 15. BASF reuses NAD02 for two different things: qualifier 160 carries an
* internal partner number and 167 a tax registration. Only the latter is a TAX ID, so a party
* identified by 160 yields null here rather than writing a partner number into a tax field.
*/
fun taxId(n) = if ((n.NAD0202 default "") == "167") nz(n.NAD0201) else null

// ===========================================================================
// Shipment identity (issue 1 / proposed solution 1)
// ===========================================================================

/** CustomerReference (BGM0201) - the order. Shared by every sub of a master-sub. */
fun refOf(doc) = doc.Heading."0020_BGM".BGM0201

/** The BASF BL (UNH03): BL00 for a plain order, BL01/BL02/... for the subs of a master-sub. */
fun blOf(doc) = doc.MessageHeader.UNH03

/**
* EDIID = CustomerReference ++ BASFBL - the composite that identifies one dossier.
*
* This is the crux of issue 1. Every sub of a master-sub order carries the *same*
* CustomerReference (2800231445 for both BL01 and BL02), so on CustomerReference alone the
* second sub's update resolves onto the first sub's dossier and BL02 silently overwrites
* BL01 - which is exactly the reported "only updating the first shipment".
*
* The concatenation is not invented here: it is how the field reads on every real record in
* docs/get-responses, without exception - "2800226066BL00" for a plain order, "2800231445BL01"
* and "2800231445BL02" for the subs of a master-sub. A dossier an IFTMBF created alone has no
* BL and its eDIID is the bare reference, which the `default ""` below reproduces.
*/
fun ediidOf(doc) = do {
    var ref = refOf(doc)
    var bl = blOf(doc)
    ---
    if (!present(ref)) null
    else (ref as String) ++ (if (present(bl)) (bl as String) else "")
}

/**
* The existing dossier this message should update, or null to create a new one.
*
* Two ways to resolve, in order:
*   1. An exact CustomerReference + BL match - the normal case once IFTMIN has run once, and
*      proposed solution 1. Matching on the BL is what keeps each sub on its own record.
*   2. Failing that, the lone BL-less dossier of the order, which only an IFTMBF that arrived
*      before any IFTMIN can have created (proposed solution 3). The IFTMIN re-purposes that
*      record instead of leaving it orphaned beside a fresh one - the flow document's
*      preferred option ("Idealy we would repurpose the existing dossier"), which also means
*      nothing has to be moved to the recycle bin.
*
* `claimBooking` gates step 2 to a single message: for a master-sub interchange there is one
* BL-less dossier and several subs, so only the first sub may claim it. Every later sub gets
* null and is created.
*/
fun targetDossier(payload, doc, claimBooking) = do {
    var exact = dossierOf(payload, refOf(doc), blOf(doc))
    ---
    if (exact != null) exact
    else if (claimBooking) bookingOnlyDossier(payload, refOf(doc))
    else null
}

/**
* The IFTMBF values cached off a booking-only dossier, as a camelCase fragment ready to be
* laid under a mapped shipment by `mergeUnder`.
*
* The second half of proposed solution 3. When an IFTMBF ran first, its values sit on the one
* BL-less dossier; the arriving IFTMIN re-purposes that dossier for its first sub, but every
* other sub is a brand-new record that would carry no booking data at all. So the booking's
* fields are read once, cached, and applied to all of them - "every other Sub dossier should
* also get the cached values mapped".
*
* The set is exactly the fields InboundIftmbf.dwl maps that InboundIftmin.dwl does not, so nothing
* here can contend with a value the IFTMIN itself carries. That is verified against
* docs/get-responses rather than assumed: `estimatedDispatchDate`, the pickup UN/LOCODE and
* the carrier's ETA / closing date are set on every `iftmbf-before-iftmin-*.json` and absent
* from every `iftmin-before-iftmbf-*.json`. `haulageType` is in the set because IFTMBF can
* derive it for an LCL order where IFTMIN cannot (IFTMIN reads it off the first container).
*
* `mergeUnder` gives the IFTMIN's own values precedence regardless, so a field that both
* sides do populate keeps the shipment's value and this fragment only fills the gaps.
*/
fun bookingCarryForward(d) = do {
    var pickup = d.pickupLocation.pickupLocation
    var main = d.master.mainCarriageAsOcean
    ---
    if (d == null) {}
    else {
        (estimatedDispatchDate: d.estimatedDispatchDate) if present(d.estimatedDispatchDate),
        (haulageType: { matchcode: d.haulageType.matchcode }) if present(d.haulageType.matchcode),
        (pickupLocation: {
            pickupLocation: {
                (unLocationCode: { matchcode: pickup.unLocationCode.matchcode })
                    if present(pickup.unLocationCode.matchcode),
                (address: { location1: pickup.address.location1 }) if present(pickup.address.location1)
            }
        }) if (present(pickup.unLocationCode.matchcode) or present(pickup.address.location1)),
        (master: {
            mainCarriageAsOcean: {
                (customerETA: main.customerETA) if present(main.customerETA),
                (customerClosing: main.customerClosing) if present(main.customerClosing)
            }
        }) if (present(main.customerETA) or present(main.customerClosing))
    }
}

// ===========================================================================
// Load type / master-sub (docs/00-basf.md "Needed flow")
// ===========================================================================

/** "FCL" when the message carries equipment (EQD), else "LCL". */
fun loadType(doc) = if (isEmpty(containers(doc))) "LCL" else "FCL"

/**
* HouseType for one shipment.
*
* The default is BackToBack. The one exception in the flow is a master-sub interchange
* whose block is LCL: that block is a co-load, and Carlo expects the `Coloadin` enum
* member (the flow document writes it both as "Co-load in" and "Coloadin"; the enum is
* the latter, matching how `BackToBack` is spelled on the wire).
*
* `masterSub` is a property of the *interchange*, not of the message, so it is passed in
* by the caller - a single message cannot tell whether it has siblings.
*/
fun houseType(doc, masterSub) =
    if (masterSub and loadType(doc) == "LCL") "Coloadin" else "BackToBack"

/**
* One cancellation payload: identity plus the recycle-bin flag, and nothing else.
*
* docs/00-basf.md, "IFTMIN / Canceling": "Get the dossier(s) by customerrefSet, then for each
* result set the property isInRecycleBin to true and upsert the record." So a cancel is a
* recycle, not a delete - the dossier stays in Carlo and simply drops out of every later
* lookup, which `liveDossiers` is what enforces. (This replaces the earlier
* `actionAttribute: "delete"`, which the flow document no longer describes.)
*
* No mapped business field may ride along: pushing order values onto a dossier that is being
* withdrawn would overwrite live data, and would leave it overwritten if the upsert were
* rejected. `target` supplies the address when a dossier was found - Id and BL, so a
* master-sub cancel recycles each sub on its own record rather than the same one twice.
*/
fun recycleShipment(doc, target) = do {
    var ref = refOf(doc)
    // The dossier's own values when one was found, the message's own when not.
    var bl = target.bASFBL default blOf(doc)
    var ediid = target.eDIID default ediidOf(doc)
    ---
    if (!present(ref)) null
    else {
        actionAttribute: if (target != null) "update" else "updateorcreate",
        (Id: target.id) if (target.id != null),
        (DUNSCustomer: doc.Interchange.UNB0201) if present(doc.Interchange.UNB0201),
        (BASFBL: bl) if present(bl),
        CustomerReference: ref,
        (EDIID: ediid) if present(ediid),
        IsInRecycleBin: true
    }
}

/**
* Every dossier one cancellation message has to recycle.
*
* A cancel names an order, and a master-sub order is several dossiers, so the lookup decides
* the count exactly as it does for IFTMBF. With no lookup at all there is nothing to
* enumerate, so the message maps to one identity-addressed upsert - the pre-lookup shape,
* keyed on CustomerReference + BL.
*
* A lookup that ran and found nothing is different, and yields nothing: there is no dossier
* to recycle, and an upsert would *create* the very record the message is cancelling.
*/
fun recycleShipments(payload, doc): Array<Any> = do {
    var found = dossiersOf(payload, refOf(doc))
    ---
    if (!hasLookup(payload)) [ recycleShipment(doc, null) ]
    else found map ((d) -> recycleShipment(doc, d))
}

// ===========================================================================
// Derivations
// ===========================================================================

/** MovementType: "D/D" when a place-of-delivery (LOC 20) exists, else "D/P". */
fun movementType(doc) = if (hasLoc20(doc)) "D/D" else "D/P"

/** HaulageType matchcode "CAR/CAR" etc. from the first container's TMD + LOC-20 presence. */
fun haulageType(doc) = do {
    var tmd = containers(doc)[0]."1670_TMD"
    var first = if ((tmd.TMD0102 default "") contains "Carrier") "CAR" else "MER"
    var second = if (hasLoc20(doc)) "CAR" else "MER"
    ---
    if (tmd == null) null else first ++ "/" ++ second
}

/** 2-letter POD country from the main-carriage LOC 12. */
fun podCountry(doc) = do {
    var pod = stageLoc(mainStage(doc), "12").LOC0201
    ---
    if (pod == null) null else (pod as String)[0 to 1]
}

/** 2-letter POL country from the main-carriage LOC 5 (LOC+5, Port of Loading). */
fun polCountry(doc) = do {
    var pol = stageLoc(mainStage(doc), "5").LOC0201
    ---
    if (pol == null) null else (pol as String)[0 to 1]
}

/** EU country codes per docs/additional-rules.md (drive the 300606 carrier split). */
fun isEuCountry(cc) =
    ["AT","BE","BG","CY","CZ","DE","DK","ES","EE","EU","FR","FI","GR","HU","HR",
     "IT","IE","LU","LT","LV","MT","NL","PT","PL","RO","SE","SK","SI","XI"] contains cc

/**
* Carrier Matchcode from NAD+CA with the additional override rules (docs/additional-rules.md).
* Depends on POD country (LOC 12), POL country (LOC 5) and the customer NAD+CZ; falls back to the
* raw NAD+CA number (resolved by Carlo master-data conversion) for any carrier not listed.
*/
fun carrierMatchcode(doc) = do {
    var ca = nad(doc, "CA").NAD0201 default ""
    var cz = nad(doc, "CZ").NAD0201 default ""
    var pod = podCountry(doc)
    var pol = polCountry(doc)
    ---
    ca match {
        case "300606" ->
            if (isEuCountry(pod)) "DIAMOND"
            else if (cz == "20051") "COSSHISHA1"
            else "COSSHI_DE"
        case c if (["2713158","292062","300627","4071504"] contains c) ->
            if (cz == "20051") "MSCMEDGVA1" else "MSCMEDGVA"
        case "4794866" -> "OCENETSIN3"
        case "817630" ->
            if (pol == "DE") "ECUWOR_DE"
            else if (pol == "IT") "ECUWOR_IT"
            else if (["BE","UK","FR","NL"] contains pol) "ECUWOR_BE"
            else ca
        else -> ca
    }
}

/** TransportSubcontractor Matchcode from NAD+EP (docs/additional-rules.md): 4794866 -> OCEANHAMBU. */
fun subcontractorMatchcode(epNo) = if ((epNo default "") == "4794866") "OCEANHAMBU" else epNo

/** Marine-pollutant classification from the DG FTX AAC "P" flag. */
fun hazardousToWater(item) =
    if ((ftxOf(itemDgFtx(item), "AAC")[0].FTX0301 default "") == "P") "MarinePollutant" else "NoMarinePollutant"

// ===========================================================================
// Goods switch (see specs/05 §Goods switch)
// ===========================================================================

/** Single packaging level present (only one of GID0201 / GID0301). */
fun singleLevel(gid) = (present(gid.GID0201) and !present(gid.GID0301)) or (present(gid.GID0301) and !present(gid.GID0201))

/**
* Switch = use the OUTER packaging level (GID02) for the primary Cargo fields.
* True only for multi-level goods when (FCL & POD in PE/GT/SV) OR LCL; otherwise use INNER (GID03).
*/
fun goodsSwitch(doc, gid) = do {
    var fcl = !isEmpty(containers(doc))
    ---
    if (singleLevel(gid)) false
    else ((fcl and (["PE", "GT", "SV"] contains podCountry(doc))) or (not fcl))
}

fun pkgCount(doc, gid) = if (goodsSwitch(doc, gid)) (gid.GID0201 default gid.GID0301) else (gid.GID0301 default gid.GID0201)
fun pkgMatchcode(doc, gid) = if (goodsSwitch(doc, gid)) (gid.GID0202 default gid.GID0302) else (gid.GID0302 default gid.GID0202)

/** GoodsDesignation part 1 (variable, two lines) per the switch. */
fun designationPart1(doc, gid) =
    if (goodsSwitch(doc, gid))
        [ gid.GID0205, ((gid.GID0301 default "") ++ " " ++ (gid.GID0205 default gid.GID0305 default "")) ]
    else
        [ gid.GID0305, ((gid.GID0201 default "") ++ " " ++ (gid.GID0205 default "")) ]

/** GoodsDesignation part 2 (constant for every example): FTX/RFF/DGS/MEA lines, in order. */
fun designationPart2(item) = do {
    var ftx = item."0980_FTX" default []
    var aac = ftxOf(itemDgFtx(item), "AAC")
    var dgs = itemDgs(item)
    ---
    (ftxParts(ftxOf(ftx, "AAA")[0] default {}))                      // AAA lines (one per component)
    ++ [ (ftxOf(ftx, "AAS")[0] default {}).FTX0401 ]                 // AAS: US harmonized tariff
    ++ [ if (rffObj(item, "OP") != null) "P.O. NBR " ++ (rffVal(item, "OP") default "") else null ]
    ++ [ rffVal(item, "VN") ]
    ++ [ (aac[0] default {}).FTX0401 ]                               // AAC line 1 (Marine Pollutant)
    ++ [ if ((aac[1] default {}) != {}) (ftxParts(aac[1]) joinBy "") else null ]  // AAC line 2 (IMDG text)
    ++ [ if (dgs.DGS06 != null) "EMS: " ++ dgs.DGS06 else null ]
    ++ [ if (meaByDesc(item, "Flash Point") != null) "Flashpoint: " ++ meaByDesc(item, "Flash Point") ++ " CEL" else null ]
}

fun goodsDesignation(doc, item) = do {
    var gid = item."0900_GID"
    var lines = (designationPart1(doc, gid) ++ designationPart2(item)) filter ((x) -> present(x)) map ((x) -> x as String)
    ---
    nz(lines joinBy "\r\n")
}

// ===========================================================================
// Dangerous goods proper-shipping-name / technical-name extraction
// ===========================================================================

/** The concatenated AAC "IMDG..." description of a goods item (2nd AAC FTX), or null. */
fun dgFullText(item) = do {
    var aac = ftxOf(itemDgFtx(item), "AAC")
    ---
    if ((aac[1] default {}) != {}) (ftxParts(aac[1]) joinBy "") else null
}
/** Proper shipping name = the phrase before the "(technical name)". */
fun properShippingName(item) = do {
    var full = dgFullText(item)
    ---
    if (full == null) null
    else nz(trim(substringBefore(substringAfter(substringAfter(full, ": "), ", "), "(")))
}
/** Technical name = the text inside the parentheses. */
fun technicalName(item) = do {
    var full = dgFullText(item)
    ---
    if (full == null or !(full contains "(")) null
    else nz(trim(substringBefore(substringAfter(full, "("), ")")))
}

// ===========================================================================
// Reusable structural builders
// ===========================================================================

fun bpMatch(nadObj) = if (nadObj == null) null else { Matchcode: nadObj.NAD0201 default "" }

/** Cargo DangerousGoods block (emitted only when DGS is regulated). */
fun dgObj(doc, item) = do {
    var dgs = itemDgs(item)
    var gid = item."0900_GID"
    ---
    {
        // Spec v1.1 section 11: the GID package quantity and packaging code are mapped a
        // *second* time here, in addition to - never instead of - the Cargo fields above.
        // Both are read off this goods item's own GID, so a DG line can never pick up the
        // packaging of a neighbouring one, and both are emitted only on a line that
        // `isRegulatedDg` already established carries dangerous goods.
        (Quantity: pkgCount(doc, gid)) if (pkgCount(doc, gid) != null),
        (Packaging: { Matchcode: pkgMatchcode(doc, gid) }) if present(pkgMatchcode(doc, gid)),
        (UnNumber: dgs.DGS0301) if (dgs.DGS0301 != null),
        (PackagingGroup: dgs.DGS05) if present(dgs.DGS05),
        (Flashpoint: (dgs.DGS0401 default meaByDesc(item, "Flash Point"))) if ((dgs.DGS0401 default meaByDesc(item, "Flash Point")) != null),
        HazardousToWater: hazardousToWater(item),
        (ProperShippingName: properShippingName(item)) if (properShippingName(item) != null),
        (TechnicalName: technicalName(item)) if (technicalName(item) != null),
        EmergencyContactName: "BASF SE /LUDW. 24 HOUR NUMBER",
        (EmergencyContactPhoneNo: dgEmergencyPhone(item)) if (dgEmergencyPhone(item) != null),
        // DGS1001 -> imdgClass, DGS06 -> instructionsForEmergency (docs/additional-rules.md);
        // mapped at the outer DG level per Carlo v3 §5.6 (the self-nested DG is the master-data catalog record).
        (ImdgClass: dgs.DGS1001) if present(dgs.DGS1001),
        (InstructionsForEmergency: dgs.DGS06) if present(dgs.DGS06)
    }
}

/** DG emergency phone extracted from the item DG CTA-HE COM text. */
fun dgEmergencyPhone(item) = do {
    var com = item."1500_Segment_group_32"[0]."1530_Segment_group_33"[0]."1550_COM"[0].COM0101
    ---
    if (com == null or !((com as String) contains ": ")) null
    else nz(trim(substringBefore(substringAfter(com as String, ": "), "|") default ""))
}

fun isRegulatedDg(item) = do {
    var dgs = itemDgs(item)
    ---
    dgs != null and (dgs.DGS01 default "ZZZ") != "ZZZ" and dgs.DGS0301 != null
}

/** Carlo Container block from a SG37 entry. */
fun containerObj(doc, entry, idx) = do {
    var eqd = entry."1650_EQD"
    var meas = entry."1680_MEA" default []
    var ediid = containerEdiid(doc, eqd.EQD0201)
    var vgm = contVgm(meas)
    var sig = contVgmSignature(entry) default anyVgmSignature(doc)
    ---
    {
        SequenceNumber: idx + 1,
        (ContainerNumber: eqd.EQD0201) if present(eqd.EQD0201),
        ContainerType: { (Matchcode: eqd.EQD0301) if present(eqd.EQD0301) },
        (TareWeight: contMea(meas, "T")) if (contMea(meas, "T") != null),
        // Numeric, not the localized display text the segment carries as a string.
        (VerifiedGrossMass: num(vgm)) if (vgm != null),
        (VgmVerificationSignature: sig) if present(sig),
        (EDIID: ediid) if (ediid != null),
        ContainerNumberType: "Known",
        TransportMode: "Container"
    }
}

/** Container/EDIID = "RFF0102/RFF0103-..." for every goods item loaded in this container. */
fun containerEdiid(doc, contNo) = do {
    var refs = (goods(doc) filter ((g) -> itemContainerNo(g) == contNo)) map ((g) -> do {
        var li = rffObj(g, "LI")
        ---
        if (li == null) null else (li.RFF0102 default "") ++ "/" ++ (li.RFF0103 default "")
    })
    ---
    nz((refs filter ((x) -> x != null) map ((x) -> x as String)) joinBy "-")
}

/** Carlo Cargo block from a SG18 goods item. */
fun cargoObj(doc, item, idx) = do {
    var gid = item."0900_GID"
    var li = rffObj(item, "LI")
    var pia = item."0970_PIA"[0]
    var rng = item."0930_RNG"
    var pci = item."1140_Segment_group_23"[0]."1150_PCI"
    var grossSum = num(meaVal(item, "AAE")) + num(meaVal(item, "WT"))
    ---
    {
        (Container: { (ContainerNumber: itemContainerNo(item)) if present(itemContainerNo(item)) }) if present(itemContainerNo(item)),
        ItemNumber: gid.GID01 default (idx + 1),
        (TotalNumberOfPackages: pkgCount(doc, gid)) if (pkgCount(doc, gid) != null),
        Packaging: { (Matchcode: pkgMatchcode(doc, gid)) if present(pkgMatchcode(doc, gid)) },
        (GoodsDesignation: goodsDesignation(doc, item)) if (goodsDesignation(doc, item) != null),
        (TemperatureRangeFrom: rng.RNG0202) if (rng.RNG0202 != null),
        (TemperateRangeTo: rng.RNG0203) if (rng.RNG0203 != null),
        (ArticleNumber: pia.PIA0201) if present(pia.PIA0201),
        (GTIN: pia.PIA0301) if present(pia.PIA0301),
        (DeliveryInfo: ftxAgg(item."0980_FTX", "DEL", " ", "\r\n")) if (ftxAgg(item."0980_FTX", "DEL", " ", "\r\n") != null),
        (TotalGrossWeight: grossSum) if (grossSum > 0),
        (TotalNetWeight: meaVal(item, "AAC")) if (meaVal(item, "AAC") != null),
        (PalletWeight: meaVal(item, "WT")) if (meaVal(item, "WT") != null),
        (TotalDimensionsVolume: meaVal(item, "ABJ")) if (meaVal(item, "ABJ") != null),
        (DeliveryNoteSAP: li.RFF0102) if (li != null),
        (DeliveryPositionNumber: li.RFF0103) if (li.RFF0103 != null),
        (EDIID: (li.RFF0102 default "") ++ "/" ++ (li.RFF0103 default "")) if (li != null),
        (OrderNumberSAP: rffVal(item, "VN")) if (rffVal(item, "VN") != null),
        (GoodsReceiverReference: rffVal(item, "CO")) if (rffVal(item, "CO") != null),
        (CustomerPONumber: rffVal(item, "OP")) if (rffVal(item, "OP") != null),
        (HSCode: rffVal(item, "AQV")) if (rffVal(item, "AQV") != null),
        (HandlingInfo: handlingInfo(pci)) if (handlingInfo(pci) != null),
        (AdditionalDGInfo: dgFullText(item)) if (dgFullText(item) != null),
        (AdditionalInfo: ftxAgg(itemDgFtx(item), "ACB", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "ACB", " ", "\r\n") != null),
        (LoadingInstructions: ftxAgg(itemDgFtx(item), "LOI", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "LOI", " ", "\r\n") != null),
        (HandlingRestrictions: ftxAgg(itemDgFtx(item), "AAN", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "AAN", " ", "\r\n") != null),
        (TemperatureControlInstructions: ftxAgg(itemDgFtx(item), "AEB", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "AEB", " ", "\r\n") != null),
        // An array, not a bare object: the v3 contract types `dangerousGoods` as one entry
        // per UN number on the line, and spec v1.1 section 11 addresses `dangerousGoods[0]`.
        // BASF sends a single DGS per goods item, so this is always one entry.
        (DangerousGoods: [ dgObj(doc, item) ]) if isRegulatedDg(item)
    }
}

/**
* HandlingInfo - the whole PCI marks-and-numbers line, one component per line.
*
* `PCI02` is EDIFACT composite C210, up to ten 35-character components, and BASF uses it as a
* block of fixed-width display lines: a real message carries the customer mark, the delivery
* reference, destination port, batch number, production and expiry dates, net and gross
* weights and the country of manufacture across nine of them, with component 8 padded with
* leading spaces to continue the sentence component 7 begins.
*
* The earlier version emitted only PCI0201 and PCI0202 and dropped everything after, which is
* the 11-09-2026 issue in docs/00-basf.md. Every present component is now joined in order,
* which also supplies the "enter between 'BASF' and the reference" the mapping sheet asks for
* on row 102. The sheet caps the field at 2000 characters; ten 35-character components cannot
* approach that, so no truncation is applied.
*/
fun handlingInfo(pci) = do {
    var parts = (kvs(pci) filter ((e) -> (e.k as String) startsWith "PCI02")
                          orderBy ((e) -> e.k as String)
                          map ((e) -> e.v)
                          filter ((v) -> present(v))
                          map ((v) -> v as String))
    ---
    if (isEmpty(parts)) null else (parts joinBy "\r\n")
}

/**
* Master / MainCarriageAsOcean block.
*
* --- The customer UDF fields (spec v1.1 sections 4-7) ---------------------------------------
* `CustomerVessel`, `CustomerVoyage`, `CustomerPOL`, `CustomerPOD` and
* `CustomerPlaceofDelivery` are the BASF customer-specific UDFs, *not* Carlo's standard
* vessel and port fields - which is the reverse of how spec v1.1 words sections 4-7. Three
* things establish it: the `customer` prefix is Carlo's own naming for them; a real record
* this integration created carries `vessel: {null, null}` and `voyageNumber: ""` beside
* `customerVessel: {"GSL MARIA", "9231236"}` and `customerVoyage: "Ocean Vessel"`
* (docs/get-responses); and the v1 mapping sheet targets exactly the standard names that
* v1.1 now says to change away from (rows 39, 42, 43, 46).
*
* So the standard `Vessel`, `VoyageNumber`, `PortOfLoading` and `PortOfDischarge` are
* deliberately left unset, per general rule 6 of that spec ("The standard CarLo field must
* not be populated instead") and matching what the vessel fields already did.
*
* `CustomerVessel` and `CustomerVoyage` are emitted for every message function. The v1 sheet
* gated them on "Only when Erstinfo 9" (row 39, condition H); that gate is withdrawn, since
* an Abschlussinfo (BGM03 = 4) is exactly where a corrected vessel or voyage arrives and the
* gate silently dropped it.
*
* Customer Lloyds is `TDT0801` and rides in `CustomerVessel/VesselNumber` - the Lloyds number
* is the matchcode Carlo identifies a vessel by. No vessel master-data lookup is performed.
*/
fun masterObj(doc) = do {
    var main = mainStage(doc)
    var tdt = main."0470_TDT"
    var etd = ((main."0480_DTM" default []) filter ((d) -> d.DTM0101 == "133"))[0].DTM0102
    var pod = stageLoc(stage(doc, "30"), "20")
    var bkg = bookingNumber(doc)
    ---
    {
        PreferredModeOfTransport: "Ocean",
        // First RFF+BN only. It occurs twice per message - header SG1 and again on the main
        // carriage stage - with the same value, which is what the spec's first-occurrence
        // rule is about; later occurrences must not add a second entry.
        (ExternalReferences: [ { ReferenceType: 9, Value: bkg } ]) if present(bkg),
        MainCarriageAsOcean: {
            (CustomerVessel: {
                (VesselNumber: tdt.TDT0801) if present(tdt.TDT0801),
                (VesselName: tdt.TDT0804) if present(tdt.TDT0804)
            }) if (present(tdt.TDT0801) or present(tdt.TDT0804)),
            (CustomerVoyage: tdt.TDT02) if present(tdt.TDT02),
            (CustomerPOL: { Matchcode: stageLoc(main, "5").LOC0201 }) if (stageLoc(main, "5") != null),
            (CustomerPOD: { Matchcode: stageLoc(main, "12").LOC0201 }) if (stageLoc(main, "12") != null),
            (CustomerPlaceofDelivery: {
                (Matchcode: pod.LOC0201) if present(pod.LOC0201),
                (Designation: pod.LOC0204) if present(pod.LOC0204)
            }) if (pod != null),
            (CustomerETD: toIsoDate(etd)) if (etd != null),
            (Carrier: { Matchcode: carrierMatchcode(doc) }) if (nad(doc, "CA") != null)
        }
    }
}

/**
* Booking number (`RFF+BN`), first occurrence only.
*
* Header SG1 is the first occurrence in every message that carries one; the main-carriage
* stage repeats the same value, and is the fallback in case a message ever carries only that.
*/
fun bookingNumber(doc) = headerRffVal(doc, "BN") default stageRffVal(doc, "BN")

/**
* ACID number (`RFF+ABT`) - spec v1.1 section 10.
*
* Unattested: no IFTMIN interchange in docs/example-orders/inbound carries an RFF+ABT, and the
* message the spec names as the example (ML 2800244245) is not in the repo. The qualifier
* does occur in IFCSUM, at cargo-line level. So both of the positions BASF uses for a
* reference in IFTMIN are tried - the header SG1 that carries RFF+BN, then the goods-item
* SG22 that carries RFF+LC - and whichever is present wins. Re-verify against a real Egypt
* message before go-live.
*/
fun acidNumber(doc) = headerRffVal(doc, "ABT") default itemRffValAny(doc, "ABT")

/** BLRecipients block for a header BL party entry. */
fun blRecipient(entry) = do {
    var n = entry."0570_NAD"
    var doc0 = entry."0630_Segment_group_13"[0]."0640_DOC"
    ---
    {
        (RecipientNumber: n.NAD0201) if present(n.NAD0201),
        (Name: n.NAD0401) if present(n.NAD0401),
        (Country: { CountryID: n.NAD09 }) if present(n.NAD09),
        (Email: partyCom(entry, "EM")) if present(partyCom(entry, "EM")),
        (BLType: { Matchcode: doc0.DOC03 }) if present(doc0.DOC03),
        (Copies: doc0.DOC04) if (doc0.DOC04 != null),
        (Originals: doc0.DOC05) if (doc0.DOC05 != null)
    }
}

// ===========================================================================
// Top-level builders consumed by InboundIftmin.dwl
// ===========================================================================

/** Carlo `<Header>` content. */
fun carloHeader(doc) = {
    SendDate: toIsoDateTime(doc.Heading."0050_DTM"[0].DTM0102) default null,
    ExportItemReference: doc.Heading."0020_BGM".BGM0201 default ""
}

/**
* One Carlo `seaHouseShipment` entry.
*
* `masterSub` says whether this message shares its interchange with other IFTMIN messages
* (one BASF BL each); it only affects `HouseType`.
*
* `target` is the existing dossier this entry updates, or null to create one - see
* `targetDossier`. It contributes only the address (Carlo's record `Id`) and turns the call
* into a definite update; every mapped field comes from the message either way.
*
* Use `toCarloShipments` rather than calling this directly - it derives `masterSub`, resolves
* `target` and routes cancellations.
*/
fun toCarloShipment(doc, masterSub, target) = do {
    var g0 = firstGood(doc)
    var fw = partyEntry(doc, "FW")
    var cn = itemNad(g0, "CN")
    var dm = itemNad(g0, "DM")
    var n1 = itemNad(g0, "N1")
    var n2 = itemNad(g0, "N2")
    var n3 = itemNad(g0, "N3")
    var dorec = itemNad(g0, "DO")
    var os = nad(doc, "OS")
    var incoLoc = ((g0."0950_LOC" default []) filter ((l) -> l.LOC01 == "1"))[0]
    var dcp = ((containers(doc)[0]."1840_Segment_group_39" default []) filter ((e) -> e."1850_NAD".NAD01 == "DCP"))[0]."1850_NAD"
    var ep = ((containers(doc)[0]."1840_Segment_group_39" default []) filter ((e) -> e."1850_NAD".NAD01 == "EP"))[0]."1850_NAD"
    ---
    {
        // A resolved dossier is an update by definition, whatever BGM03 says - the record
        // demonstrably exists, so leaving "updateorcreate" in place would let a mis-addressed
        // call quietly create a duplicate instead of failing.
        actionAttribute: if (target != null) "update" else shipmentAction(doc),
        (Id: target.id) if (target.id != null),
        PreferredModeOfTransport: "Ocean",
        (DUNSCustomer: doc.Interchange.UNB0201) if present(doc.Interchange.UNB0201),
        (BASFBL: blOf(doc)) if present(blOf(doc)),
        (CustomerReference: refOf(doc)) if present(refOf(doc)),
        // CustomerReference + BASFBL. The reference alone is the order, not the dossier, so
        // without this a master-sub update lands twice on the same record (issue 1).
        (EDIID: ediidOf(doc)) if (ediidOf(doc) != null),
        (CustomerTransportManagerName: doc.Heading."0030_CTA".CTA0202) if present(doc.Heading."0030_CTA".CTA0202),
        (CustomerTransportManagerEmail: doc.Heading."0040_COM"[0].COM0101) if present(doc.Heading."0040_COM"[0].COM0101),
        (SendersInstructions: ftxAgg(headerFtx(doc), "SIC", "", "\r\n")) if (ftxAgg(headerFtx(doc), "SIC", "", "\r\n") != null),
        (DocDeliveryInstructions: docDeliveryInstructions(doc)) if (docDeliveryInstructions(doc) != null),
        (BLRemarks: ftxAgg(headerFtx(doc), "AAS", "", "\r\n")) if (ftxAgg(headerFtx(doc), "AAS", "", "\r\n") != null),
        (CustomerEDIType: { Matchcode: ediType(doc) }) if (ediType(doc) != null),
        // Letter of credit (RFF+LC) - spec v1.1 section 9. BASF carries it on the goods item
        // rather than the header, so the first one found across the items is the shipment's.
        (LCNumber: itemRffValAny(doc, "LC")) if (itemRffValAny(doc, "LC") != null),
        // ACID (RFF+ABT) - spec v1.1 section 10, Egypt shipments. Taken from the structured
        // segment only, never from free-text FTX. No IFTMIN example message in the repo
        // carries one, so both plausible positions are tried; see docs/00-basf.md.
        (ACIDNumber: acidNumber(doc)) if (acidNumber(doc) != null),
        MovementType: movementType(doc),
        LoadType: loadType(doc),
        HouseType: houseType(doc, masterSub),
        (Incoterms: incoLoc.LOC0201) if present(incoLoc.LOC0201),
        (Incotermplace: incoLoc.LOC0204) if present(incoLoc.LOC0204),
        ShipmentDate: toIsoDate(((mainStage(doc)."0480_DTM" default []) filter ((d) -> d.DTM0101 == "133"))[0].DTM0102)
            default toIsoDate(doc.Heading."0050_DTM"[0].DTM0102),
        DeliveryTerms: "Prepaid",
        // Scenario is deliberately not emitted. The field is obsolete on BASF's side (spec
        // v1.1 section 16), and real Carlo records carry `scenario.matchcode: null` - see
        // docs/get-responses. The load type itself still rides on `LoadType` above.
        (HaulageType: { Matchcode: haulageType(doc) }) if (haulageType(doc) != null),
        ObjectOwner: { OrganisationalUnitId: 5 },
        Customer: bpMatch(nad(doc, "CZ")),
        Consignor: bpMatch(nad(doc, "CZ")),
        (FreightPayer: bpMatch(nad(doc, "FP"))) if (nad(doc, "FP") != null),
        // Shipper (from OS): street is NAD0402, city+zip in NAD06
        (Shipper: {
            (Name1: os.NAD0401) if present(os.NAD0401),
            Address: {
                (Street: os.NAD0402) if present(os.NAD0402),
                (Location1: os.NAD06) if present(os.NAD06),
                (Country: { CountryID: os.NAD09 }) if present(os.NAD09)
            }
        }) if (os != null),
        // Forwarder (from FW)
        (ForwarderName: nad(doc, "FW").NAD0401) if present(nad(doc, "FW").NAD0401),
        (ForwarderRoad: (nad(doc, "FW").NAD0501 default "") ++ (nad(doc, "FW").NAD0502 default "")) if present(nad(doc, "FW").NAD0501),
        (ForwarderPcd: nad(doc, "FW").NAD08) if present(nad(doc, "FW").NAD08),
        (ForwarderCity1: nad(doc, "FW").NAD06) if present(nad(doc, "FW").NAD06),
        (ForwarderCountry: { CountryID: nad(doc, "FW").NAD09 }) if present(nad(doc, "FW").NAD09),
        (ForwarderPhone: partyCom(fw, "TE")) if present(partyCom(fw, "TE")),
        (ForwarderEmail: partyCom(fw, "EM")) if present(partyCom(fw, "EM")),
        // Consignee (from item DO)
        (Consignee: {
            (Name1: dorec.NAD0401) if present(dorec.NAD0401),
            (Name2: dorec.NAD0301) if present(dorec.NAD0301),
            Address: {
                (Street: dorec.NAD0501) if present(dorec.NAD0501),
                (Location1: dorec.NAD06) if present(dorec.NAD06),
                (Location2: itemRegion(g0, "DO")) if present(itemRegion(g0, "DO")),
                (ZipCode: dorec.NAD08) if present(dorec.NAD08),
                (Country: { CountryID: dorec.NAD09 }) if present(dorec.NAD09)
            },
            (PhoneNumber: itemZzz(g0, "DO").LOC0204) if present(itemZzz(g0, "DO").LOC0204),
            (EmailAddress: itemZzz(g0, "DO").LOC0404) if present(itemZzz(g0, "DO").LOC0404)
        }) if (dorec != null),
        // Notify 1 (from item N1)
        (Notify1: {
            (Name1: n1.NAD0401) if present(n1.NAD0401),
            (Name2: n1.NAD0402) if present(n1.NAD0402),
            Address: {
                (Street: n1.NAD0501) if present(n1.NAD0501),
                (Location1: n1.NAD06) if present(n1.NAD06),
                (Location2: itemRegion(g0, "N1")) if present(itemRegion(g0, "N1")),
                (ZipCode: n1.NAD08) if present(n1.NAD08),
                (Country: { CountryID: n1.NAD09 }) if present(n1.NAD09)
            }
        }) if (n1 != null),
        (PhoneNumberNotify1: itemZzz(g0, "N1").LOC0204) if present(itemZzz(g0, "N1").LOC0204),
        (EmailNotify1: itemZzz(g0, "N1").LOC0404) if present(itemZzz(g0, "N1").LOC0404),
        // Notify 2 (from item N2) - spec v1.1 section 14. NAD+N2 sits in the same goods-item
        // party group as NAD+N1, so this is deliberately the Notify1 block field for field,
        // writing to the Notify2 targets. Keep the two in step.
        (Notify2: {
            (Name1: n2.NAD0401) if present(n2.NAD0401),
            (Name2: n2.NAD0402) if present(n2.NAD0402),
            Address: {
                (Street: n2.NAD0501) if present(n2.NAD0501),
                (Location1: n2.NAD06) if present(n2.NAD06),
                (Location2: itemRegion(g0, "N2")) if present(itemRegion(g0, "N2")),
                (ZipCode: n2.NAD08) if present(n2.NAD08),
                (Country: { CountryID: n2.NAD09 }) if present(n2.NAD09)
            }
        }) if (n2 != null),
        (PhoneNumberNotify2: itemZzz(g0, "N2").LOC0204) if present(itemZzz(g0, "N2").LOC0204),
        (EmailNotify2: itemZzz(g0, "N2").LOC0404) if present(itemZzz(g0, "N2").LOC0404),
        // Party TAX IDs - spec v1.1 section 15, qualifier 167 only.
        (ShipperTAXID: taxId(os)) if (taxId(os) != null),
        (ConsigneeTAXID: taxId(dorec)) if (taxId(dorec) != null),
        (Notify1TAXID: taxId(n1)) if (taxId(n1) != null),
        (Notify2TAXID: taxId(n2)) if (taxId(n2) != null),
        (Notify3TAXID: taxId(n3)) if (taxId(n3) != null),
        // Goods receiver (from item CN), House level
        (GoodsReceiverName: (cn.NAD0401 default "") ++ " " ++ (cn.NAD0402 default "")) if present(cn.NAD0401),
        (GoodsReceiverRoad: cn.NAD0501) if present(cn.NAD0501),
        (GoodsReceiverPcd: cn.NAD08) if present(cn.NAD08),
        (GoodsReceiverCity1: cn.NAD06) if present(cn.NAD06),
        (GoodsReceiverCity2: (cn.NAD07 default "") ++ " - " ++ (itemRegion(g0, "CN") default "")) if present(cn.NAD07),
        (GoodsReceiverCountry: { CountryID: cn.NAD09 }) if present(cn.NAD09),
        (GoodsReceiverEmail: itemZzz(g0, "CN").LOC0404) if present(itemZzz(g0, "CN").LOC0404),
        // Customer export manager (from item DM)
        (CustomerExportManagerName: dm.NAD0401) if present(dm.NAD0401),
        (CustomerExportManagerAddress: ([dm.NAD0501, dm.NAD08, dm.NAD06, dm.NAD09] filter ((x) -> present(x)) map ((x) -> x as String)) joinBy "\r\n") if (dm != null),
        (CustomerExportManagerPhone: itemZzz(g0, "DM").LOC0204) if present(itemZzz(g0, "DM").LOC0204),
        (CustomerExportManagerEmail: itemZzz(g0, "DM").LOC0404) if present(itemZzz(g0, "DM").LOC0404),
        // Place of delivery (LOC 20) now rides on Master/MainCarriageAsOcean/
        // CustomerPlaceofDelivery - see `masterObj`. Spec v1.1 section 7.
        // Pre-carriage / subcontractor (equipment parties)
        (PickupLocation: { ExportCarrier: { Matchcode: dcp.NAD0201 } }) if present(dcp.NAD0201),
        (TransportSubcontractor: { Matchcode: subcontractorMatchcode(ep.NAD0201) }) if present(ep.NAD0201),
        // BL recipients (header BL parties)
        (BLRecipients: ((parties(doc) filter ((e) -> e."0570_NAD".NAD01 == "BL")) map ((e) -> blRecipient(e)))) if (!isEmpty(parties(doc) filter ((e) -> e."0570_NAD".NAD01 == "BL"))),
        // Containers & cargo
        (Container: (containers(doc) map ((c, i) -> containerObj(doc, c, i)))) if (!isEmpty(containers(doc))),
        (Cargo: (goods(doc) map ((gd, i) -> cargoObj(doc, gd, i)))) if (!isEmpty(goods(doc))),
        Master: masterObj(doc)
    }
}

/** DocDeliveryInstructions = FTX ABR + FTX DOC, each joined by \n, segments by \n\n. */
fun docDeliveryInstructions(doc) = do {
    var segs = (ftxOf(headerFtx(doc), "ABR") ++ ftxOf(headerFtx(doc), "DOC")) map ((f) -> ftxParts(f) joinBy "")
    ---
    nz(segs joinBy "\r\n")
}

/** CustomerEDIType matchcode = the code after ":" in the FTX ABO text (e.g. YE22). */
fun ediType(doc) = do {
    var abo = ftxOf(headerFtx(doc), "ABO")[0]
    ---
    if (abo == null) null else nz(abo.FTX0402 default (if ((abo.FTX0401 default "") contains ":") substringAfter(abo.FTX0401, ":") else null))
}

// ===========================================================================
// Interchange entry point (docs/00-basf.md "Needed flow", step 0 onwards)
// ===========================================================================

/**
* Map a whole parsed IFTMIN interchange to the Carlo `seaHouseShipment` array.
*
* Step 0 routes on BGM03: a cancellation recycles the order's dossiers, anything else maps a
* full shipment. Step 1a/2 collapse into "one entry per IFTMIN message": a master-sub
* interchange simply carries several messages (BL01, BL02, ...) where an ordinary one
* carries a single BL00, so mapping every message covers both the plain and the split
* case, and each message is independently FCL or LCL.
*
* Messages that carry no CustomerReference are dropped rather than sent: Carlo matches on
* that field, so an identity-less entry would create a junk shipment on this upsert
* endpoint.
*
* --- What the lookup adds -------------------------------------------------------------------
* Each message is addressed at the dossier the GET resolved for its own BL (`targetDossier`),
* which is what stops the subs of a master-sub order from overwriting one another.
*
* On top of that, one BL-less dossier in the result means an IFTMBF ran before this IFTMIN
* (issue 3). Its values are read once here - the lookup is a single response, so there is
* nothing to re-fetch per message - and laid underneath every sub, while the first sub
* re-purposes the dossier itself. `mergeUnder` runs after `camelKeys` because the cached
* fragment comes back from Carlo already camelCase.
*
* Order matters in the `flatMap`: `msgs` is in interchange order (BL01 then BL02), so "the
* first sub" is the first BL of the file and not whichever dossier the GET happened to return
* first - the master-sub LCL capture comes back BL02 first.
*/
fun toCarloShipments(payload): Array<Any> = do {
    var all = messagesOfType(payload, "IFTMIN")
    // A property of the interchange, so it is read before the FCL filter - see `houseType`.
    var masterSub = sizeOf(all) > 1
    // The FCL switch (`PROCESS_FCL`). Cancels are gated with everything else: a load type the
    // integration never created is one it must not address either. A master-sub interchange is
    // always uniformly FCL or uniformly LCL, so this drops such an interchange whole.
    var msgs = all filter ((m) -> processFcl(payload) or loadType(m) == "LCL")
    var carry = bookingCarryForward(bookingOnlyDossier(payload, refOf(msgs[0])))
    ---
    (msgs flatMap ((m, i) ->
        if (isCancel(m)) (recycleShipments(payload, m) map ((s) -> camelKeys(s)))
        else [ mergeUnder(
            camelKeys(toCarloShipment(m, masterSub, targetDossier(payload, m, i == 0))),
            carry) ]
    )) filter ((s) -> s != null)
}

---
{
    // Already camelCase: `toCarloShipments` renders each entry itself, because the cached
    // IFTMBF fragment it merges in is camelCase to begin with.
    seaHouseShipment: toCarloShipments(payload)
}