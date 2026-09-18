#!/usr/bin/env python3
"""Convert raw BASF EDIFACT interchanges into the JSON shape the Fracht Connect EDI
parser hands to the DataWeave mappings.

The mappings never see EDIFACT - they receive the parsed JSON. This script reproduces
that parse so the example interchanges in docs/example-orders/inbound can be used as test
fixtures.

Output shape (verified against two real parser captures, see FIDELITY below):

    { "EDI": { "Errors": [], "Delimiters": "+: '?",
               "Messages": { "<dir>": { "<TYPE>": [ <message>, ... ] } },
               "FunctionalAcksReceived": [], "FunctionalAcksGenerated": [] } }

Each message is
    { "Interchange": {UNB..}, "MessageHeader": {UNH..}, "Id": "IFTMIN",
      "Name": "Instruction message", "Heading": { <positioned segments/groups> } }

Segment and group keys carry the message-structure position the parser prefixes them
with ("0020_BGM", "0890_Segment_group_18"). Element keys are "<TAG><ee>" for simple
data elements and "<TAG><ee><cc>" for components of a composite; empty components are
omitted; numeric data elements become JSON numbers with trailing zeros dropped.

FIDELITY
--------
All three structures were derived from real parser output. The captures are stored under
docs/example-orders/inbound with misleading extensions - go by content, not by filename:

    IFTMIN D99A   fcl/2800209301_FCL_IFTMIN_ERST_9.json
    IFTMBF D08A   fcl/2013357254_IFCSUM.txt              (an IFTMBF capture)
    IFCSUM D08A   fcl/TRS-000001_30062026_*.xml          (three IFCSUM captures)

Re-parsing the matching source interchange reproduces each capture exactly, with one
class of exception: where a capture stores U+FFFD, its own save lost a non-ASCII
character that the source still carries, and this script emits the faithful value.
Verified differences - IFTMIN 0, IFTMBF 11 (all U+FFFD), IFCSUM 0 and 1 (U+FFFD).

Positions marked ESTIMATED were not exercised by any capture and are reconstructed from
the UN/EDIFACT branching diagrams. They cannot affect mapping correctness: all three
mappings navigate by the "_<SEGMENT>" key suffix and by group nesting, never by the
numeric position. Repeat limits are deliberately permissive - the directory maxima are
not modelled, and segment tags decide placement, not counts.

Usage:
    python tools/edifact_to_json.py <in.txt> [<out.json>]
    python tools/edifact_to_json.py --all        # convert every example order
"""

from __future__ import annotations

import json
import os
import re
import sys
from decimal import Decimal, InvalidOperation

# --------------------------------------------------------------------------------------
# Encoding
# --------------------------------------------------------------------------------------

def read_message_text(path: str) -> str:
    """Read an interchange the way the production parser sees it.

    BASF sends UTF-8 on the wire and the parser decodes it as latin-1, so real parser
    output carries mojibake: "40<C2><B4> Reefer" where the message said "40' Reefer".
    Reproducing that is what makes these fixtures match what the mappings receive.

    The captures in docs/example-orders/inbound were saved in two different encodings, so the
    wire form has to be recovered before the mojibake step: a capture that decodes as
    UTF-8 already *is* the wire form, while one that does not was re-saved as CP1252 and
    has to be encoded back to UTF-8 first.

    Verified: this reproduces docs/example-orders/inbound/fcl/2800209301_FCL_IFTMIN_ERST_9.json
    exactly (0 differences over the whole document).
    """
    raw = open(path, "rb").read()
    try:
        raw.decode("utf-8")
        wire = raw
    except UnicodeDecodeError:
        wire = raw.decode("cp1252").encode("utf-8")
    return wire.decode("latin-1")


# --------------------------------------------------------------------------------------
# Tokenizer
# --------------------------------------------------------------------------------------

SEG_TERM, ELEM_SEP, COMP_SEP, RELEASE, DECIMAL = "'", "+", ":", "?", "."


def split_unescaped(text: str, sep: str, consume_release: bool) -> list[str]:
    """Split on `sep`, honouring the EDIFACT release character.

    Splitting is two-phase - elements first, then components - so the release character
    must survive the element pass (`consume_release=False`) and only be stripped on the
    component pass. Consuming it too early turns "?:" into a real separator and shreds
    every free-text segment that contains a colon.
    """
    parts, buf, i = [], [], 0
    while i < len(text):
        ch = text[i]
        if ch == RELEASE and i + 1 < len(text):
            if not consume_release:
                buf.append(ch)
            buf.append(text[i + 1])
            i += 2
            continue
        if ch == sep:
            parts.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    parts.append("".join(buf))
    return parts


