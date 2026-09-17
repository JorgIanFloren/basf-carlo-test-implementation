# BASF
## Elemica
>Note: This section is not important for Claude
SOW - Statement of Work signed. Hasn't started yet, something with licences (most likely basf side of things).

BASF (AS400/SAP) -> |M|p -> (E) >> Polytra
                                >> MAERSK
                                >> ...

## Inbound
### IFTMIN
Three main types of IFTMIN: Code 9 & Code 4 (Update/Create), Code 1 (Cancel)
Default: HouseShipmentType = "BACK-TO-BACK"

#### Canceling
Get the dossier(s) by `customerrefSet`, then for each result set the property isInRecycleBin to true and upsert the record.

#### FCL
Confirmed FCL conversion is good. One new change: HouseShipmentType = "BACK-TO-BACK"

> FCL is currently **switched off** in both `seaHouseShipment` mappings - see "FCL switch" below.

#### LCL
We need to send an LCL example through the implementation and look what comes out of it.

#### Master Sub
Multiple BL's in one file. Could be all FCL or all LCL. One booking, multiple BLs.
IF LCL -> HouseShipmentType = "Co-load in" "Coloadin"

A master-sub interchange is **always uniformly FCL or uniformly LCL, never mixed.**

#### Needed flow
Step 0: "BASF IFTMIN START"
If Code 9 or 4 goto Step 1, else "BASF IFTMIN CANCEL"

Step 1a: "BASF IFTMIN CREATE"
Is this a "Master-Sub"?
- Yes: Run "Master-Sub split flow"
- No: Is this FCL?
- Yes: Run FCL Flow
- No: Run LCL flow
Step 1b: "BASF IFTMIN CANCEL" -- "HOW" TO BE CONFIRMED by Robin/Niels
- Send cancel: using CustomerRef

Step 2: "BASF MASTER-SUB SPLIT"
Is this FCL?
- Yes: Run FCL flow for each FCL Block.
- No: Run LCL flow with bool "co-load:true"

Step 3: FCL Flow
Step 4: LCL Flow

Parametrized flow (TODO: Check possibility) co-load default false
In the LCL flow we need to set HouseShipmentType to "Co-load in" if "co-load:true"

>To check: Can we merge LCL and FCL flow into one mapping, or is it better to keep them split?
According to Chad we should be able to process all three kinds of basf iftmin messages in one big dwl mapping file.

The contract to map to is `expected_output_SeaHouseShipment.json`

#### Scenario's
##### FCL LCL
Create an FCL/LCL, when an update comes, get the existing dossier and upsert it with the new information.
##### Master - Sub FCL / LCL
For each FCL/LCL dossier in the Master-Sub file upsert the dossier.

> Special case when IFTMBF ran first: see IFTMBF section.

### IFTMBF
Three main types of IFTMBF: Code 9 & Code 4 (Update/Create), Code 1 (Cancel)

#### Cancel
Ignore this file

#### Needed flow
Step 0:
- IF Code 1 (Cancel)
- Yes: Stop Integration Flow
- GET DOSSIER by CustomerRef
- IF EXISTS Dossiers
- Yes: For each dossier UPDATE FLOW (PUT dossier by CustomerRef)
- No: For each dossier CREATE FLOW (POST dossier)

Step 1: GET DOSSIERS (By CustomerRef)

Step 2: For each dossier in the result of step 1 - PUT DOSSIER (By CustomerRef and BL ID)
- Take dossier
- Update IFTMBF fields
- Send to update endpoint
Step 3: POST DOSSIER
- Set IFTMBF fields
- Set CustomerRef
- Send to create endpoint

The contract to map to is `expected_output_SeaHouseShipment.json`

