%dw 2.0
output application/json encoding="UTF-8"

/**
* BASF IFTMIN (parsed JSON) -> Carlo / Soloplan v3 `seaHouseShipment` mapping library.
*
* Input  : one parsed IFTMIN message object, i.e. an element of
*          `payload.EDI.Messages.D99A.IFTMIN`. `Heading` carries the business content;
*          `Interchange` / `MessageHeader` carry the envelope. Segment keys are
*          numeric-prefixed ("0020_BGM") and must be quoted.
* Output : the body of one Carlo `seaHouseShipment` entry, authored in PascalCase; the
*          mapping entry point (src/test/dw/BasfIftmin.dwl) renders it with `camelKeys`.
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
*     BGM03 = 1                      -> `cancelShipment`, an identity-only delete
*     BGM03 = 4 / 9                  -> `toCarloShipment`
*         one message  + EQD present -> FCL, HouseType BackToBack
*         one message  + no EQD      -> LCL, HouseType BackToBack
*         many messages (master-sub) -> one shipment per message (per BASF BL), and an
*                                       LCL block becomes HouseType Coloadin (co-load in)
*
* Every position this module selects is verified against the real parser capture at
* docs/example-orders/fcl/2800209301_FCL_IFTMIN_ERST_9.json - none of the positions that
* tools/edifact_to_json.py marks ESTIMATED are read here.
*
* Conventions: functions are left un-annotated (strict type-checker); never name a var
* `input`; a `do{}` allows only declarations before `---`; repeated qualified segments are
* filtered by qualifier, never indexed. `FrachtShipmentRef` is intentionally NOT mapped.
*/

//import * from CommonModule
import substringAfter, substringBefore from dw::core::Strings

/**
* Helpers shared by the three BASF inbound mappings (IFTMIN, IFTMBF, IFCSUM).
*
* Two navigation styles live here and both are needed:
*
*   - Positional selectors ("0020_BGM") are what IftminModule uses. They are exact for a
*     known directory and read naturally, but the position numbers are directory-specific.
*   - Suffix navigation (`segs`/`seg1`/`groupsWith`) matches a segment by its "_<TAG>" key
*     suffix and walks groups structurally, so it survives a directory change. IftmbfModule
*     and IfcsumModule use it, because D08A renumbers almost every group relative to D99A
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

/** Item RFF object (SG22) for qualifier `q`. */
fun rffObj(item, q) = ((item."1110_Segment_group_22" default []) filter ((r) -> r."1120_RFF".RFF0101 == q))[0]."1120_RFF"
fun rffVal(item, q) = rffObj(item, q).RFF0102

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

/** Scenario matchcode: the BASF FCL / BASF LCL scenario the shipment is created under. */
fun scenarioMatchcode(doc) = "BASF " ++ loadType(doc)

