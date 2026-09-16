"""Generate docs/carlo/02..05 from the CarLo OpenAPI document.

    python tools/carlo_docs.py                 # fetch the live contract and regenerate
    python tools/carlo_docs.py path/to.json    # regenerate from a saved document

02 and 03 are prose with a generated field table spliced in; 04 and 05 are wholly generated.
01, 06, 07 and the README are hand-written - most of what they say is behaviour the OpenAPI
document does not describe - so this script never touches them.

Re-run whenever the contract is regenerated server-side. CarLo drops fields it does not
recognise without a word, so a field this repo renames silently stops being populated.
"""

import json
import os
import re
import ssl
import sys
import urllib.request

SPEC_URL = ('https://api-carlo-test.fracht.be:4712'
            '/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json')
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', 'carlo')
BASE = '/api/PolytraSeafreightHouseShipment_BASF/v3'


def load_spec(arg=None):
    """The contract, from a local file if one is named, else off the test host.

    The test host's certificate does not chain to a public root, hence the unverified
    context - the same reason every curl in these docs carries -k.
    """
    if arg:
        return json.load(open(arg, encoding='utf-8'))
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(SPEC_URL, context=ctx, timeout=60) as r:
        return json.loads(r.read().decode('utf-8'))


spec = load_spec(sys.argv[1] if len(sys.argv) > 1 else None)
SCH = spec['components']['schemas']

def rootitem(name):
    rb = spec['components']['requestBodies'][name]
    key = name[0].lower() + name[1:]
    return rb['content']['application/json']['schema']['properties'][key]['items']

ROOT = {'SeaHouseShipment': rootitem('SeaHouseShipment'),
        'ShipmentCargo':    rootitem('ShipmentCargo')}

# ---------------------------------------------------------------- type rendering
def typestr(v, link=True):
    def ref(n):
        return f'[`{n}`](04-schemas.md#{n.lower()})' if link else f'`{n}`'
    if '$ref' in v:
        return ref(v['$ref'].split('/')[-1])
    if 'oneOf' in v or 'anyOf' in v:
        parts = [x.get('type','?') for x in (v.get('oneOf') or v.get('anyOf'))]
        return '`' + ' \| '.join(parts) + '`'
    t = v.get('type', '?')
    if t == 'array':
        return 'array of ' + typestr(v.get('items', {}), link)
    if t == 'object' and 'properties' not in v:
        return '`number`'          # quantity/measure fields — see the note in each page
    if t == 'object':
        return '`object`'
    f = v.get('format')
    if f == 'date':      return '`date`'
    if f == 'date-time': return '`date-time`'
    if f in ('int32','int64'): return '`integer`'
    return f'`{t}`'

def limit(v):
    if 'maxLength' in v:
        return str(v['maxLength']) if v['maxLength'] else '0 *(unused)*'
    return ''

def desc(v):
    d = re.sub(r'\s+', ' ', (v.get('description') or '').strip())
    if d == '-':
        return ''
    # the generator that produced this swagger stripped <see cref> refs and left the
    # sentences dangling: "Gets or sets the ." / "whether this  is active."
    d = re.sub(r'Gets or sets the \.\s*', '', d)
    d = re.sub(r'^Gets or sets (a value indicating )?', '', d)
    d = re.sub(r'^Gets ', '', d)
    d = re.sub(r'\s{2,}', ' ', d)
    d = d.replace('|', '\|').strip()
    return (d[0].upper() + d[1:]) if d else ''

def fieldtable(sch, link=True, skip_action=True):
    req = set(sch.get('required', []))
    rows = []
    for k, v in (sch.get('properties') or {}).items():
        if skip_action and k == 'actionAttribute':
            continue
        rows.append('| `%s` | %s | %s | %s | %s |' % (
            k, typestr(v, link), 'yes' if k in req else '',
            limit(v), desc(v)))
    if not rows:
        return '*No fields other than `actionAttribute`.*\n'
    return ('| Field | Type | Req | Max | Notes |\n|---|---|:-:|--:|---|\n'
            + '\n'.join(rows) + '\n')