#### Scenario's
The `lookup.json` files that used to sit under `src\test\resources\InboundIftmbf\*\inputs\` are
superseded by `docs\get-responses\`, which names each capture after the scenario it belongs to.
Each file is what a lookup by `customerref` returns from the system:

| Capture | What ran first | Returns |
|---|---|---|
| `iftmbf-before-iftmin-fcl.json` | IFTMBF, no pre-existing dossier | 1 dossier, no BL |
| `iftmbf-before-iftmin-lcl.json` | ″ | 1 dossier, no BL |
| `iftmbf-before-iftmin-mastersub-fcl.json` | ″ | 1 dossier, no BL |
| `iftmbf-before-iftmin-mastersub-lcl.json` | ″ | 1 dossier, no BL |
| `iftmin-before-iftmbf-fcl.json` | IFTMIN | 1 dossier, BL00 |
| `iftmin-before-iftmbf-lcl.json` | ″ | 1 dossier, BL00 |
| `iftmin-before-iftmbf-mastersub-fcl.json` | ″ | 2 dossiers, BL01 + BL02 |
| `iftmin-before-iftmbf-mastersub-lcl.json` | ″ | 2 dossiers, BL02 + BL01 (unordered) |
| `dossier-not-found.json` | nothing | `{ "seaHouseShipment": [] }` |

`src\test\resources\get-responses\` is the classpath copy the test suites read; keep the two in
step. Both mappings receive the response on the `payload` node of the seq 3 envelope, beside the
interchange on `originalPayload` - see `config\README.md` check 6 and
`docs\carlo\06-dossier-lookup.md`.

Reference fields, consistent across all nine captures:
- `customerReference` is the **order**, shared by every BL of a master-sub.
- `bASFBL` is the BL (`UNH03`), empty on a dossier an IFTMBF created alone.
- `eDIID` is `customerReference` ++ `bASFBL`, i.e. the composite that identifies one dossier.
- `id` is Carlo's own record number.

#### Additional information on possible scenarios
Following scenario's exist
- Fcl/Lcl
- Master-Sub Fcl/Lcl

##### IFTMBF comes first
###### Fcl / Lcl
FCL and LCL scenarios are pretty straightforward. Map the IFTMBF fields and create a new dossier with them. When the IFTMIN is sent afterwards, lookup the dossier by `customerref` and map out all the other information and send the update.

###### Master-Sub Fcl / Lcl
The Master-Sub scenarios are a bit more complex. Since IFTMBF has no knowledge of Bill of Lading (BL ID). The Master-Sub scenario's will create one dossier based on the IFTMBF and the BL ID will be empty.

When afterwards an IFTMIN Master-Sub is sent we need to lookup the dossier by `customerref` and when we notice that the BL ID is empty, we know we will need to cache the IFTMBF information that was previously saved. Then we need to loop over the IFTMIN dossiers and apply the IFTMBF data we previously loaded to each of the provided dossiers. Idealy we would repurpose the existing dossier, but if it makes more sense solution wise. We could update the IFTMBF record so that the isInRecycleBin property reads true. 

>Note! If you chose to implement the isInRecylceBin path, you have to make sure that when you are getting the dossier(s) by customerref, you have to filter out all return values that have isInRecylceBin = true.

##### IFTMIN comes first
###### Fcl / Lcl
FCL and LCL scenarios are pretty straightforward. Get the existing dossier created by the IFTMIN message. Map the IFTMBF fields and update the dossier with them.

###### Master-Sub Fcl / Lcl
For each dossier found when getting by `customerref`, update the usual iftmbf fields for each dossier and send the update.

### IFCSUM
Step 0:
- Fetch Shipment Cargo Line by RFFLI-id
- Update fields according to mapping
- Send to Server
The contract to map to is `expected_output_ShipmentCargo.json`

## Outbound
### IFTFCC (Invoice)
Mapping underway (Robin)

### IFTSTA (Status message)
Mapping underway (Niels)

## FCL switch

Both `seaHouseShipment` mappings carry a constant `PROCESS_FCL`, shipped `false`.

LCL is processed unconditionally. FCL is switchable because go-live carries LCL only. When the
switch is off an FCL message contributes nothing at all - no create, no update and no cancel
either, since a load type the integration never created is one it must not address. A master-sub
interchange is always uniformly FCL or uniformly LCL, so the filter takes such an interchange
whole or not at all.

To enable FCL: set `PROCESS_FCL = true` in **both** `InboundIftmin.dwl` and `InboundIftmbf.dwl` and
re-upload both blobs. They must hold the same value - a booking that creates an FCL dossier the
instruction then ignores is exactly the orphaned-record state issue 3 below describes.
Re-uploading is how these mappings deploy, so this is a configuration change rather than a code
change. `InboundIfcsum.dwl` has no switch: it addresses a cargo line by `RFF+LI` id and cannot tell
FCL from LCL, so with FCL off an IFCSUM for an FCL order simply finds nothing to update.

> With FCL off an FCL interchange maps to `{ "seaHouseShipment": [] }`. Whether the delivery step
> POSTs that empty array to Carlo or short-circuits is **not established** - nothing in `config/`
> says. Confirm before go-live.

## Issues
#### Current issues 
Date: 2026-09-02
1. IFTMIN Master Sub create = ok / IFTMIN Master sub update its only updating the first shipment even tough the IFTMIN Master Sub update contains BL01 & BL02
2. IFTMIN Master sub create = ok / IFTMBF only contains data for the whole order (Master). The IFTMBF should therefore be applied to every sub of the Master that was send before.
3. When IFTMBF comes first and is of type Master Sub, we currently run into problems because there is no indication of it being of type Master Sub. The automation will currently create a new dossier with empty BL ID.

Date: 11-09-2026
1. Segment PCI in the excel file line 102 should take into account the whole line, not just the first two values.

Date: 16-09-2026
1. Master sub update is still only updating the first shipment, not the second. 
 
#### Proposed solutions
Date: 2026-09-02
1. When master sub, look-ups must be done using the CustomerRef AND bill of lading id (BL ID)
2. When IFTMBF comes in and the lookup returns multiple dossiers, apply the mapping to each returned dossier.
3. When an IFTMIN comes in and the lookup returns one dossier with no BL AND the IFTMIN is of type Master-Sub, then we need to read the existing dossier (IFTMBF data) and cache it. Then we should update the existing dossier with the data of the first Sub BL. Hereafter every other Sub dossier should also get the cached values mapped.

Date: 11-09-2026
1. Join **every** `PCI02` component present, in order, separated by CR/LF, into
   `Cargo/HandlingInfo`. `PCI02` is EDIFACT composite C210 - up to ten 35-character components,
   which BASF uses as a block of fixed-width display lines. A real message carries nine: the
   customer mark, the delivery reference, destination port, batch number, production and expiry
   dates, net and gross weights, country of manufacture - with component 8 padded with leading
   spaces to continue the sentence component 7 begins. One component per line preserves that
   layout, and also supplies the "enter between 'BASF' and the reference" the sheet asks for on
   row 102.

Date: 16-09-2026
1. Not a mapping defect. The addressing fix for 2026-09-02 #1 is in the mapping and tested, but
   **inert in production**: no pipeline step performed the "GET dossier by CustomerRef", so no
   lookup ever reached the mappings and both fell back to a single unaddressed upsert.
   Carlo's `updateorcreate` then matches on `customerReference` alone, so every BL of a
   master-sub resolves onto the same record. The fix is to wire that step - the call is specified
   and server-verified in `docs/carlo/06-dossier-lookup.md`; see also README open item 1 and
   `config/README.md` check 6.

Date: 17-09-2026
1. The lookup step is wired on both profiles, and it does **not** extend the payload - that
   assumption was wrong, and `payload.lookup` is never populated by FrachtConnect. The
   `dataDelivery` at sequence 3 hands the transformer an envelope of two sibling nodes: the
   message as it entered the system under `originalPayload` (the node name is
   `originalPayloadNodeName` on that step) and the GET response under `payload`. The reference the
   GET filters on is injected into its path by the `dataPipeline` at sequence 2.
   `InboundIftmin.dwl` and `InboundIftmbf.dwl` both read the two halves off that envelope, through
   one pair of accessors each ("The pipeline envelope").

#### Status
| Issue | Solution | State |
|---|---|---|
| 02-09 #1 | CustomerRef + BL ID addressing | Implemented and live now the lookup is wired (17-09 #1) |
| 02-09 #2 | one update per returned dossier | Implemented (`toCarloBookingUpdates`) and live |
| 02-09 #3 | cache the booking dossier, re-purpose it for the first sub | Implemented (`bookingCarryForward` / `mergeUnder`) and live |
| 11-09 #1 | whole PCI line | Implemented (`handlingInfo`) |
| 16-09 #1 | wire the dossier lookup | Wired on both profiles (seq 2 + seq 3) |
| 17-09 #1 | read the lookup off the `originalPayload` / `payload` envelope | Implemented in both mappings |

## IFTMIN mapping specification v1.1

`docs/01-BASF-CarLo_IFTMIN_Mapping_Specification_v1.1.md`. Implemented except where noted.

#### Correction to the spec: sections 4-7

The spec lists `customerVessel`, `customerVoyage`, `customerPOL`, `customerPOD` and
`customerPlaceofDelivery` as fields that **must not** be used. That is inverted - those *are* the
BASF customer UDFs, and they are the targets. Three things establish it:

- The `customer` prefix is Carlo's own naming for them; the standard fields are `vessel`,
  `voyageNumber`, `portOfLoading`, `portOfDischarge`.
- A real record this integration created carries `vessel: {null, null}` and `voyageNumber: ""`
  beside `customerVessel: {"GSL MARIA", "9231236"}` and `customerVoyage: "Ocean Vessel"`
  (`docs/get-responses`).
- The v1 mapping sheet targets exactly the standard names that v1.1 says to change away from
  (rows 39, 42, 43, 46).

So POL, POD and Place of Delivery moved onto the customer UDFs, and the standard fields are now
left unset - per the spec's general rule 6, and matching what vessel and voyage already did.

> **Confirm with the analyst:** `portOfLoading` was resolving Carlo master data (it comes back
> with `designation: "Antwerpen"`, `cityCode: "ANR"`), so something downstream may read it.
> Vacating it follows the spec and the vessel precedent, but the effect is not visible from here.

#### Verified against BASF's reference messages

Section 18 of the spec names three validation messages, and all three are now in
`docs/example-orders/inbound/fcl/`. Every v1.1 field is asserted against them, and every value matches
what the specification itself prints:

| Item | Message | Mapped value |
|---|---|---|
| ACID (`RFF+ABT`) | `2800244245` (Egypt) | `2101495821022010016` |
| Booking number | `2800245098` | `57681221`, one entry, `referenceType 9` |
| VGM | ″ | `20897.04`, numeric |
| VGM signature | ″ | `MR WILLMANN, JAN` |
| Notify2 | `2800250325` | `BASF MEXICANA` |
| Notify2 TAX ID | ″ | `BME8109104S6` |

`2800244245` settles where BASF puts `RFF+ABT`: on the **goods item** (SG22), beside `RFF+LC`,
not in the header. That was the one v1.1 mapping this repo could not attest before.

#### Other deviations

- **Section 13 (VGM signature).** The spec says `NAD+AM` occurs once per message and should be
  copied to every container. It actually occurs once *per container*, in that container's own
  SG39 group, so it is read per container with a message-level fallback. Same result whenever the
  value repeats, correct when it does not.
- **Section 4 (Erstinfo gate).** The v1 sheet gated vessel and voyage on "Only when Erstinfo 9",
  which dropped them from every Abschlussinfo - the message a corrected vessel arrives on. The
  gate is withdrawn: vessel, voyage and VGM now map on both code 9 and code 4.
- **Section 11 (DG cardinality).** `dangerousGoods` is now an array, per the v3 contract and the
  spec's own `dangerousGoods[0]`. It was a bare object, matching the legacy TRS sample.
- **Section 16 (Scenario).** The field is obsolete, and removed from `InboundIftmin.dwl` **and**
  `InboundIftmbf.dwl`. The spec covers IFTMIN only, but leaving it in the booking mapping would
  write back on every update what the instruction stopped sending.

#### Open

1. **v1.1 pins this integration to contract v3.** The five TAX ID fields plus `lCNumber` and
   `aCIDNumber` exist only in v3; v4 drops all eight. See `docs/carlo/07-contract-conformance.md`.
2. **LCL bookings lose `HaulageType` and `EstimatedDispatchDate`** (README open item 5). The
   IFTMBF sheet's rules need an `EQD` and an LCL booking has none. With FCL switched off this is
   the main path, not an edge case.