def split_segments(text: str) -> list[str]:
    """Split an interchange into segment strings.

    Two on-the-wire flavours occur in the captures: apostrophe-terminated (a single
    line) and newline-terminated (the apostrophes replaced by CRLF). In the newline
    flavour an escaped apostrophe in data ("?'", as in "4 quai d?'Arenc") survives as a
    trailing "?" before the line break, so a line ending in an unconsumed release
    character continues onto the next line with a literal apostrophe. The production
    parser rejects those messages; handling it here keeps the affected captures usable.

    A few captures went one save further and turned that line break into a space, leaving
    "4 quai d? Arenc". That is a released space by the rules, and it is read as one - the
    apostrophe is simply gone from those files. Nothing is inferred back: the intact copies
    of the same messages are in the example set too, and the affected value (a carrier's
    street address) is not mapped.
    """
    text = text.lstrip("﻿")
    if text.startswith("UNA"):
        text = text[9:]

    if text.count(SEG_TERM) >= 3:
        body = text.replace("\r", "").replace("\n", "")
        return [s for s in split_on_terminator(body) if s.strip()]

    out, pending = [], ""
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if not line.strip() and not pending:
            continue
        candidate = pending + line
        if trailing_release_count(candidate) % 2 == 1:
            pending = candidate[:-1] + RELEASE + SEG_TERM
            continue
        pending = ""
        if candidate.strip():
            out.append(candidate)
    if pending.strip():
        out.append(pending)
    return out


def trailing_release_count(s: str) -> int:
    n = 0
    while n < len(s) and s[len(s) - 1 - n] == RELEASE:
        n += 1
    return n


def split_on_terminator(body: str) -> list[str]:
    segs, buf, i = [], [], 0
    while i < len(body):
        ch = body[i]
        if ch == RELEASE and i + 1 < len(body):
            buf.append(ch)
            buf.append(body[i + 1])
            i += 2
            continue
        if ch == SEG_TERM:
            segs.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    if buf:
        segs.append("".join(buf))
    return segs


# --------------------------------------------------------------------------------------
# Segment definitions
#
# Per segment tag: an ordered list of data elements. "C" = composite (keys get a
# component suffix), "S" = simple (no component suffix, first component only).
# Compositeness was derived from the two real parser captures where observed; the rest
# follows the UN/EDIFACT service directory.
# --------------------------------------------------------------------------------------

BASE_SEGMENTS: dict[str, str] = {
    #        01 02 03 04 05 06 07 08 09 10 11 12 13
    "BGM": "C  C  S  S",
    "CNI": "S  C  S",
    "CNT": "C",
    "COM": "C",
    "CTA": "S  C",
    "DGS": "S  C  C  C  S  S  S  S  C  C  S  S  S",
    "DOC": "C  C  S  S  S",
    "DTM": "C",
    "EQD": "S  C  C  S  S  S",
    "EQN": "C",
    "FTX": "S  S  C  C  S  S",
    "GID": "S  C  C  C  C",
    "LOC": "S  C  C  C  S",
    "MEA": "S  C  C  S",
    "NAD": "S  C  C  C  C  S  C  S  S  C",
    "PCI": "S  C  S  C",
    "PIA": "S  C  C  C  C",
    "QTY": "C",
    "RFF": "C",
    "RNG": "S  C",
    "SEL": "S  C  S  C",
    "SGP": "C  S",
    "STS": "C  C  C  C",
    "TCC": "C  C  C  C",
    "TDT": "S  S  C  C  C  S  C  C  S",
    "TMD": "C  S  S",
    "TSR": "C  C  C  C",
    "UNB": "C  C  C  C  S  C  S  S  S  S  S",
    "UNH": "S  C  S  C  C  C  C",
}

# Per-directory overrides. The parser follows the directory it was handed, and two
# elements genuinely changed shape between D99A and D08A:
#
#   NAD07  D99A = 3229 Country sub-entity identification  (simple)
#          D08A = C819 COUNTRY SUB-ENTITY DETAILS         (composite)
#   COM01  D99A = C076 COMMUNICATION CONTACT, M 1         (composite, flat keys)
#          D08A = C076 COMMUNICATION CONTACT, M 9         (repeating composite)
#
# A repeating composite is rendered by the parser as an array of objects keyed by the
# composite's own component codes - COM01: [{"C07601": "...", "C07602": "TE"}] - not as
# the flat COM0101/COM0102 pair D99A produces. "R:C076" encodes that.
DIRECTORY_SEGMENTS: dict[str, dict[str, str]] = {
    "D99A": {
        "NAD": "S  C  C  C  C  S  S  S  S  C",
    },
    "D08A": {
        "NAD": "S  C  C  C  C  S  C  S  S  C",
        "COM": "R:C076",
    },
}


