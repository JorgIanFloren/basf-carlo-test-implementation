/**
* BASF IFTMBF (firm booking) -> Carlo (Soloplan) v3 `seaHouseShipment` - mapping entry point.
*
* Same target endpoint as BasfIftmin.dwl, but this message *updates* the shipment IFTMIN
* created: Carlo matches on DUNSCustomer + CustomerReference and `actionAttribute:
* "updateorcreate"` makes the call an upsert, so a booking that arrives before its IFTMIN
* still lands. Only the fields the "Update" worksheet of docs/iftmbf/IFTMBF_mapping_v1.xlsx
* maps are sent - emitting more would overwrite shipment data with booking-stage values.
*
* Per docs/00-basf.md "IFTMBF / Needed flow" step 0, a code 1 (cancel) booking stops the
* integration flow and contributes nothing.
*
* Input : `payload` = the whole parsed interchange,
*         `{ EDI: { Messages: { D08A: { IFTMBF: [...] } } } }`.
* Output: `{ "seaHouseShipment": [ ... ] }` in camelCase.
*/
%dw 2.0
output application/json encoding="UTF-8"

import camelKeys from CommonModule
import toCarloBookingUpdates from IftmbfModule
---
{
    seaHouseShipment: toCarloBookingUpdates(payload) map ((s) -> camelKeys(s))
}
