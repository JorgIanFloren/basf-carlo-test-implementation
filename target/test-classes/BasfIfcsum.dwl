/**
* BASF IFCSUM (consolidation summary) -> Carlo (Soloplan) v3 `shipmentCargo` - mapping
* entry point.
*
* The only one of the three mappings that does not target `seaHouseShipment`. IFCSUM
* arrives after the shipment exists and updates individual cargo lines, matched on the
* delivery note in RFF+LI (docs/00-basf.md: "Fetch Shipment Cargo Line by RFF-LI id").
* What it delivers is the customs MRN (RFF+ABT) and, on an FCL consolidation, the
* container's verified gross mass, seal number and VGM signatory.
*
* Input : `payload` = the whole parsed interchange,
*         `{ EDI: { Messages: { D08A: { IFCSUM: [...] } } } }`.
* Output: `{ "shipmentCargo": [ ... ] }` in camelCase, per
*         docs/expected_output_ShipmentCargo.json.
*
* Every entry carries `actionAttribute: "update"` - the flow has no create path, and an
* upsert would add a duplicate cargo line whenever the delivery-note match failed.
*/
%dw 2.0
output application/json encoding="UTF-8"

import camelKeys from CommonModule
import toCarloCargoUpdates from IfcsumModule
---
{
    shipmentCargo: toCarloCargoUpdates(payload) map ((c) -> camelKeys(c))
}