def layout_for(directory: str, tag: str) -> list[str]:
    override = DIRECTORY_SEGMENTS.get(directory, {}).get(tag)
    return (override if override is not None else BASE_SEGMENTS.get(tag, "")).split()

# Data elements the directory types as numeric. The parser emits these as JSON numbers
# (trailing zeros dropped: "56463.000" -> 56463, "108.576" -> 108.576).
NUMERIC_KEYS = {
    "CNI01", "CNI03",
    "CNT0102",
    "DGS0301", "DGS0401",
    "DOC04", "DOC05",
    "EQN0101",
    "GID01", "GID0201", "GID0301", "GID0401", "GID0501",
    "QTY0102",
    "RNG0202", "RNG0203",
    "SGP02",
    "UNB0401", "UNB0402",
    "UNH0401",
}


def parse_segment(seg: str, directory: str) -> tuple[str, dict]:
    """Turn one segment string into (tag, {elementKey: value})."""
    elements = split_unescaped(seg, ELEM_SEP, consume_release=False)
    tag = elements[0].strip()
    kinds = layout_for(directory, tag)
    out: dict[str, object] = {}

    for idx, raw in enumerate(elements[1:], start=1):
        if raw == "":
            continue
        kind = kinds[idx - 1] if idx - 1 < len(kinds) else "C"
        # The parser right-trims every component (EDIFACT pads to the element width);
        # leading spaces are significant and kept.
        components = [c.rstrip() for c in split_unescaped(raw, COMP_SEP, consume_release=True)]
        key_base = f"{tag}{idx:02d}"

        if kind == "S":
            if components[0] != "":
                out[key_base] = coerce(key_base, components[0])
        elif kind.startswith("R:"):
            code = kind[2:]
            entry = {
                f"{code}{cidx:02d}": coerce(f"{code}{cidx:02d}", value)
                for cidx, value in enumerate(components, start=1)
                if value != ""
            }
            if entry:
                out.setdefault(key_base, []).append(entry)
        else:
            for cidx, value in enumerate(components, start=1):
                if value == "":
                    continue
                key = f"{key_base}{cidx:02d}"
                out[key] = coerce(key, value)
    return tag, out


def coerce(key: str, value: str):
    if key not in NUMERIC_KEYS:
        return value
    try:
        number = Decimal(value)
    except (InvalidOperation, ValueError):
        return value
    if number == number.to_integral_value():
        return int(number)
    return float(number)


# --------------------------------------------------------------------------------------
# Message structures
# --------------------------------------------------------------------------------------

class Seg:
    __slots__ = ("pos", "tag", "repeat")

    def __init__(self, pos: str, tag: str, repeat: int = 1):
        self.pos, self.tag, self.repeat = pos, tag, repeat

    @property
    def key(self) -> str:
        return f"{self.pos}_{self.tag}"

    @property
    def trigger(self) -> str:
        return self.tag


class Grp:
    __slots__ = ("pos", "number", "repeat", "children")

    def __init__(self, pos: str, number: int, repeat: int, children: list):
        self.pos, self.number, self.repeat, self.children = pos, number, repeat, children

    @property
    def key(self) -> str:
        return f"{self.pos}_Segment_group_{self.number}"

    @property
    def trigger(self) -> str:
        return self.children[0].trigger


# --- IFTMIN D99A -----------------------------------------------------------------------
# Positions verified against docs/example-orders/inbound/fcl/2800209301_FCL_IFTMIN_ERST_9.json,
# except those marked ESTIMATED.

