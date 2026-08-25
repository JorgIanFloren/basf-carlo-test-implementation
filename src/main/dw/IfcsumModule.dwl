%dw 2.0
/**
* BASF IFCSUM (forwarding & consolidation summary, parsed JSON) -> Carlo / Soloplan v3
* `shipmentCargo` mapping library.
*
* Third of the three BASF inbound mappings, and the only one that does not target
* `seaHouseShipment`. IFTMIN creates the shipment and its cargo lines; IFTMBF updates the
* booking; IFCSUM comes last and updates *individual cargo lines* of a shipment that
* already exists, per docs/00-basf.md:
*
*     Step 0: Fetch Shipment Cargo Line by RFF-LI id
*             Update fields according to mapping
*             Send to Server
*
* Input  : one parsed IFCSUM message object, i.e. an element of
*          `payload.EDI.Messages.D08A.IFCSUM`.
* Output : entries of the Carlo `shipmentCargo` array (contract:
*          docs/expected_output_ShipmentCargo.json), authored in PascalCase; the mapping
*          entry point (src/test/dw/BasfIfcsum.dwl) renders them with `camelKeys`.
*
* --- What the message actually carries -----------------------------------------------------
* Across the four captured examples IFCSUM delivers two things against existing cargo lines:
*
*   FCL (fcl/20260625-*, TrisSquid_Message_Sequence (1))
*       one sea container - its verified gross mass (MEA WT/AAB, described "VGM"), seal
*       number (SEL) and the person who signed the VGM off (NAD+AM) - plus the delivery
*       notes loaded into it.
*   LCL (lcl/IFCSUM_136579804)
*       a truck rather than a container, no VGM, but a customs MRN (RFF+ABT) per consignment.
*
* Both shapes are the same mapping: one `shipmentCargo` entry per (CNI, GID) pair, keyed on
* the delivery note, carrying whichever of MRN / VGM the message happens to have.
*
* --- Identity ------------------------------------------------------------------------------
* The cargo line is identified by RFF+LI = <delivery note>:<position>, which is exactly what
* IftminModule wrote into the cargo line's `DeliveryNoteSAP`, `DeliveryPositionNumber` and
* `EDIID` ("<note>/<position>"). All three are emitted so Carlo can match on whichever it
* indexes.
*
* Navigation is by `_<SEGMENT>` suffix (CommonModule), not by position key - see
* IftmbfModule.dwl for why that matters in the D08A directory.
*/

//import * from CommonModule

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
// Navigation
// ===========================================================================

/** Scalar as a trimmed String ("" for null) - codes are compared through this because the
 *  parser emits some of them as JSON numbers. */
fun str(v) = if (v == null) "" else trim(v as String)

/** The consignment groups (SG26: CNI + its RFF group + its GID groups). */
fun consignments(doc) = groupsWith(body(doc), "CNI")

/** The equipment groups (SG22: EQD + EQN + MEA + SEL + NAD + FTX). */
fun equipments(doc) = groupsWith(body(doc), "EQD")

/** RFF value (RFF0102) with qualifier `q` among a node's direct RFF groups. */
fun refOf(node, q) =
    ((groupsWith(node, "RFF") map ((g) -> seg1(g, "RFF")))
        filter ((r) -> str(r.RFF0101) == q))[0]

/** The goods-item groups (SG51: GID + its RFF group) of a consignment. */
fun goodsOf(consignment) = groupsWith(consignment, "GID")

// ===========================================================================
// Container / VGM
// ===========================================================================

/**
* The one sea container this message reports on, or null.
*
* Two guards, both deliberate:
*
*   - An LCL IFCSUM describes the *truck* that carried the consignments to the terminal
*     ("Truck with removable tarp", no ISO type code in EQD0301). That is pre-carriage
*     equipment, not the container the cargo line sits in, so it must not be written onto
*     the cargo line. A populated EQD0301 is what distinguishes a real container.
*   - Nothing in the message links a consignment to a specific piece of equipment. With a
*     single container that link is unambiguous; with several it would be a guess, so the
*     container block is omitted rather than risk attaching one container's VGM to another
*     container's cargo. Every captured example carries exactly one. See §Open items in
*     docs/ifcsum/01-IFCSUM_mapping_spec.md.
*/
fun soleContainer(doc) = do {
    var withIso = equipments(doc) filter ((eq) -> present(seg1(eq, "EQD").EQD0301))
    ---
    if (sizeOf(withIso) == 1) withIso[0] else null
}

