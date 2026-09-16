# BASF to CarLo IFTMIN Mapping Specification

> **Implementation notes — read before working from this document.** The body below is the
> supplied specification, unaltered. Three things in it were found not to match the system or the
> real BASF messages while implementing it; the reasoning and evidence are in
> `docs/00-basf.md` → *"IFTMIN mapping specification v1.1"*.
>
> - **§4–§7 are inverted.** `customerVessel`, `customerVoyage`, `customerPOL`, `customerPOD` and
>   `customerPlaceofDelivery` are listed as forbidden, but those *are* the BASF customer UDFs and
>   they are the targets. The standard fields are `vessel`, `voyageNumber`, `portOfLoading`,
>   `portOfDischarge`.
> - **§13 is wrong about cardinality.** `NAD+AM` occurs once *per container*, not once per
>   message, so the signature is read per container with a message-level fallback.
> - **§16 (remove Scenario) also applies to `BasfIftmbf.dwl`,** which this IFTMIN-scoped document
>   does not mention. Left in the booking mapping, it would write the value straight back.
>
> §10 (ACID) is implemented but **unattested** — no example message carries an `RFF+ABT`.

## 1. Purpose

This document defines the requested changes to the existing BASF IFTMIN to CarLo integration. It distinguishes between:

- changes to existing mappings;
- additional mappings that must not replace existing behaviour;
- mappings that must be removed; and
- items that remain outside the interface scope.

Unless explicitly stated otherwise, the existing integration behaviour remains unchanged.

## 2. Scope

### Included

- Change the existing Customer Lloyds, Customer Vessel, and Customer Voyage mapping to customer-specific UDF fields.
- Change the existing Customer POL, Customer POD, and Customer Place of Delivery mapping to customer-specific UDF fields.
- Booking Number (`RFF+BN`).
- Letter of Credit Number (`RFF+LC`).
- ACID Number (`RFF+ABT`).
- Additional dangerous-goods package quantity and packaging fields, without changing the existing cargo mappings.
- Verified Gross Mass (VGM).
- VGM verification signature.
- Notify2, using the existing Notify1 logic.
- Party TAX ID fields.
- Removal of the existing `Scenario = BASF FCL` mapping.

### Out of scope

- Transport mode. This is provided through the BASF IFTMBF message and is not part of this IFTMIN mapping.
- Changes to Merchant Haulage and Carrier's Haulage. The existing integration logic remains unchanged. Additional logic will be handled by a workflow in CarLo.
- Freight Payer changes. These will be handled in CarLo.

## 3. General implementation rules

1. JSON paths are relative to the integration payload root.
2. Do not assume a fixed cargo or container array index when the EDIFACT hierarchy determines the applicable record.
3. Preserve identifiers and codes as strings, including leading zeroes where applicable.
4. Structured EDIFACT fields are the source of truth. Do not extract a mapped value from free-text `FTX` when a structured segment is defined.
5. Existing mappings must remain unchanged unless this document explicitly says that they must be changed or removed.
6. Where this document refers to an existing customer-specific UDF, Soloplan must use the corresponding UDF already configured for the BASF integration. The standard CarLo field must not be populated instead.

---

## 4. Change Existing Mapping: Customer Lloyds, Vessel, and Voyage

### Background

These values are already extracted and mapped by the existing integration. The target mapping must be changed. The integration must use the existing BASF customer-specific UDF fields instead of the standard CarLo Vessel and Voyage fields.

### Source EDIFACT

```edifact
TDT+20+Ocean Vessel+10+13++++9472165:146:11:COSCO HOPE
```

### Values

| Business value | Example extracted value | Required target |
|---|---|---|
| Customer Lloyds | `9472165` | Existing BASF Customer Lloyds UDF |
| Customer Vessel | `COSCO HOPE` | Existing BASF Customer Vessel UDF |
| Customer Voyage | `Ocean Vessel` | Existing BASF Customer Voyage UDF |

### Required change

- Keep the existing EDIFACT extraction logic.
- Populate the existing BASF customer-specific UDF fields.
- Do not populate the standard CarLo Vessel or Voyage fields for these customer values.
- Do not perform a Vessel master-data lookup for this requested change unless that lookup is required by unchanged integration logic outside these customer UDF mappings.

### Fields that must not be used as the new targets