IFTMIN_D99A = [
    Seg("0020", "BGM"),
    Seg("0030", "CTA"),
    Seg("0040", "COM", 999),
    Seg("0050", "DTM", 999),
    Seg("0060", "TSR", 999),                                    # ESTIMATED
    Seg("0090", "FTX", 999),
    Seg("0100", "CNT", 999),
    Grp("0110", 1, 999, [Seg("0120", "RFF"), Seg("0130", "DTM", 999)]),          # ESTIMATED
    Grp("0360", 7, 999, [Seg("0370", "TCC"), Seg("0450", "QTY", 999)]),
    Grp("0460", 8, 999, [
        Seg("0470", "TDT"),
        Seg("0480", "DTM", 999),
        Seg("0490", "TSR", 999),
        Grp("0500", 9, 999, [Seg("0510", "LOC"), Seg("0520", "DTM", 999)]),
        Grp("0530", 10, 999, [Seg("0540", "RFF"), Seg("0550", "DTM", 999)]),
    ]),
    Grp("0560", 11, 999, [
        Seg("0570", "NAD"),
        Seg("0580", "LOC", 999),                                # ESTIMATED
        Grp("0600", 12, 999, [Seg("0610", "CTA"), Seg("0620", "COM", 999)]),
        Grp("0630", 13, 999, [Seg("0640", "DOC"), Seg("0650", "DTM", 999)]),
    ]),
    Grp("0890", 18, 9999, [
        Seg("0900", "GID"),
        Seg("0910", "HAN", 999),                                # ESTIMATED
        Seg("0930", "RNG"),
        Seg("0940", "TMP", 999),                                # ESTIMATED
        Seg("0950", "LOC", 999),
        Seg("0960", "MOA", 999),                                # ESTIMATED
        Seg("0970", "PIA", 999),
        Seg("0980", "FTX", 999),
        Grp("1000", 19, 999, [Seg("1010", "NAD"), Seg("1020", "DTM", 999), Seg("1030", "LOC", 999)]),
        Grp("1050", 20, 999, [Seg("1060", "MEA")]),
        Grp("1070", 21, 999, [Seg("1080", "DIM")]),             # ESTIMATED
        Grp("1110", 22, 999, [Seg("1120", "RFF"), Seg("1130", "DTM", 999)]),
        Grp("1140", 23, 999, [Seg("1150", "PCI"), Seg("1160", "RFF", 999), Seg("1170", "DTM", 999)]),
        Grp("1360", 29, 999, [Seg("1370", "SGP")]),
        Grp("1500", 32, 999, [
            Seg("1510", "DGS"),
            Seg("1520", "FTX", 999),
            Grp("1530", 33, 999, [Seg("1540", "CTA"), Seg("1550", "COM", 999)]),
        ]),
    ]),
    Grp("1640", 37, 999, [
        Seg("1650", "EQD"),
        Seg("1660", "EQN"),
        Seg("1670", "TMD"),
        Seg("1680", "MEA", 999),
        Seg("1690", "DIM", 999),                                # ESTIMATED
        Seg("1700", "SEL", 999),                                # ESTIMATED
        Seg("1710", "TPL", 999),                                # ESTIMATED
        Seg("1720", "HAN", 999),                                # ESTIMATED
        Seg("1730", "TMP", 999),                                # ESTIMATED
        Seg("1740", "RNG", 999),                                # ESTIMATED
        Seg("1750", "FTX", 999),                                # ESTIMATED
        Grp("1760", 38, 999, [Seg("1770", "LOC"), Seg("1780", "DTM", 999)]),     # ESTIMATED
        Grp("1840", 39, 999, [
            Seg("1850", "NAD"),
            Seg("1860", "DTM", 999),                            # ESTIMATED
            Grp("1870", 40, 999, [Seg("1880", "CTA"), Seg("1890", "COM", 999)]),  # ESTIMATED
        ]),
    ]),
]

# --- IFTMBF D08A -----------------------------------------------------------------------
# Positions verified against docs/example-orders/inbound/fcl/2013357254_IFCSUM.txt (an IFTMBF
# capture despite the filename), except those marked ESTIMATED.

IFTMBF_D08A = [
    Seg("0020", "BGM"),
    Seg("0030", "CTA"),
    Seg("0040", "COM", 999),
    Seg("0050", "DTM", 999),
    Seg("0060", "TSR", 999),                                    # ESTIMATED
    Seg("0080", "FTX", 999),
    Seg("0090", "CNT", 999),
    Grp("0170", 3, 999, [Seg("0180", "RFF"), Seg("0190", "DTM", 999)]),
    Grp("0360", 7, 999, [
        Seg("0370", "TDT"),
        Seg("0380", "DTM", 999),
        Seg("0390", "TSR", 999),
        Grp("0400", 8, 999, [Seg("0410", "LOC"), Seg("0420", "DTM", 999)]),
    ]),
    Grp("0460", 10, 999, [
        Seg("0470", "NAD"),
        Seg("0480", "LOC", 999),                                # ESTIMATED
        Grp("0490", 11, 999, [Seg("0500", "CTA"), Seg("0510", "COM", 999)]),
    ]),
    Grp("0700", 16, 9999, [
        Seg("0710", "GID"),
        Seg("0740", "RNG"),
        Seg("0750", "LOC", 999),                                # ESTIMATED
        Seg("0780", "PIA", 999),
        Seg("0790", "FTX", 999),
        Grp("0800", 17, 999, [Seg("0810", "NAD"), Seg("0820", "LOC", 999)]),    # ESTIMATED
        Grp("0850", 18, 999, [Seg("0860", "MEA")]),
        Grp("0910", 20, 999, [Seg("0920", "RFF"), Seg("0930", "DTM", 999)]),
        Grp("0940", 21, 999, [Seg("0950", "PCI"), Seg("0960", "RFF", 999)]),    # ESTIMATED
        Grp("1070", 25, 999, [Seg("1080", "SGP")]),
        Grp("1120", 27, 999, [
            Seg("1130", "DGS"),
            Seg("1140", "FTX", 999),
            Grp("1150", 28, 999, [Seg("1160", "CTA"), Seg("1170", "COM", 999)]),
        ]),
    ]),
    Grp("1260", 32, 999, [
        Seg("1270", "EQD"),
        Seg("1280", "EQN"),
        Seg("1290", "TMD"),
        Seg("1300", "MEA", 999),                                # ESTIMATED
        Seg("1310", "DIM", 999),                                # ESTIMATED
        Seg("1320", "SEL", 999),                                # ESTIMATED
        Seg("1350", "FTX", 999),
        Grp("1370", 33, 999, [Seg("1380", "NAD"), Seg("1390", "DTM", 999)]),
    ]),
]