# ---------------------------------------------------------------- 04-schemas.md
order = sorted(SCH)
body = []
body.append("""# Component schemas — `PolytraSeafreightHouseShipment_BASF` v3

Every nested object type reachable from [`seaHouseShipment`](02-seahouseshipment.md) or
[`shipmentCargo`](03-shipmentcargo.md). Generated from
`/docs/PolytraSeafreightHouseShipment_BASF-v3/docs.json`.

`actionAttribute` is omitted from every table — it is present on all of these types and means the
same thing everywhere; see [§ actionAttribute](01-calling-the-api.md#actionattribute).

**Req** marks a field the contract declares required *for that object*, which only bites when the
object itself is present. **Max** is `maxLength`; a `0` there is the swagger's way of saying the
property is generated and not writable.

Fields typed `number` below are declared `type: object` with no properties in the swagger. They
are CarLo quantities and go on the wire as **plain JSON numbers** — see
[§ Quantities](01-calling-the-api.md#quantities).

---
""")
for n in order:
    s = SCH[n]
    body.append(f'## {n}\n')
    d = (s.get('description') or '').strip()
    if d:
        body.append(re.sub(r'\s+', ' ', d) + '\n')
    body.append(fieldtable(s))
    body.append('')
open(os.path.join(OUT, '04-schemas.md'), 'w', encoding='utf-8').write('\n'.join(body))
print('wrote 04-schemas.md')

# ---------------------------------------------------------------- filters
def filtertable(path):
    op = spec['paths'][path]['get']
    prm = next(p for p in op['parameters'] if p['name'] == '$filter')
    seen = {}
    for name, ex in prm['examples'].items():
        if name == '<Choose Filter Sample>':
            continue
        base = re.sub(r'_(startswith|endswith|contains)$', '', name)
        val  = ex['value']
        ids  = re.findall(r'\b(\d{5,})\b', val)
        e = seen.setdefault(base, {'ids': ids, 'ops': set(), 'sample': val})
        e['ops'].add('eq' if base == name else name.rsplit('_', 1)[-1])
        if base == name:
            e['sample'] = val
    rows = []
    for k, v in seen.items():
        ops = sorted(v['ops'])
        ops = ['eq'] + [o for o in ops if o != 'eq'] if 'eq' in ops else ops
        rows.append('| `%s` | %s | %s | `%s` |' % (
            k, ' / '.join(f'`{i}`' for i in v['ids']),
            ', '.join(f'`{o}`' for o in ops),
            v['sample'].replace('|', '\|')))
    return ('| Property | Id | Operators | Example |\n|---|---|---|---|\n'
            + '\n'.join(rows) + '\n'), len(seen)

t_sea, n_sea = filtertable('/api/PolytraSeafreightHouseShipment_BASF/v3/SeaHouseShipment/{id}')
t_car, n_car = filtertable('/api/PolytraSeafreightHouseShipment_BASF/v3/ShipmentCargo/{id}')

open(os.path.join(OUT, '05-filter-properties.md'), 'w', encoding='utf-8').write(f"""# `$filter` property ids

CarLo's OData-ish filter addresses fields by **numeric property id**, never by name:
`$filter=700071 eq '2800209301'` filters on `customerReference`. The ids below are the complete
set the v3 contract advertises as filterable — {n_sea} on `SeaHouseShipment`, {n_car} on
`ShipmentCargo`. A field not in these tables cannot be filtered on, even though it exists on the
object.

Read [§ $filter](01-calling-the-api.md#4-filter) first for the encoding rules — getting the
space encoding wrong is an HTTP 500, not a 400.

Two ids separated by `/` (e.g. `186062/5765907`) are the swagger's own example and mean the
property is reachable by either id; use the first.

A `_Range` row is a pair: the property has a *from* id and a *to* id one higher, and you combine
them with `ge` / `le`. The plain (non-range) id matches a single exact value.

## SeaHouseShipment

{t_sea}
## ShipmentCargo

{t_car}""")
print('wrote 05-filter-properties.md')


sea = ROOT['SeaHouseShipment']
req = ', '.join('`%s`' % r for r in sea['required'])

