/**
* BASF IFTMIN -> Carlo (Soloplan) v3 `seaHouseShipment` - mapping entry point.
*
* Runs automatically against the parsed JSON representation of an inbound IFTMIN
* interchange; nothing outside this file needs to know which scenario the message is.
* `toCarloShipments` implements the whole of docs/00-basf.md "IFTMIN / Needed flow":
*
*     code 1 (cancel)   -> an identity-only delete, matched on CustomerReference
*     code 4 / 9        -> a full shipment per IFTMIN message in the interchange
*                          FCL / LCL from the presence of EQD
*                          master-sub (several messages, BL01, BL02, ...) -> one entry each,
*                          an LCL block among them becoming HouseType Coloadin
*
* Input : `payload` = the whole parsed interchange, `{ EDI: { Messages: { D99A: { IFTMIN: [...] } } } }`.
*         Only `Messages` carries value; `Errors`, `Delimiters` and `FunctionalAcks*` are ignored.
* Output: `{ "seaHouseShipment": [ ... ] }` in camelCase - Carlo's JSON deserializer is
*         case-sensitive, so `camelKeys` renders the PascalCase names the mapping is
*         authored in (matching the mapping sheet's XPaths) as the camelCase the API expects.
*
* An interchange with no usable IFTMIN message yields an empty array rather than an
* identity-less shipment, which this upsert endpoint would turn into a junk record.
*/
%dw 2.0
output application/json encoding="UTF-8"

import camelKeys from CommonModule
import toCarloShipments from IftminModule
---
{
    seaHouseShipment: toCarloShipments(payload) map ((s) -> camelKeys(s))
}