# --- IFCSUM D08A -----------------------------------------------------------------------
# Positions verified against the three real parser captures kept (despite their .xml
# extensions) at docs/example-orders/inbound/fcl/TRS-000001_30062026_*.xml, except those marked
# ESTIMATED.

IFCSUM_D08A = [
    Seg("0020", "BGM"),
    Seg("0030", "DTM", 99),
    Seg("0040", "TSR", 9),                                    # ESTIMATED
    Seg("0050", "FTX", 99),
    Seg("0060", "CNT", 9),                                    # ESTIMATED
    Grp("0090", 1, 99, [Seg("0100", "RFF"), Seg("0110", "DTM", 9)]),
    Grp("0210", 4, 999, [
        Seg("0220", "NAD"),
        Seg("0230", "LOC", 9),                                # ESTIMATED
    ]),
    Grp("0420", 9, 999, [
        Seg("0430", "TDT"),
        Seg("0440", "DTM", 9),                                # ESTIMATED
        Grp("0680", 16, 99, [Seg("0690", "RFF"), Seg("0700", "DTM", 9)]),
        Grp("0710", 17, 999, [
            Seg("0720", "NAD"),
            Seg("0730", "LOC", 9),                            # ESTIMATED
            Grp("0740", 18, 99, [Seg("0750", "CTA"), Seg("0760", "COM", 9)]),
        ]),
    ]),
    Grp("0910", 22, 999, [
        Seg("0920", "EQD"),
        Seg("0930", "EQN"),
        Seg("0960", "MEA", 99),
        Seg("0980", "SEL", 99),
        Seg("0990", "NAD", 99),
        Seg("1030", "FTX", 99),
    ]),
    Grp("1150", 26, 9999, [
        Seg("1160", "CNI"),
        Grp("1430", 33, 99, [Seg("1440", "RFF"), Seg("1450", "DTM", 9)]),
        Grp("2260", 51, 9999, [
            Seg("2270", "GID"),
            Seg("2280", "FTX", 99),                           # ESTIMATED
            Grp("2470", 55, 99, [Seg("2480", "RFF"), Seg("2490", "DTM", 9)]),
        ]),
    ]),
]

# --- IFTSTA D96A -----------------------------------------------------------------------
# The one OUTBOUND structure: Carlo raises a shipment-change event, OutboundIftsta.dwl builds
# this shape, and Fracht Connect serialises it to EDIFACT. Parsing the approved messages under
# docs/example-orders/outbound/iftsta/basf back into it is what gives the mapping suite an
# expectation it did not write itself.
#
# RECONSTRUCTED, not verified - no parser capture of an IFTSTA exists. Two things constrain it
# and neither is proof:
#
#   - It consumes all 14 approved messages with nothing left over. `build_message` raises
#     Unplaceable on a leftover segment, so a structure that is merely plausible fails loudly;
#     this one does not. That makes the nesting self-consistent with the messages.
#   - The TDT group carries a nested LOC+DTM group, which is how IFTMIN SG8/SG9, IFTMBF SG7/SG8
#     and IFCSUM SG9 all model carriage in this file.
#
# The consequence worth knowing: because EDIFACT parsing is a left-to-right structural walk and
# the messages put both LOC segments before all four voyage dates, DTM+133/186/132/178 land
# under the *second* SG7 repeat - the arrival port - not the departure one. That is what the
# grammar says, not a statement about which port the dates describe.
#
# See docs/iftsta/01-IFTSTA_mapping_spec.md §10.1. Positions and group numbers must be
# confirmed against a captured outbound envelope before go-live.