/**
* A cancellation payload: identity only.
*
* docs/00-basf.md step 1b is "Send cancel: using CustomerRef". Carlo matches the existing
* shipment on CustomerReference and `actionAttribute: "delete"` removes it, so nothing
* else may be sent - emitting mapped business fields alongside a delete would push
* booking-stage values onto a shipment that is about to be removed, and would overwrite
* live data if the delete were rejected.
*/
fun cancelShipment(doc) = do {
    var ref = doc.Heading."0020_BGM".BGM0201
    ---
    if (!present(ref)) null
    else {
        actionAttribute: "delete",
        (DUNSCustomer: doc.Interchange.UNB0201) if present(doc.Interchange.UNB0201),
        (BASFBL: doc.MessageHeader.UNH03) if present(doc.MessageHeader.UNH03),
        CustomerReference: ref
    }
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
fun dgObj(item) = do {
    var dgs = itemDgs(item)
    ---
    {
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
    ---
    {
        SequenceNumber: idx + 1,
        (ContainerNumber: eqd.EQD0201) if present(eqd.EQD0201),
        ContainerType: { (Matchcode: eqd.EQD0301) if present(eqd.EQD0301) },
        (TareWeight: contMea(meas, "T")) if (contMea(meas, "T") != null),
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
        (HandlingInfo: (pci.PCI0201 default "") ++ "\r\n" ++ (pci.PCI0202 default "")) if (pci != null),
        (AdditionalDGInfo: dgFullText(item)) if (dgFullText(item) != null),
        (AdditionalInfo: ftxAgg(itemDgFtx(item), "ACB", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "ACB", " ", "\r\n") != null),
        (LoadingInstructions: ftxAgg(itemDgFtx(item), "LOI", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "LOI", " ", "\r\n") != null),
        (HandlingRestrictions: ftxAgg(itemDgFtx(item), "AAN", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "AAN", " ", "\r\n") != null),
        (TemperatureControlInstructions: ftxAgg(itemDgFtx(item), "AEB", " ", "\r\n")) if (ftxAgg(itemDgFtx(item), "AEB", " ", "\r\n") != null),
        (DangerousGoods: dgObj(item)) if isRegulatedDg(item)
    }
}

/** Master / MainCarriageAsOcean block. */
fun masterObj(doc) = do {
    var main = mainStage(doc)
    var tdt = main."0470_TDT"
    var etd = ((main."0480_DTM" default []) filter ((d) -> d.DTM0101 == "133"))[0].DTM0102
    var isOriginal = (doc.Heading."0020_BGM".BGM03 default "9") == "9"
    ---
    {
        PreferredModeOfTransport: "Ocean",
        MainCarriageAsOcean: {
            (CustomerVessel: {
                (VesselNumber: tdt.TDT0801) if present(tdt.TDT0801),
                (VesselName: tdt.TDT0804) if present(tdt.TDT0804)
            }) if (isOriginal and (present(tdt.TDT0801) or present(tdt.TDT0804))),
            (CustomerVoyage: tdt.TDT02) if (isOriginal and present(tdt.TDT02)),
            (PortOfLoading: { Matchcode: stageLoc(main, "5").LOC0201 }) if (stageLoc(main, "5") != null),
            (PortOfDischarge: { Matchcode: stageLoc(main, "12").LOC0201 }) if (stageLoc(main, "12") != null),
            (CustomerETD: toIsoDate(etd)) if (etd != null),
            (Carrier: { Matchcode: carrierMatchcode(doc) }) if (nad(doc, "CA") != null)
        }
    }
}

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
// Top-level builders consumed by BasfIftmin.dwl
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
* (one BASF BL each); it only affects `HouseType`. Use `toCarloShipments` rather than
* calling this directly - it derives `masterSub` and routes cancellations.
*/
fun toCarloShipment(doc, masterSub) = do {
    var g0 = firstGood(doc)
    var fw = partyEntry(doc, "FW")
    var cn = itemNad(g0, "CN")
    var dm = itemNad(g0, "DM")
    var n1 = itemNad(g0, "N1")
    var dorec = itemNad(g0, "DO")
    var os = nad(doc, "OS")
    var incoLoc = ((g0."0950_LOC" default []) filter ((l) -> l.LOC01 == "1"))[0]
    var dcp = ((containers(doc)[0]."1840_Segment_group_39" default []) filter ((e) -> e."1850_NAD".NAD01 == "DCP"))[0]."1850_NAD"
    var ep = ((containers(doc)[0]."1840_Segment_group_39" default []) filter ((e) -> e."1850_NAD".NAD01 == "EP"))[0]."1850_NAD"
    ---
    {
        actionAttribute: shipmentAction(doc),
        PreferredModeOfTransport: "Ocean",
        (DUNSCustomer: doc.Interchange.UNB0201) if present(doc.Interchange.UNB0201),
        (BASFBL: doc.MessageHeader.UNH03) if present(doc.MessageHeader.UNH03),
        (CustomerReference: doc.Heading."0020_BGM".BGM0201) if present(doc.Heading."0020_BGM".BGM0201),
        (CustomerTransportManagerName: doc.Heading."0030_CTA".CTA0202) if present(doc.Heading."0030_CTA".CTA0202),
        (CustomerTransportManagerEmail: doc.Heading."0040_COM"[0].COM0101) if present(doc.Heading."0040_COM"[0].COM0101),
        (SendersInstructions: ftxAgg(headerFtx(doc), "SIC", "", "\r\n")) if (ftxAgg(headerFtx(doc), "SIC", "", "\r\n") != null),
        (DocDeliveryInstructions: docDeliveryInstructions(doc)) if (docDeliveryInstructions(doc) != null),
        (BLRemarks: ftxAgg(headerFtx(doc), "AAS", "", "\r\n")) if (ftxAgg(headerFtx(doc), "AAS", "", "\r\n") != null),
        (CustomerEDIType: { Matchcode: ediType(doc) }) if (ediType(doc) != null),
        MovementType: movementType(doc),
        LoadType: loadType(doc),
        HouseType: houseType(doc, masterSub),
        (Incoterms: incoLoc.LOC0201) if present(incoLoc.LOC0201),
        (Incotermplace: incoLoc.LOC0204) if present(incoLoc.LOC0204),
        ShipmentDate: toIsoDate(((mainStage(doc)."0480_DTM" default []) filter ((d) -> d.DTM0101 == "133"))[0].DTM0102)
            default toIsoDate(doc.Heading."0050_DTM"[0].DTM0102),
        DeliveryTerms: "Prepaid",
        // Emitted for LCL as well as FCL - the v1 mapping only ever set it for FCL, which
        // left every LCL shipment without a scenario.
        Scenario: { Matchcode: scenarioMatchcode(doc) },
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
        // Place of delivery (LOC 20)
        (PlaceOfDelivery: {
            (Matchcode: stageLoc(stage(doc, "30"), "20").LOC0201) if present(stageLoc(stage(doc, "30"), "20").LOC0201),
            (Designation: stageLoc(stage(doc, "30"), "20").LOC0204) if present(stageLoc(stage(doc, "30"), "20").LOC0204)
        }) if (stageLoc(stage(doc, "30"), "20") != null),
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
* Step 0 routes on BGM03: a cancellation yields an identity-only delete, anything else a
* full shipment. Step 1a/2 collapse into "one entry per IFTMIN message": a master-sub
* interchange simply carries several messages (BL01, BL02, ...) where an ordinary one
* carries a single BL00, so mapping every message covers both the plain and the split
* case, and each message is independently FCL or LCL.
*
* Messages that carry no CustomerReference are dropped rather than sent: Carlo matches on
* that field, so an identity-less entry would create a junk shipment on this upsert
* endpoint.
*/
fun toCarloShipments(payload) = do {
    var msgs = messagesOfType(payload, "IFTMIN")
    var masterSub = sizeOf(msgs) > 1
    ---
    msgs map ((m) -> if (isCancel(m)) cancelShipment(m) else toCarloShipment(m, masterSub))
          filter ((s) -> s != null)
}

---
{
    seaHouseShipment: toCarloShipments(payload) map ((s) -> camelKeys(s))
}