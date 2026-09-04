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

#### LCL
We need to send an LCL example through the implementation and look what comes out of it.

#### Master Sub
Multiple BL's in one file. Could be all FCL or all LCL. One booking, multiple BLs.
IF LCL -> HouseShipmentType = "Co-load in" "Coloadin"

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
The `lookup.json` files that used to sit under `src\test\resources\BasfIftmbf\*\inputs\` are
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
step. The mappings receive the response on `payload.lookup` - see `config\README.md` check 6.

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

## Issues
#### Current issues 
Date: 2026-09-02
1. IFTMIN Master Sub create = ok / IFTMIN Master sub update its only updating the first shipment even tough the IFTMIN Master Sub update contains BL01 & BL02
2. IFTMIN Master sub create = ok / IFTMBF only contains data for the whole order (Master). The IFTMBF should therefore be applied to every sub of the Master that was send before.
3. When IFTMBF comes first and is of type Master Sub, we currently run into problems because there is no indication of it being of type Master Sub. The automation will currently create a new dossier with empty BL ID.

#### Proposed solutions
1. When master sub, look-ups must be done using the CustomerRef AND bill of lading id (BL ID)
2. When IFTMBF comes in and the lookup returns multiple dossiers, apply the mapping to each returned dossier.
3. When an IFTMIN comes in and the lookup returns one dossier with no BL AND the IFTMIN is of type Master-Sub, then we need to read the existing dossier (IFTMBF data) and cache it. Then we should update the existing dossier with the data of the first Sub BL. Hereafter every other Sub dossier should also get the cached values mapped.