IFTSTA_D96A = [
    Seg("0020", "BGM"),
    Seg("0030", "DTM", 9),
    Seg("0040", "TSR", 9),
    Seg("0050", "FTX", 9),                                      # ESTIMATED
    Seg("0060", "CNT", 9),                                      # ESTIMATED
    Grp("0070", 1, 9, [Seg("0080", "RFF"), Seg("0090", "DTM", 9)]),
    Grp("0100", 2, 9, [                                         # ESTIMATED
        Seg("0110", "NAD"),
        Grp("0120", 3, 9, [Seg("0130", "CTA"), Seg("0140", "COM", 9)]),
    ]),
    Grp("0150", 4, 9999, [
        Seg("0160", "CNI"),
        Grp("0170", 5, 9, [
            Seg("0180", "STS"),
            Seg("0190", "RFF", 9),
            Seg("0200", "DTM", 9),
            Seg("0210", "FTX", 9),                              # ESTIMATED
            Grp("0220", 6, 9, [
                Seg("0230", "TDT"),
                Seg("0240", "DTM", 9),
                Grp("0250", 7, 9, [Seg("0260", "LOC"), Seg("0270", "DTM", 9)]),
            ]),
            Grp("0280", 8, 999, [
                Seg("0290", "EQD"),
                Seg("0300", "MEA", 9),                          # ESTIMATED
                Seg("0310", "SEL", 9),                          # ESTIMATED
            ]),
        ]),
    ]),
]

STRUCTURES = {
    ("IFTMIN", "D99A"): IFTMIN_D99A,
    ("IFTMBF", "D08A"): IFTMBF_D08A,
    ("IFCSUM", "D08A"): IFCSUM_D08A,
    ("IFTSTA", "D96A"): IFTSTA_D96A,
}

MESSAGE_NAMES = {
    "IFTMIN": "Instruction message",
    "IFTMBF": "Firm booking message",
    "IFCSUM": "Forwarding and consolidation summary message",
    "IFTSTA": "International multimodal status report message",
}


# --------------------------------------------------------------------------------------
# Structure-driven build
# --------------------------------------------------------------------------------------

class Unplaceable(Exception):
    pass


def build_level(items: list, segs: list[tuple[str, dict]], i: int, out: dict) -> int:
    """Consume segments from `segs` starting at `i` according to `items`.

    EDIFACT structures are ordered, so a single left-to-right pass suffices: for each
    item in turn, consume as many consecutive repeats as match. Returns the index of the
    first segment this level could not consume.
    """
    for item in items:
        count = 0
        while i < len(segs) and count < item.repeat:
            tag = segs[i][0]
            if tag != item.trigger:
                break
            if isinstance(item, Seg):
                value = segs[i][1]
                i += 1
            else:
                child: dict = {}
                start = i
                i = build_level(item.children, segs, i, child)
                if i == start:
                    break
                value = child
            count += 1
            if item.repeat == 1:
                out[item.key] = value
            else:
                out.setdefault(item.key, []).append(value)
    return i


def build_message(msg_type: str, version: str, unh: dict, unb: dict,
                  segs: list[tuple[str, dict]]) -> dict:
    structure = STRUCTURES.get((msg_type, version))
    if structure is None:
        raise Unplaceable(f"no structure defined for {msg_type} {version}")

    heading: dict = {}
    consumed = build_level(structure, segs, 0, heading)
    if consumed != len(segs):
        raise Unplaceable(
            f"{msg_type} {version}: could not place segment #{consumed + 1} "
            f"({segs[consumed][0]}) - extend the structure table"
        )
    return {
        "Interchange": unb,
        "Heading": heading,
        "Id": msg_type,
        "MessageHeader": unh,
        "Name": MESSAGE_NAMES.get(msg_type, msg_type),
    }


# --------------------------------------------------------------------------------------
# Interchange walk
# --------------------------------------------------------------------------------------

def convert(path: str) -> dict:
    segments = split_segments(read_message_text(path))

    unb: dict = {}
    messages: dict[str, dict[str, list]] = {}
    i = 0
    while i < len(segments):
        tag = segments[i][:3]
        if tag == "UNB":
            unb = parse_segment(segments[i], "")[1]
            i += 1
            continue
        if tag != "UNH":
            i += 1
            continue

        # The directory is only known once UNH is read, and it decides how the segments
        # that follow are shaped (see DIRECTORY_SEGMENTS), so the body is parsed lazily.
        unh = parse_segment(segments[i], "")[1]
        msg_type = unh.get("UNH0201", "")
        version = f"{unh.get('UNH0202', '')}{unh.get('UNH0203', '')}"
        body, i = [], i + 1
        while i < len(segments) and segments[i][:3] != "UNT":
            body.append(parse_segment(segments[i], version))
            i += 1
        i += 1  # skip UNT

        message = build_message(msg_type, version, unh, unb, body)
        messages.setdefault(version, {}).setdefault(msg_type, []).append(message)

    return {
        "EDI": {
            "Errors": [],
            "Delimiters": "+: '?",
            "Messages": messages,
            "FunctionalAcksReceived": [],
            "FunctionalAcksGenerated": [],
        }
    }