/** Verified gross mass of an equipment group: MEA WT/AAB, the one described "VGM". */
fun vgmWeight(eq) = do {
    var mea = (segs(eq, "MEA") filter ((m) -> str(m.MEA0201) == "AAB"))[0]
    ---
    if (mea == null) null else num(mea.MEA0302)
}

/** The person who signed off the VGM declaration (NAD+AM of the equipment group). */
fun vgmPerson(eq) = (segs(eq, "NAD") filter ((n) -> str(n.NAD01) == "AM"))[0].NAD0401

/** Carlo `Container` block for a cargo line, or null when there is no unambiguous container. */
fun containerObj(doc) = do {
    var eq = soleContainer(doc)
    var eqd = seg1(eq, "EQD")
    var vgm = vgmWeight(eq)
    var seal = seg1(eq, "SEL").SEL01
    var person = vgmPerson(eq)
    ---
    if (eq == null) null
    else {
        (ContainerNumber: eqd.EQD0201) if present(eqd.EQD0201),
        (ContainerType: { Matchcode: eqd.EQD0301 }) if present(eqd.EQD0301),
        (VerifiedGrossMass: vgm) if (vgm != null),
        (SealNumber: seal) if present(seal),
        // Contract spelling, typo included (docs/expected_output_ShipmentCargo.json).
        (VGMPersonInChanrge: person) if present(person)
    }
}

// ===========================================================================
// Cargo lines
// ===========================================================================

/**
* One `shipmentCargo` entry for a (consignment, goods item) pair.
*
* `actionAttribute` is always "update": the flow has no create path - an IFCSUM only ever
* revisits cargo lines an IFTMIN already created - and "updateorcreate" would silently add a
* duplicate line whenever the delivery-note match failed. See `toCarloCargoUpdates` for how
* a code 1 message is handled.
*/
fun cargoLine(doc, consignment, item) = do {
    var cni = seg1(consignment, "CNI")
    var li = refOf(item, "LI")
    var note = li.RFF0102 default cni.CNI0201
    var position = li.RFF0103
    var mrn = refOf(consignment, "ABT").RFF0102
    var container = containerObj(doc)
    ---
    if (!present(note)) null
    else {
        actionAttribute: "update",
        (ItemNumber: seg1(item, "GID").GID01) if (seg1(item, "GID").GID01 != null),
        DeliveryNoteSAP: note,
        (DeliveryPositionNumber: position) if present(position),
        // Same join key IftminModule writes onto the cargo line it creates.
        (EDIID: (note as String) ++ "/" ++ ((position default "") as String)) if present(position),
        (MRN: mrn) if present(mrn),
        (Container: container) if (container != null and !isEmpty(container))
    }
}

/** Every cargo line of one IFCSUM message, in message order. */
fun toCarloCargoUpdate(doc) =
    (consignments(doc) flatMap ((c) -> goodsOf(c) map ((g) -> cargoLine(doc, c, g))))
        filter ((line) -> line != null)

// ===========================================================================
// Interchange entry point
// ===========================================================================

/** True for a cancellation (BGM03 = 1). */
fun isCancel(doc) = str(seg1(body(doc), "BGM").BGM03) == "1"

/**
* Map a whole parsed IFCSUM interchange to the Carlo `shipmentCargo` array.
*
* A code 1 message contributes nothing. Cancelling a consolidation summary does not cancel
* the underlying cargo, and this mapping has no safe way to undo a VGM or an MRN it
* previously sent - so, as with IFTMBF, the flow simply stops. If BASF ever needs a cancel
* to clear those fields, that has to be specified rather than inferred.
*/
fun toCarloCargoUpdates(payload) =
    (messagesOfType(payload, "IFCSUM")
        filter ((m) -> !isCancel(m)))
        flatMap ((m) -> toCarloCargoUpdate(m))
