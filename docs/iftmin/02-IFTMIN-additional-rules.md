Country code can be derived from POD, the country code are the first two characters from POD.
When the country code is in the following list, it is an EU country code:
AT,BE,BG,CY,CZ,DE,DK,ES,EE,EU,FR,FI,GR,HU,HR,IT,IE,LU,LT,LV,MT,NL,PT,PL,RO,SE,SK,SI,XI

Rules to implement:
- if NAD+CA = 300606 and POD is an EU Country code then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=DIAMOND
- if NAD+CA = 300606 and POD is an not EU Country code and NAD+CZ = 20051 then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=COSSHISHA1
- if NAD+CA = 300606 and POD is an not EU Country code and NAD+CZ =/= 20051 then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=COSSHI_DE
- if NAD+CA in (2713158, 292062, 300627, 4071504) then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=MSCMEDGVA, if NAD+CZ = 20051 then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode+"1" (MSCMEDGVA1)
- if NAD+CA = 4794866 then  result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=OCENETSIN3
- if NAD+CA = 817630 LOC+5 starts with 'DE' then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=ECUWOR_DE
- if NAD+CA = 817630 LOC+5 starts with 'IT' then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=ECUWOR_IT
- if NAD+CA = 817630 LOC+5 starts with any of ('BE', 'UK', 'FR', 'NL') then result.SeaHouseShipmentData.SeaHouseShipment.Master.MainCarriageAsOcean.Carrier.Matchcode=ECUWOR_BE

- if NAD+EP = 4794866 then result.SeaHouseShipmentData.SeaHouseShipment.TransportSubcontractor.Matchcode=OCEANHAMBU

Mapping adjustment:
The value of node 1500_Segment_group_32.1510_DGS.DGS1001 must map to seaHouseShipment[index].cargo[index].dangerousGoods[index].imdgClass
The value of node 1500_Segment_group_32.1510_DGS.DGS06 must map to seaHouseShipment[index].cargo[index].dangerousGoods[index].instructionsForEmergency