def is_edifact(path: str) -> bool:
    """Classify by content, not by extension.

    The example set is thoroughly mislabelled - EDIFACT interchanges saved as .xml, .docx
    and .png; parsed-JSON captures saved as .txt and .xml - so the only reliable test is
    the interchange header.
    """
    head = open(path, "rb").read(8)
    return head.startswith(b"UNA") or head.startswith(b"UNB")


def slug(name: str) -> str:
    """Classpath-safe fixture name: the DataWeave test runner reads fixtures through
    `classpath://`, where spaces and parentheses in the source filenames do not survive."""
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", name.lower())).strip("-")


def describe(doc: dict, fixture: str, source: str, scenario: str) -> dict:
    """One manifest row: what this fixture is, so tests can be driven by data rather than
    by a hand-maintained list. Everything here is read off the message itself, because the
    source filenames say the wrong thing about all three of type, direction and code."""
    rows = [
        (version, msg_type, msg)
        for version, byType in doc["EDI"]["Messages"].items()
        for msg_type, msgs in byType.items()
        for msg in msgs
    ]
    version, msg_type = (rows[0][0], rows[0][1]) if rows else ("", "")
    messages = []
    for _v, _t, msg in rows:
        heading = msg["Heading"]
        bgm = next((v for k, v in heading.items() if k.endswith("_BGM")), {})
        equipment = [
            g for k, v in heading.items()
            if "_Segment_group_" in k
            for g in (v if isinstance(v, list) else [v])
            if isinstance(g, dict) and any(kk.endswith("_EQD") for kk in g)
        ]
        messages.append({
            "bl": msg["MessageHeader"].get("UNH03"),
            "code": str(bgm.get("BGM03", "")),
            "customerReference": bgm.get("BGM0201"),
            "equipment": len(equipment),
        })
    row = {
        "fixture": fixture,
        "source": source,
        "scenario": scenario,
        "messageType": msg_type,
        "version": version,
        "messageCount": len(messages),
        "masterSub": msg_type == "IFTMIN" and len(messages) > 1,
        "messages": messages,
    }
    if msg_type == "IFCSUM":
        row["cargo"] = [line for _v, _t, msg in rows for line in ifcsum_cargo(msg)]
    return row


def ifcsum_cargo(msg: dict) -> list:
    """The cargo lines an IFCSUM message should produce, read straight off the parsed tree.

    Deliberately independent of InboundIfcsum.dwl: this walks the structure by explicit key
    lookup where the mapping walks it by segment-name suffix, so the manifest is a genuine
    cross-check of the mapping rather than a restatement of it.
    """
    heading = msg["Heading"]

    def groups(node, seg):
        out = []
        for key, value in node.items():
            if "_Segment_group_" not in key:
                continue
            for g in (value if isinstance(value, list) else [value]):
                if isinstance(g, dict) and any(k.endswith("_" + seg) for k in g):
                    out.append(g)
        return out

    def seg(node, name):
        for key, value in (node or {}).items():
            if key.endswith("_" + name):
                return (value[0] if isinstance(value, list) else value)
        return {}

    def ref(node, qualifier):
        for g in groups(node, "RFF"):
            r = seg(g, "RFF")
            if r.get("RFF0101") == qualifier:
                return r
        return {}

    # Only a real sea container (an ISO type code in EQD0301) belongs on a cargo line; an
    # LCL summary describes the truck that ran the consignments to the terminal.
    boxes = [e for e in groups(heading, "EQD") if seg(e, "EQD").get("EQD0301")]
    container = None
    if len(boxes) == 1:
        eqd = seg(boxes[0], "EQD")
        measures = [m for m in as_list(boxes[0], "MEA") if m.get("MEA0201") == "AAB"]
        persons = [n for n in as_list(boxes[0], "NAD") if n.get("NAD01") == "AM"]
        container = {
            "containerNumber": eqd.get("EQD0201"),
            "containerType": eqd.get("EQD0301"),
            "verifiedGrossMass": float(measures[0]["MEA0302"]) if measures else None,
            "sealNumber": (as_list(boxes[0], "SEL") or [{}])[0].get("SEL01"),
            "vgmPerson": persons[0].get("NAD0401") if persons else None,
        }

    lines = []
    for consignment in groups(heading, "CNI"):
        mrn = ref(consignment, "ABT").get("RFF0102")
        for item in groups(consignment, "GID"):
            li = ref(item, "LI")
            lines.append({
                "itemNumber": seg(item, "GID").get("GID01"),
                "deliveryNote": li.get("RFF0102") or seg(consignment, "CNI").get("CNI0201"),
                "position": li.get("RFF0103"),
                "mrn": mrn,
                "container": container,
            })
    return lines


def as_list(node: dict, name: str) -> list:
    for key, value in node.items():
        if key.endswith("_" + name):
            return value if isinstance(value, list) else [value]
    return []


