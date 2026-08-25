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

### IFTMBF
Three main types of IFTMIN: Code 9 & Code 4 (Update/Create), Code 1 (Cancel)
#### Needed flow
Step 0:
- IF Code 1 (Cancel)
- Yes: Stop Integration Flow
- GET DOSSIER by CustomerRef
- IF EXISTS Dossier
- Yes: UPDATE FLOW (PUT dossier by CustomerRef)
- No: CREATE FLOW (POST dossier)

Step 1: GET DOSSIER (By CustomerRef)

Step 2: PUT DOSSIER (By CustomerRef)
- Take dossier from Step 1
- Update IFTMBF fields
- Send to update endpoint
Step 3: POST DOSSIER
- Set IFTMBF fields
- Set CustomerRef
- Send to create endpoint

The contract to map to is `expected_output_SeaHouseShipment.json`
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