DOC02 = """# `SeaHouseShipment` — the house shipment (dossier)

A CarLo **house shipment** is one dossier: one bill of lading's worth of a booking, with its
master shipment, containers, cargo lines and road carriages hanging off it. This is the resource
the IFTMIN and IFTMBF mappings write.

```
POST   BASE/SeaHouseShipment
GET    BASE/SeaHouseShipment/{id}
PUT    BASE/SeaHouseShipment/{id}
DELETE BASE/SeaHouseShipment/{id}
```

The body is **always** an array under a `seaHouseShipment` key, on POST and PUT alike, and the
GET response comes back the same way:

```json
{ "seaHouseShipment": [ { "...": "one dossier" } ] }
```

One request can carry many dossiers. That is what makes a BASF master-sub order a single call:
each bill of lading is its own entry in the array. See
[batching](01-calling-the-api.md#writing-several-records-in-one-call).

## Required fields

REQFIELDS

The contract enforces these on a create. On an `update` — or an `updateorcreate` that resolves to
an existing record — CarLo merges what you send into the stored dossier, so an update need not
restate them. On a create, omitting one is a `400` carrying a validation message, not a silent
default.

`master` being required means **every** house shipment carries a
[`SeaMasterShipment`](04-schemas.md#seamastershipment), even a stand-alone one; its own
`deliveryTerms` is required in turn.

## Fields

SEATABLE
## Values the contract does not enumerate

The swagger types `movementType`, `houseType`, `loadType`, `deliveryTerms`, `lockStatus`,
`incoterms` and their neighbours as bare `string` with no `enum`, but CarLo validates them
against its own enum members and rejects anything else. These are the values attested by live GET
responses from the test system and by this repo's captures in `docs/get-responses/`:

| Field | Observed values |
|---|---|
| `preferredModeOfTransport` | `Ocean` |
| `movementType` | `P/P`, `D/P`, `D/D` |
| `houseType` | `House`, `BackToBack`; `Coloadin` per BASF's flow document, not yet seen in a response |
| `loadType` | `FCL`, `LCL`, `GC` |
| `incoterms` | `CIF`, `CIP`, `CFR` — ISO Incoterm codes |
| `deliveryTerms` | `Prepaid` |
| `lockStatus` | `Free`, `Consolidated` |
| `isInRecycleBin` | `true` / `false` |
| `carriage[].purpose` | `PickUpContainerForExportTerminal`, `DeliveryFromImportTerminal` |
| `carriage[].section` | `PreCarriage`, `OnCarriage` |
| `carriage[].transportMode` | `Container`, `Road` |
| `container[].containerNumberType` | `Known`, `Unknown` |
| `container[].vgmWeightDeterminationMethod` | `SM2` |
| `container[].vgmState` | `NotSent` |
| `container[].ventSetting`, `container[].drainage` | `None` |
| `externalReferenc[].referenceType` | `9` — numeric member |
| `shipmentBaseTasks[].state` | `0`, `1` — numeric member |
| `master.shippingInstructions.billOfLadingKind` | `1` — numeric member |
| `customer.inttraRefType` | `InttraCompanyId`, `0` |
| `*.addresses[].businessPartnerAddressType` | `Default` |

`houseType: "Coloadin"` is spelled that way — one word, lower-case `in` — even though BASF's
flow document writes it "Co-load in". It is the only value in the table above that no live
response has confirmed, so it is the one to check first if an LCL master-sub is rejected.

Fields typed `string | integer` in the table above take either the enum member's name or its
numeric value. Prefer the name wherever one is attested: a number out of range is accepted
silently and stores nonsense.

`isInRecycleBin` is how a dossier is withdrawn. Setting it `true` and upserting keeps the record
in CarLo but drops it out of every later `$filter` result — which is why the lookup in
[06-dossier-lookup.md](06-dossier-lookup.md) also filters recycled records out client-side.

## Addressing an existing dossier

`POST` with `actionAttribute: "updateorcreate"` keys on the record's natural identity, which for
BASF is `customerReference`. A master-sub order, where several dossiers share one
`customerReference`, therefore cannot be addressed that way — the last entry in the array wins.
To update one specific dossier you need its `id`, and for that you need a lookup:
[06-dossier-lookup.md](06-dossier-lookup.md).

## Related

- [`ShipmentCargo`](03-shipmentcargo.md) — the cargo lines, writable standalone as well as nested
  here under `cargo`
- [04-schemas.md](04-schemas.md) — every nested type
- [05-filter-properties.md](05-filter-properties.md#seahouseshipment) — the 71 filterable
  properties
"""