```text
seaHouseShipment[0].master.mainCarriageAsOcean.customerVessel
seaHouseShipment[0].master.mainCarriageAsOcean.customerVoyage
```

### Technical note

The exact UDF technical names are not repeated in the supplied requirements. Soloplan must use the existing BASF UDF fields currently configured for Customer Lloyds, Customer Vessel, and Customer Voyage.

---

## 5. Change Existing Mapping: Customer POL

### Source EDIFACT

```edifact
LOC+5+BEANR:::Antwerpen
```

### Extracted value

```text
BEANR
```

### Required target

```text
Existing BASF Customer POL UDF
```

### Required change

- Keep the existing extraction of the location code from `LOC+5`.
- Populate the existing BASF Customer POL UDF.
- Do not use the standard CarLo Customer POL field as the new target.

### Standard field that must not be used as the new target

```text
seaHouseShipment[0].master.mainCarriageAsOcean.customerPOL.matchcode
```

---

## 6. Change Existing Mapping: Customer POD

### Source EDIFACT

```edifact
LOC+12+USNYC:::NEW YORK
```

### Extracted value

```text
USNYC
```

### Required target

```text
Existing BASF Customer POD UDF
```

### Required change

- Keep the existing extraction of the location code from `LOC+12`.
- Populate the existing BASF Customer POD UDF.
- Do not use the standard CarLo Customer POD field as the new target.

### Standard field that must not be used as the new target

```text
seaHouseShipment[0].master.mainCarriageAsOcean.customerPOD.matchcode
```

---

## 7. Change Existing Mapping: Customer Place of Delivery

### Source EDIFACT

```edifact
LOC+20+USCMH:::Columbus (OH) - Terminal
```

### Extracted value

```text
USCMH
```

### Required target

```text
Existing BASF Customer Place of Delivery UDF
```

### Required change

- Keep the existing extraction of the location code from `LOC+20`.
- Populate the existing BASF Customer Place of Delivery UDF.
- Do not use the standard CarLo Customer Place of Delivery field as the new target.

### Standard field that must not be used as the new target

```text
seaHouseShipment[0].master.mainCarriageAsOcean.customerPlaceofDelivery.matchcode
```

---

## 8. Add Booking Number

### Source EDIFACT

```edifact
RFF+BN:BKGREF123
```

### Mapping

```text
BKGREF123 -> seaHouseShipment[0].master.externalReferences[0].value
```

Set:

```text
seaHouseShipment[0].master.externalReferences[0].referenceType = 9
```

### First-occurrence rule

- Map only the first `RFF+BN` occurrence.
- Ignore later `RFF+BN` occurrences.
- Do not create extra `externalReferences` entries.
- Do not overwrite the first value.

### Target JSON example

```json
{
  "seaHouseShipment": [
    {
      "master": {
        "externalReferences": [
          {
            "referenceType": 9,
            "value": "BKGREF123"
          }
        ]
      }
    }
  ]
}
```

---

## 9. Add Letter of Credit Number

### Source EDIFACT

```edifact
RFF+LC:LC123456
```

### Mapping

```text
LC123456 -> seaHouseShipment[0].lCNumber
```

For an `RFF` segment with qualifier `LC`, extract the reference value and map it to `lCNumber`.

---

## 10. Add ACID Number

### Source EDIFACT

```edifact
RFF+ABT:2101495821022010016
```

### Mapping

```text
2101495821022010016 -> seaHouseShipment[0].aCIDNumber
```

### Rules

- Use the value from structured segment `RFF+ABT`.
- Do not extract the ACID number from free-text `FTX` segments.

---

## 11. Add Dangerous-Goods Package Quantity and Packaging

### Background

The EDIFACT package quantity and packaging code are already mapped to the normal Cargo fields. Those existing mappings must not be changed or removed.

### Source EDIFACT

```edifact
GID+1+7:CP3:67:91:Pallet,wood,CP3,1140x1140x138mm,HT+35:1H1:::Plastic drums
```

### Existing mappings to retain unchanged

```text
35  -> seaHouseShipment[0].cargo[n].totalNumberOfPackages
1H1 -> seaHouseShipment[0].cargo[n].packaging.matchcode
```

### Additional mappings

When the same GID goods item contains applicable dangerous-goods information in a `DGS` segment, process the same values additionally in the CarLo Dangerous Goods fields:

```text
35  -> seaHouseShipment[0].cargo[n].dangerousGoods[0].quantity
1H1 -> seaHouseShipment[0].cargo[n].dangerousGoods[0].packaging.matchcode
```

### Required behaviour

1. Retain the existing normal Cargo mappings.
2. Do not redirect or replace those existing mappings.
3. Evaluate dangerous-goods information within the current GID goods-item hierarchy.
4. When the current GID contains applicable dangerous-goods data, also populate the extra Dangerous Goods quantity and packaging fields.
5. When the current GID does not contain applicable dangerous-goods data, do not create the additional Dangerous Goods package mapping.
6. Never copy values from one GID goods item to Dangerous Goods data belonging to another GID goods item.

### Target JSON example

```json
{
  "seaHouseShipment": [
    {
      "cargo": [
        {
          "totalNumberOfPackages": 35,
          "packaging": {
            "matchcode": "1H1"
          },
          "dangerousGoods": [
            {
              "quantity": 35,
              "packaging": {
                "matchcode": "1H1"
              }
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 12. Add Verified Gross Mass (VGM)

### Source EDIFACT examples

```edifact
VGM+KGM:24220.000
```

A supplied BASF Abschlussinfo example contains:

```edifact
MEA+WT+AAB:::VGM+KGM:20897.040
```

### Mapping

```text
VGM value -> seaHouseShipment[0].container[n].verifiedGrossMass
```

### Rules

- Extract the kilogram value.
- Map it to the corresponding container.
- Store it as a numeric value, for example `24220.00`, not localized display text.
- Support the applicable BASF IFTMIN VGM representation.

---

## 13. Add VGM Verification Signature

### Source EDIFACT

```edifact
NAD+AM+++MR SCHMIDT; MICHAEL; TST GMBH
```

### Mapping

```text
MR SCHMIDT; MICHAEL; TST GMBH
-> seaHouseShipment[0].container[n].vgmVerificationSignature
```

### Distribution rule

- `NAD+AM` occurs once per EDIFACT message.
- Extract the complete applicable name value.
- Apply the same signature to every container in the shipment.

---

## 14. Add Notify2

Notify2 must use exactly the same mapping and parsing logic as the existing Notify1 mapping, but write to the Notify2 fields.

### Notify1 source example

```edifact
NAD+N1+4377277:160++BDP INTERNATIONAL:BASF IMPORT OPERATIONS+510 WALNUT ST, FL 3+PHILADELPHIA+PA+191063690+US
```

### Existing Notify1 output example

```json
{
  "notify1": {
    "name1": "BDP INTERNATIONAL",
    "name2": "BASF IMPORT OPERATIONS",
    "address": {
      "location1": "PHILADELPHIA",
      "location2": "Pennsylvania",
      "zipCode": "191063690",
      "street": "510 WALNUT ST, FL 3",
      "country": {
        "countryID": "US",
        "countryName": "United States of America"
      },
      "state": null
    }
  }
}
```

### Notify2 source example

```edifact
NAD+N2+BME8109104S6:167+CIUDAD DE LOS DEPORTES+BASF MEXICANA+INSURGENTES SUR 975+ALCALDIA BENITO JUAREZ+CMX+03710+MX
```

### Notify2 targets

```text
seaHouseShipment[0].notify2.name1
seaHouseShipment[0].notify2.name2
seaHouseShipment[0].notify2.address.location1
seaHouseShipment[0].notify2.address.location2
seaHouseShipment[0].notify2.address.zipCode
seaHouseShipment[0].notify2.address.street
seaHouseShipment[0].notify2.address.country.countryID
seaHouseShipment[0].notify2.address.country.countryName
seaHouseShipment[0].notify2.address.state
```

### Contact details

Phone numbers and email addresses remain at Sea House Shipment level:

```text
seaHouseShipment[0].phoneNumberNotify1
seaHouseShipment[0].phoneNumberNotify2
seaHouseShipment[0].phoneNumberNotify3
seaHouseShipment[0].emailNotify1
seaHouseShipment[0].emailNotify2
seaHouseShipment[0].emailNotify3
```

Notify2 contact details must use the same grouping and parsing logic as Notify1, but write to the Notify2 phone and email fields.

---

## 15. Add Party TAX ID

### Source example

```edifact
NAD+N2+BME8109104S6:167+CIUDAD DE LOS DEPORTES+BASF MEXICANA+INSURGENTES SUR 975+ALCALDIA BENITO JUAREZ+CMX+03710+MX
```

### Qualifier rule

Map the party identifier as a TAX ID only when its identifier qualifier is `167`:

```text
BME8109104S6:167
```

If the identifier qualifier is not `167`, do not populate a TAX ID field from that identifier.

### Party targets

```text
Shipper   -> seaHouseShipment[0].shipperTAXID
Consignee -> seaHouseShipment[0].consigneeTAXID
Notify1   -> seaHouseShipment[0].notify1TAXID
Notify2   -> seaHouseShipment[0].notify2TAXID
Notify3   -> seaHouseShipment[0].notify3TAXID
```

The existing party qualifier mapping determines the applicable party role.

### Notify2 example

```text
BME8109104S6 -> seaHouseShipment[0].notify2TAXID
```

---

## 16. Remove Existing Scenario Mapping

The existing mapping that sets the Scenario field to `BASF FCL` must be removed.

### Previous behaviour

```text
Scenario = BASF FCL
```

### Required behaviour

- Do not populate the Scenario field from the BASF IFTMIN integration.
- Remove or disable the existing logic that assigns `BASF FCL`.

---

## 17. Mapping Summary

| Change type | Topic | EDIFACT source / condition | Required target or action |
|---|---|---|---|
| Change existing | Customer Lloyds | TDT vessel identification | Existing BASF Customer Lloyds UDF, not the standard CarLo Vessel field. |
| Change existing | Customer Vessel | TDT vessel identification/name | Existing BASF Customer Vessel UDF, not the standard CarLo Vessel field. |
| Change existing | Customer Voyage | Applicable TDT value | Existing BASF Customer Voyage UDF, not the standard CarLo Voyage field. |
| Change existing | Customer POL | `LOC+5` | Existing BASF Customer POL UDF, not the standard CarLo POL field. |
| Change existing | Customer POD | `LOC+12` | Existing BASF Customer POD UDF, not the standard CarLo POD field. |
| Change existing | Place of Delivery | `LOC+20` | Existing BASF Customer Place of Delivery UDF, not the standard CarLo field. |
| Add | Booking Number | First `RFF+BN` | `master.externalReferences[0].value`, with `referenceType = 9`. |
| Add | Letter of Credit | `RFF+LC` | `seaHouseShipment[0].lCNumber`. |
| Add | ACID | `RFF+ABT` | `seaHouseShipment[0].aCIDNumber`. |
| Add without replacing existing | DG Quantity | GID package quantity plus applicable DGS under same GID | `cargo[n].dangerousGoods[0].quantity`. Retain `cargo[n].totalNumberOfPackages`. |
| Add without replacing existing | DG Packaging | GID package code plus applicable DGS under same GID | `cargo[n].dangerousGoods[0].packaging.matchcode`. Retain `cargo[n].packaging.matchcode`. |
| Add | VGM | Applicable BASF VGM segment | `container[n].verifiedGrossMass`. |
| Add | VGM Signature | `NAD+AM` | Apply to `container[n].vgmVerificationSignature` for all containers. |
| Add | Notify2 | `NAD+N2` | Same logic as Notify1, using `notify2` and Notify2 contact fields. |
| Add | Party TAX ID | NAD identifier qualifier `167` | Corresponding Shipper, Consignee, Notify1, Notify2, or Notify3 TAX ID field. |
| Remove | Scenario | Existing constant `BASF FCL` | Do not populate the field. |

---

## 18. Validation References

The supplied BASF messages can be used as test inputs:

- ML `2800209952`: one container with multiple GID goods items and dangerous-goods data.
- ML `2800244245`: Egypt shipment containing structured `RFF+ABT` ACID data.
- ML `2800245098`: Abschlussinfo containing repeated `RFF+BN`, VGM data, and `NAD+AM` signature data.

Values from these examples must not be hardcoded.

---

## 19. Change History

| Version | Date | Description |
|---|---|---|
| 1.0 | 2026-09-11 | Initial consolidated specification. |
| 1.1 | 2026-09-11 | Clarified that Customer Lloyds, Vessel, Voyage, POL, POD, and Place of Delivery must use existing BASF UDF fields. Clarified that dangerous-goods package fields are additional and do not replace existing cargo mappings. |