def convert_tree(src: str, dst: str, label: str) -> int:
    """Convert every EDIFACT file under `src` into `dst`, mirroring the directory layout.

    Shared by --all and --outbound. The inbound walk flattens one level into a scenario
    directory and writes a manifest; the outbound tree is already `<variant>/<MESSAGE>.txt`
    and its expectation *is* the message, so it needs neither.
    """
    ok = failed = skipped = 0
    for root, _dirs, files in os.walk(src):
        for name in sorted(files):
            path = os.path.join(root, name)
            if not is_edifact(path):
                skipped += 1
                continue
            rel = os.path.relpath(path, src).replace("\\", "/")
            out_path = os.path.join(dst, os.path.splitext(rel)[0] + ".json")
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            try:
                doc = convert(path)
            except Unplaceable as exc:
                print(f"FAIL {rel}: {exc}")
                failed += 1
                continue
            with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
                json.dump(doc, fh, indent=2, ensure_ascii=False)
                fh.write("\n")
            print(f"ok   {rel}")
            ok += 1
    print(f"\n{label}: {ok} converted, {failed} failed, {skipped} skipped (not EDIFACT)")
    return 1 if failed else 0


def copy_tree(src: str, dst: str, label: str) -> int:
    """Copy every .json under `src` to `dst`, mirroring the layout. Re-serialised rather than
    byte-copied so the classpath fixture is normalised the same way a converted one is."""
    count = 0
    for root, _dirs, files in os.walk(src):
        for name in sorted(files):
            if not name.endswith(".json"):
                continue
            rel = os.path.relpath(os.path.join(root, name), src).replace("\\", "/")
            out_path = os.path.join(dst, rel)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            with open(os.path.join(root, name), encoding="utf-8") as fh:
                doc = json.load(fh)
            with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
                json.dump(doc, fh, indent=2, ensure_ascii=False)
                fh.write("\n")
            print(f"ok   {rel}")
            count += 1
    print(f"\n{label}: {count} copied")
    return 0


def main(argv: list[str]) -> int:
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if argv and argv[0] == "--outbound":
        # The approved IFTSTA messages are the *expectation* for OutboundIftsta.dwl, so they
        # travel to the classpath parsed into the same shape the mapping emits. The mapping
        # builds that shape from a Carlo event; this builds it from the EDIFACT. Agreement
        # between the two is the suite's central assertion.
        out = os.path.join(here, "src", "test", "resources", "example-orders", "outbound", "iftsta")
        rc = convert_tree(
            os.path.join(here, "docs", "example-orders", "outbound", "iftsta", "basf"),
            os.path.join(out, "basf"),
            "outbound expectations")
        # The Carlo events are the *input*, and they are already JSON - copied rather than
        # converted, but copied by this tool so that one command keeps the whole fixture set in
        # step with docs/ and no file on the classpath is hand-maintained.
        return rc or copy_tree(
            os.path.join(here, "docs", "example-orders", "outbound", "iftsta", "carlo"),
            os.path.join(out, "carlo"),
            "outbound inputs")

    if argv and argv[0] == "--all":
        src = os.path.join(here, "docs", "example-orders", "inbound")
        dst = os.path.join(here, "src", "test", "resources", "example-orders", "inbound")
        ok = failed = skipped = 0
        manifest = []
        for root, _dirs, files in os.walk(src):
            for name in sorted(files):
                path = os.path.join(root, name)
                if not is_edifact(path):
                    skipped += 1
                    continue
                rel = os.path.relpath(path, src).replace("\\", "/")
                scenario = rel.split("/")[0]
                out_name = slug(os.path.splitext(os.path.basename(rel))[0]) + ".json"
                out_path = os.path.join(dst, scenario, out_name)
                os.makedirs(os.path.dirname(out_path), exist_ok=True)
                try:
                    doc = convert(path)
                except Unplaceable as exc:
                    print(f"FAIL {rel}: {exc}")
                    failed += 1
                    continue
                with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
                    json.dump(doc, fh, indent=2, ensure_ascii=False)
                    fh.write("\n")
                manifest.append(describe(doc, f"{scenario}/{out_name}", rel, scenario))
                print(f"ok   {rel} -> {scenario}/{out_name}")
                ok += 1

        manifest.sort(key=lambda e: (e["messageType"], e["fixture"]))
        with open(os.path.join(dst, "manifest.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(manifest, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        print(f"\n{ok} converted, {failed} failed, {skipped} skipped (not EDIFACT)")
        print(f"manifest: {len(manifest)} fixtures -> example-orders/inbound/manifest.json")
        return 1 if failed else 0

    if not argv:
        print(__doc__)
        return 2
    doc = convert(argv[0])
    text = json.dumps(doc, indent=2, ensure_ascii=False)
    if len(argv) > 1:
        with open(argv[1], "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text + "\n")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