DOC02 = DOC02.replace('BASE', BASE).replace('REQFIELDS', req).replace('SEATABLE', fieldtable(sea))
open(os.path.join(OUT, '02-seahouseshipment.md'), 'w', encoding='utf-8').write(DOC02)
print('wrote 02')

car = ROOT['ShipmentCargo']
creq = ', '.join('`%s`' % r for r in car['required'])

DOC03 = """# `ShipmentCargo` — the cargo line

One cargo line of a house shipment: a goods position with its packaging, weights, HS code,
dangerous-goods data and the container it sits in. This is the resource the IFCSUM mapping writes.

```
POST   BASE/ShipmentCargo
GET    BASE/ShipmentCargo/{id}
PUT    BASE/ShipmentCargo/{id}
DELETE BASE/ShipmentCargo/{id}
```

Body and response are an array under a `shipmentCargo` key:

```json
{ "shipmentCargo": [ { "...": "one cargo line" } ] }
```

## Two ways to write a cargo line

A cargo line reaches CarLo either **nested** inside a house shipment
(`seaHouseShipment[].cargo[]`, the same [`ShipmentCargo`](04-schemas.md#shipmentcargo) type) or
**standalone** through this endpoint. They are not interchangeable:

- Nested, on a create, is how a line comes into existence along with its dossier.
- Standalone is how you amend a line that already exists — adding a VGM, an MRN, a container
  assignment — without resending the whole dossier.

Standalone has no usable create path: nothing on `shipmentCargo` names the parent dossier, so a
line posted here can only be *matched* against one already stored, by `deliveryNoteSAP` /
`eDIID` / `itemNumber`. An `updateorcreate` whose match fails adds an orphan line rather than
failing, so send `actionAttribute: "update"` on this endpoint.

## Required fields

CARGOREQ — the position number within its shipment. It is the only required field, and it is part
of what an `update` matches on, together with the delivery-note reference.

## Fields

CARGOTABLE
## Notes

`hSCode` (a free string) and `harmonizedSystemCodes` (references into CarLo's HS-code master
data) are different fields. The string takes whatever the message carried; the array resolves
only against codes that exist in CarLo, and a `matchcode` that does not is a validation error.

`dangerousGoods[]` is an array — one entry per UN number on the line — of
[`ShipmentCargoDangerousGoodsData`](04-schemas.md#shipmentcargodangerousgoodsdata). Its swagger
description, *"Bei Klasse1 wird das Explosivgewicht als Nettogewicht interpretiert"*, means: for
class 1 (explosives) `netWeight` is read as the explosive weight, not the net mass.

`container` is a **single** [`ShipmentContainer`](04-schemas.md#shipmentcontainer), not an array -
a cargo line sits in one container. `sequenceNumber` is required on it and is what ties the line
to the container of the same sequence on the dossier. Get it wrong and CarLo adds a second
container instead of matching the existing one.

Weight, volume and count fields are plain numbers on the wire despite the swagger's
`type: object` — see [quantities](01-calling-the-api.md#quantities).

## Related

- [`SeaHouseShipment`](02-seahouseshipment.md) — the dossier these lines belong to
- [05-filter-properties.md](05-filter-properties.md#shipmentcargo) — the 21 filterable properties
"""

DOC03 = DOC03.replace('BASE', BASE).replace('CARGOREQ', creq).replace('CARGOTABLE', fieldtable(car))
open(os.path.join(OUT, '03-shipmentcargo.md'), 'w', encoding='utf-8').write(DOC03)
print('wrote 03')
