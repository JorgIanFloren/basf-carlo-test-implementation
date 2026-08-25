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

import * from CommonModule

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
