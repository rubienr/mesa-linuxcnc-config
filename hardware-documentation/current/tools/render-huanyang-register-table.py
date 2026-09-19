#!/usr/bin/env python3
"""Render a Huanyang register-dump JSON file as a documented Markdown table."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


NAMES = {
    0: "Parameter lock",
    1: "Source of operation commands",
    2: "Source of operating frequency",
    3: "Main frequency",
    4: "Base frequency",
    5: "Maximum operating frequency",
    6: "Intermediate frequency",
    7: "Minimum frequency",
    8: "Maximum voltage",
    9: "Intermediate voltage",
    10: "Minimum voltage",
    11: "Frequency lower limit",
    12: "Reserved",
    13: "Parameter reset",
    14: "Acceleration time 1",
    15: "Deceleration time 1",
    16: "Acceleration time 2",
    17: "Deceleration time 2",
    18: "Acceleration time 3",
    19: "Deceleration time 3",
    20: "Acceleration time 4",
    21: "Deceleration time 4",
    22: "Reserved",
    23: "Reverse-rotation selection",
    24: "STOP-key selection",
    25: "Starting mode",
    26: "Stopping mode",
    27: "Starting frequency",
    28: "Stopping frequency",
    29: "DC-braking time at start",
    30: "DC-braking time at stop",
    31: "DC-braking voltage level",
    32: "Frequency-track time",
    33: "Current level for frequency tracking",
    34: "Voltage-rise time during frequency tracking",
    35: "UP/DOWN frequency step",
    41: "Carrier frequency",
    42: "Jogging frequency",
    43: "S-curve time",
    44: "Multi-input 1 (FOR terminal)",
    45: "Multi-input 2 (REV terminal)",
    46: "Multi-input 3 (RST terminal)",
    47: "Multi-input 4 (SPH terminal)",
    48: "Multi-input 5 (SPM terminal)",
    49: "Multi-input 6 (SPL terminal)",
    50: "Multi-output 1 (DRV)",
    51: "Multi-output 2 (UPF)",
    52: "Multi-output 3 (FA/FB/FC)",
    53: "Multi-output 4 (KA/KB)",
    54: "AM analog/pulse-output selection",
    55: "AM analog-output gain",
    56: "Skip frequency 1",
    57: "Skip frequency 2",
    58: "Skip frequency 3",
    59: "Skip-frequency range",
    60: "Uniform frequency 1",
    61: "Uniform frequency 2",
    62: "Uniform-frequency range",
    63: "Timer 1 time",
    64: "Timer 2 time",
    65: "Counting value",
    66: "Intermediate counter",
    70: "Analog-input type",
    71: "Analog filtering constant",
    72: "Higher analog frequency",
    73: "Lower analog frequency",
    74: "Bias direction at higher frequency",
    75: "Bias direction at lower frequency",
    76: "Analog negative-bias reverse",
    77: "UP/DOWN memory",
    78: "UP/DOWN speed unit",
    80: "PLC operation mode",
    81: "Auto-PLC cycle mode",
    82: "PLC running-direction mask",
    84: "PLC ramp-time mask",
    117: "Auto-PLC memory",
    118: "Over-voltage stall prevention",
    119: "Stall-prevention level during acceleration",
    120: "Stall-prevention level at constant speed",
    121: "Deceleration time for constant-speed stall prevention",
    122: "Stall-prevention level during deceleration",
    123: "Over-torque detection mode",
    124: "Over-torque detection level",
    125: "Over-torque detection time",
    130: "Number of auxiliary pumps",
    131: "Continuous running time of auxiliary pumps",
    132: "Auxiliary-pump interlocking time",
    133: "High-speed running time",
    134: "Low-speed running time",
    135: "Stopping voltage level",
    136: "Duration at stopping-voltage level",
    137: "Wake-up voltage level",
    138: "Sleep frequency",
    139: "Duration at sleep frequency",
    141: "Rated motor voltage",
    142: "Rated motor current",
    143: "Motor pole count",
    144: "Rated motor speed at 50 Hz",
    145: "Automatic torque compensation",
    146: "Motor no-load current",
    147: "Motor slip compensation",
    150: "Automatic voltage regulation",
    151: "Automatic energy saving",
    152: "Fault-restart delay",
    153: "Restart after instantaneous power loss",
    154: "Allowable power-loss time",
    155: "Number of abnormal restarts",
    156: "PID proportional constant",
    157: "PID integral time",
    158: "PID differential time",
    159: "PID target value",
    160: "PID target-value source",
    161: "PID upper limit",
    162: "PID lower limit",
    163: "RS-485 station address",
    164: "Communication baud rate",
    165: "Communication data format",
    170: "Additional display item",
    171: "Display-items enable mask",
    172: "Fault clear",
    174: "Rated inverter current",
    175: "Inverter load model",
    176: "Inverter frequency standard",
    177: "Fault record 1",
    178: "Fault record 2",
    179: "Fault record 3",
    180: "Fault record 4",
    181: "Software version",
    182: "Manufacture date",
    183: "Serial number",
}


PURPOSES = {
    0: "Prevents accidental parameter changes when locked.",
    1: "Selects keypad, external terminals, or communications for run commands.",
    2: "Selects keypad, analog input, or communications as the frequency source.",
    3: "Frequency command used in keypad/main-speed operation.",
    4: "Motor V/f base frequency; must match the motor/application.",
    5: "Hard upper operating-frequency setting.",
    6: "Intermediate point of the V/f curve.",
    7: "Minimum starting point of the V/f curve.",
    8: "Maximum V/f-curve voltage.",
    9: "Intermediate V/f-curve voltage.",
    10: "Minimum V/f-curve voltage.",
    11: "Prevents commands below this output frequency.",
    13: "Writing the reset code can restore factory parameters; read only in this capture.",
    23: "Allows or forbids reverse motor rotation.",
    24: "Determines whether the panel STOP key remains effective under remote control.",
    25: "Selects normal start or frequency-track start.",
    26: "Selects ramped stop or coast stop.",
    27: "Initial output frequency during a normal start.",
    28: "Frequency at which normal deceleration transitions to stop/braking.",
    29: "Duration of DC injection before starting.",
    30: "Duration of DC injection during stopping.",
    31: "DC-injection braking voltage as a percentage.",
    32: "Time used to search for the speed of a spinning load.",
    33: "Current limit used during frequency tracking.",
    34: "Voltage-rise timing during frequency tracking.",
    35: "Increment used by external UP/DOWN commands.",
    41: "PWM carrier selection; trades motor noise against VFD heating/EMI.",
    42: "Output frequency used for jog operation.",
    43: "Softens acceleration/deceleration transitions when nonzero.",
    54: "Selects what the AM terminal represents and whether it is analog or pulse output.",
    55: "Scales the AM monitor output.",
    59: "Half-width around each avoided mechanical-resonance frequency.",
    62: "Hysteresis around the uniform-frequency thresholds.",
    65: "Final external-counter threshold.",
    66: "Intermediate external-counter threshold.",
    70: "Selects voltage/current analog command input behavior.",
    71: "Low-pass filtering of the analog command input.",
    72: "Frequency corresponding to the high end of the analog input.",
    73: "Frequency corresponding to the low end of the analog input.",
    74: "Direction associated with the high end of the analog input.",
    75: "Direction associated with the low end of the analog input.",
    76: "Allows or blocks reverse operation caused by negative analog bias.",
    77: "Controls whether an UP/DOWN change survives stopping.",
    78: "Selects the minimum UP/DOWN step rate.",
    80: "Selects normal, multi-speed, traverse, internal PLC, or drawing operation.",
    81: "Selects stop/cycle behavior for internal PLC operation.",
    82: "Bit mask selecting forward/reverse direction for PLC speed steps.",
    84: "Bit mask selecting one of four ramp pairs for each PLC speed step.",
    117: "Controls whether Auto-PLC resumes its saved state.",
    118: "Extends deceleration when regenerative energy raises the DC bus.",
    119: "Current threshold that pauses acceleration.",
    120: "Current threshold that reduces frequency at constant speed.",
    121: "Rate used to lower frequency during constant-speed stall prevention.",
    122: "Current threshold used during deceleration.",
    123: "Selects when over-torque is detected and whether it trips.",
    124: "Current threshold for over-torque detection.",
    125: "Delay before over-torque protection acts.",
    130: "Configures the number of auxiliary pumps controlled by the VFD.",
    131: "Alternation interval for auxiliary pumps.",
    132: "Dead time while changing auxiliary pumps.",
    133: "Delay at high-speed threshold before adding a pump.",
    134: "Delay at low-speed threshold before removing a pump.",
    135: "Process-feedback threshold for entering sleep.",
    136: "Required duration below the stopping threshold.",
    137: "Process-feedback threshold for waking from sleep.",
    138: "Low operating frequency used when entering sleep.",
    139: "Required duration at the sleep frequency.",
    141: "Motor nameplate voltage used by protection/control calculations.",
    142: "Motor nameplate current used for current limiting and protection.",
    143: "Motor pole count used for speed calculation.",
    144: "Motor rated speed at 50 Hz; not the maximum speed at 400 Hz.",
    145: "Adds low-frequency voltage to increase torque.",
    146: "No-load current as a percentage of rated motor current.",
    147: "Compensates induction-motor slip under load.",
    150: "Stabilizes motor voltage against input-voltage variation.",
    151: "Reduces voltage under light constant-speed load.",
    152: "Delay before an automatic fault restart.",
    153: "Allows frequency-track restart after a short power interruption.",
    154: "Maximum interruption duration eligible for automatic restart.",
    155: "Limits automatic reset/restart attempts; zero disables them.",
    156: "Proportional gain of the process PID controller.",
    157: "Integral time of the process PID controller.",
    158: "Derivative time of the process PID controller.",
    159: "Internally configured PID setpoint.",
    160: "Selects internal PD159 or external analog PID setpoint.",
    161: "Upper PID feedback threshold for a multifunction output.",
    162: "Lower PID feedback threshold for a multifunction output.",
    163: "Slave address used by the Huanyang serial protocol.",
    164: "Selects serial baud rate.",
    165: "Selects ASCII/RTU mode, parity, data bits, and stop bits.",
    170: "Selects the optional quantity shown on the front panel.",
    171: "Enables additional front-panel display quantities.",
    172: "Writing 1 clears faults; captured value is outside the manual's documented range.",
    174: "Factory/model current rating; documented as read-only.",
    175: "Selects constant-torque or fan/pump load model; read-only.",
    176: "Factory 50/60 Hz region setting; read-only.",
    181: "Factory software-version code.",
    182: "Factory packed manufacture-date code.",
    183: "Factory serial-number field.",
}


MULTI_INPUT = {
    0: "disabled",
    1: "run",
    2: "forward",
    3: "reverse",
    4: "stop",
    10: "fault reset",
    14: "timer 2 start",
    22: "multi-speed 3",
    23: "ramp-time select 1",
    24: "ramp-time select 2",
}
MULTI_OUTPUT = {
    0: "disabled",
    1: "in run",
    5: "set frequency reached",
    8: "accelerating",
    25: "auxiliary pump 1",
    26: "auxiliary pump 2",
}
CARRIER_KHZ = [0.7, 1, 1.5, 2, 3, 4, 5, 7, 8, 9, 10, 11, 13, 15, 17, 20]

# Values are transcribed from the supplied HY-series manual. Asterisks are
# retained because the manual defines them as model/application-specific.
# Parameters absent from this mapping are handled explicitly below.
FACTORY_SETTINGS = {
    0: "0", 1: "0", 2: "0", 3: "0.00 Hz", 4: "50.00 Hz",
    5: "50.00 Hz", 6: "2.50 Hz", 7: "0.50 Hz", 8: "220/380 V",
    9: "15/27.5 V", 10: "* (8 V for 220 V class; 13.5 V for 380 V class)",
    11: "0.00 Hz", 13: "00", 23: "1", 24: "1", 25: "0", 26: "0",
    27: "0.5 Hz", 28: "0.5 Hz", 29: "0.0 s", 30: "0.0 s",
    31: "2.0%", 32: "2.0 s", 33: "150%", 34: "0.5 s",
    35: "0.01 Hz", 41: "5 (generic; model-dependent)", 42: "5.00 Hz",
    43: "1 s", 44: "02", 45: "03", 46: "10", 47: "17", 48: "18",
    49: "19", 50: "01", 51: "05", 52: "02", 53: "00", 54: "0",
    55: "100.0%", 59: "0.50 Hz", 62: "0.50 Hz", 63: "0.01",
    64: "0", 65: "0", 66: "0", 70: "0", 71: "20", 72: "50.00 Hz",
    73: "0.00 Hz", 74: "0", 75: "0", 76: "0", 77: "0", 78: "0",
    80: "0", 81: "0", 82: "0", 84: "0", 86: "15 Hz", 87: "20 Hz",
    88: "25 Hz", 89: "30 Hz", 90: "35 Hz", 91: "40 Hz", 92: "0.5 Hz",
    101: "10.0 s", 102: "10.0 s", 117: "0", 118: "1", 119: "150%",
    120: "0%", 121: "5.0 s", 122: "150%", 123: "0", 124: "0%",
    125: "1.0 s", 130: "0", 131: "60 min", 132: "5 s", 133: "60 s",
    134: "60 s", 135: "95%", 136: "30 s", 137: "80%", 138: "20.00 Hz",
    139: "20 s", 141: "* (220 V for 230 V class; 380 V for 400 V class)",
    142: "*", 143: "04", 144: "1440 rpm", 145: "2.0%", 146: "40%",
    147: "0.0%", 150: "1", 151: "0%", 152: "1.0 s", 153: "0",
    154: "0.5 s", 155: "00", 156: "100%", 157: "5.0 s", 158: "0 s",
    159: "*", 160: "0", 161: "100%", 162: "0%", 163: "00",
    164: "1 (9600 bit/s)", 165: "0 (8N1 ASCII)", 170: "0", 171: "0",
    172: "00", 174: "*", 175: "0", 176: "*", 177: "—", 178: "—",
    179: "—", 180: "—", 181: "*", 182: "*", 183: "*",
}

for parameter in range(14, 22):
    FACTORY_SETTINGS[parameter] = "* (model-specific)"
for parameter in (56, 57, 58, 60, 61):
    FACTORY_SETTINGS[parameter] = "0.00 Hz"
for parameter in range(103, 109):
    FACTORY_SETTINGS[parameter] = "0.0 s"

EXPLICITLY_RESERVED = {
    12, 22, *range(35, 41), *range(67, 70), 79, *range(184, 251),
}
DELIVERED_HANDBOOK_PENDING = {
    *range(81, 86), *range(93, 101), *range(109, 117),
}
NOT_PRESENT_IN_MANUAL = {
    126, *range(127, 130), 140, 148, 149,
    *range(166, 170), 173,
}

# Encoded values corresponding to numeric factory settings above. Parameters
# with a model-specific/no-fixed default are intentionally absent so they get
# an indeterminate marker instead of a potentially false comparison.
FACTORY_RAW = {
    0: 0, 1: 0, 2: 0, 3: 0, 4: 5000, 5: 5000, 6: 250, 7: 50,
    8: 2200, 9: 150, 10: 80, 11: 0, 13: 0, 23: 1, 24: 1, 25: 0,
    26: 0, 27: 5, 28: 5, 29: 0, 30: 0, 31: 20, 32: 20, 33: 150,
    34: 5, 35: 1, 41: 5, 42: 500, 43: 1, 44: 2, 45: 3, 46: 10,
    47: 17, 48: 18, 49: 19, 50: 1, 51: 5, 52: 2, 53: 0, 54: 0,
    55: 1000, 56: 0, 57: 0, 58: 0, 59: 50, 60: 0, 61: 0, 62: 50,
    63: 1, 64: 0, 65: 0, 66: 0, 70: 0, 71: 20, 72: 5000, 73: 0,
    74: 0, 75: 0, 76: 0, 77: 0, 78: 0, 80: 0, 81: 0, 82: 0, 84: 0,
    86: 1500, 87: 2000, 88: 2500, 89: 3000, 90: 3500, 91: 4000,
    92: 50, 101: 100, 102: 100, 103: 0, 104: 0, 105: 0, 106: 0,
    107: 0, 108: 0, 117: 0, 118: 1, 119: 150, 120: 0, 121: 50,
    122: 150, 123: 0, 124: 0, 125: 10, 130: 0, 131: 60, 132: 5,
    133: 60, 134: 60, 135: 95, 136: 30, 137: 80, 138: 2000,
    139: 20, 141: 2200, 143: 4, 144: 1440, 145: 20, 146: 40,
    147: 0, 150: 1, 151: 0, 152: 10, 153: 0, 154: 5, 155: 0,
    156: 1000, 157: 50, 158: 0, 160: 0, 161: 100, 162: 0,
    163: 0, 164: 1, 165: 0, 170: 0, 171: 0, 172: 0, 175: 0,
}


def number(value: float, digits: int = 2) -> str:
    return f"{value:.{digits}f}".rstrip("0").rstrip(".")


def name(parameter: int) -> str:
    if parameter in EXPLICITLY_RESERVED:
        return "Reserved"
    if 81 <= parameter <= 85:
        return "Pending transcription from delivered handbook"
    if parameter in NAMES:
        return NAMES[parameter]
    if parameter in NOT_PRESENT_IN_MANUAL:
        return "Not present in project PDF"
    if 86 <= parameter <= 100:
        return f"Multi-speed frequency {parameter - 84}"
    if 101 <= parameter <= 116:
        return f"PLC timer {parameter - 100}"
    return "Not described in supplied manual"


def purpose(parameter: int) -> str:
    if parameter in EXPLICITLY_RESERVED:
        return "Reserved in the handbook delivered with this VFD."
    if 81 <= parameter <= 85:
        return "The project PDF's description is not applicable; transcribe the delivered handbook."
    if parameter in PURPOSES:
        return PURPOSES[parameter]
    if 14 <= parameter <= 21:
        return "Sets one of four acceleration/deceleration ramp times."
    if 44 <= parameter <= 49:
        return "Assigns a function to one of the six digital input terminals."
    if 50 <= parameter <= 53:
        return "Assigns a status/control function to a multifunction output."
    if 56 <= parameter <= 58:
        return "Defines a frequency to skip to avoid mechanical resonance."
    if parameter in {60, 61}:
        return "Frequency threshold used by multifunction outputs and pump control."
    if parameter in {63, 64}:
        return "Delay for an externally triggered multifunction timer."
    if 86 <= parameter <= 100:
        return "Frequency command for a multi-speed/PLC step."
    if 101 <= parameter <= 116:
        return "Run duration for a multi-speed/PLC step."
    if 177 <= parameter <= 180:
        return "Stores a historical fault code; decoding requires the matching firmware display-code table."
    return "No applicable description is available yet; preserve the raw result."


def factory_setting(parameter: int) -> str:
    if parameter in EXPLICITLY_RESERVED:
        return "Reserved; none stated"
    if parameter in DELIVERED_HANDBOOK_PENDING:
        return "Pending handbook transcription"
    if parameter in NOT_PRESENT_IN_MANUAL:
        return "Not present in project PDF"
    if parameter in FACTORY_SETTINGS:
        return FACTORY_SETTINGS[parameter]
    return "Not stated in project PDF"


def factory_difference(parameter: int, record: dict) -> str:
    if (
        record["status"] != "ok"
        or parameter in EXPLICITLY_RESERVED
        or parameter in DELIVERED_HANDBOOK_PENDING
        or parameter not in FACTORY_RAW
    ):
        return "?"
    return "" if record["raw_value"] == FACTORY_RAW[parameter] else "X"


def manual_status(parameter: int) -> str:
    if parameter in EXPLICITLY_RESERVED:
        return "R"
    if parameter in NOT_PRESENT_IN_MANUAL:
        return "N"
    return ""


def render_markdown_table(
    headers: list[str], rows: list[list[str]], alignments: list[str]
) -> list[str]:
    """Render a Markdown table whose pipe characters align in plain text."""
    widths = [
        max(3, len(headers[column]), *(len(row[column]) for row in rows))
        for column in range(len(headers))
    ]

    def pad(value: str, column: int) -> str:
        alignment = alignments[column]
        if alignment == "right":
            return value.rjust(widths[column])
        if alignment == "center":
            return value.center(widths[column])
        return value.ljust(widths[column])

    rendered = [
        "| " + " | ".join(pad(value, column) for column, value in enumerate(headers)) + " |"
    ]
    separators = []
    for width, alignment in zip(widths, alignments):
        if alignment == "right":
            separators.append("-" * (width - 1) + ":")
        elif alignment == "center":
            separators.append(":" + "-" * (width - 2) + ":")
        else:
            separators.append("-" * width)
    rendered.append("| " + " | ".join(separators) + " |")
    rendered.extend(
        "| " + " | ".join(pad(value, column) for column, value in enumerate(row)) + " |"
        for row in rows
    )
    return rendered


def decode(parameter: int, raw: int) -> str:
    if 81 <= parameter <= 85:
        return f"{raw} (interpretation pending handbook transcription)"
    if parameter in {3, 4, 5, 6, 7, 11, 42, 56, 57, 58, 59, 60, 61, 62, 72, 73} or 86 <= parameter <= 100:
        return f"{number(raw / 100)} Hz"
    if parameter in {8, 9, 10, 141}:
        return f"{number(raw / 10)} V"
    if 14 <= parameter <= 21 or parameter in {29, 30, 32, 121, 125, 152, 154, 157} or 101 <= parameter <= 116:
        return f"{number(raw / 10)} s"
    if parameter in {27, 28}:
        return f"{number(raw / 10)} Hz"
    if parameter in {31, 55, 145, 147, 156}:
        return f"{number(raw / 10)} %"
    if parameter == 158:
        return f"{number(raw / 100)} s"
    if parameter in {33, 119, 120, 122, 124, 135, 137, 146, 151, 159, 161, 162}:
        return f"{raw} %"
    if parameter == 34:
        return f"{number(raw / 10)} s"
    if parameter == 41 and 0 <= raw < len(CARRIER_KHZ):
        return f"{CARRIER_KHZ[raw]} kHz"
    if 44 <= parameter <= 49:
        return f"{raw}: {MULTI_INPUT.get(raw, 'see manual assignment table')}"
    if 50 <= parameter <= 53:
        return f"{raw}: {MULTI_OUTPUT.get(raw, 'see manual assignment table')}"
    if parameter == 54:
        return f"{raw}: 0–10 V proportional to output frequency" if raw == 0 else str(raw)
    if parameter == 70:
        return {0: "0: 0–10 V", 1: "1: 0–5 V", 2: "2: 0–20 mA", 3: "3: 4–20 mA"}.get(raw, str(raw))
    if parameter in {74, 75}:
        return f"{raw}: {'positive' if raw == 0 else 'negative'}"
    if parameter in {76, 77, 78, 117, 118, 150, 151, 153}:
        return f"{raw}: {'disabled/not retained' if raw == 0 else 'enabled/retained'}"
    if parameter == 1:
        return {0: "0: keypad", 1: "1: external terminals", 2: "2: communications"}.get(raw, str(raw))
    if parameter == 2:
        return {0: "0: keypad", 1: "1: analog/external", 2: "2: communications"}.get(raw, str(raw))
    if parameter == 23:
        return f"{raw}: {'reverse forbidden' if raw == 0 else 'reverse enabled'}"
    if parameter == 24:
        return f"{raw}: panel STOP {'valid' if raw else 'invalid'}"
    if parameter == 25:
        return f"{raw}: {'normal start' if raw == 0 else 'frequency-track start'}"
    if parameter == 26:
        return f"{raw}: {'decelerating stop' if raw == 0 else 'coast stop'}"
    if parameter == 63:
        return f"{number(raw / 10)} s"
    if parameter == 64:
        return f"{raw} s"
    if parameter == 80:
        return f"{raw}: {'normal operation' if raw == 0 else 'see PLC-mode table'}"
    if parameter == 81:
        return f"{raw}: stop after one PLC cycle" if raw == 0 else str(raw)
    if parameter in {82, 84, 171}:
        return f"{raw} (0x{raw:04x} bit mask)"
    if parameter == 123:
        return f"{raw}: detect at set frequency and continue running" if raw == 0 else str(raw)
    if parameter == 130:
        return f"{raw} auxiliary pump{'s' if raw != 1 else ''}"
    if parameter == 131:
        return f"{raw} min"
    if parameter in {132, 133, 134, 136, 139}:
        return f"{raw} s"
    if parameter == 138:
        return f"{number(raw / 100)} Hz"
    if parameter == 142:
        return f"{number(raw / 10)} A"
    if parameter == 143:
        return f"{raw} poles"
    if parameter == 144:
        return f"{raw} rpm at 50 Hz"
    if parameter == 163:
        return f"station {raw}"
    if parameter == 164:
        return {0: "4800 bit/s", 1: "9600 bit/s", 2: "19200 bit/s", 3: "38400 bit/s"}.get(raw, str(raw))
    if parameter == 165:
        return {0: "8N1 ASCII", 1: "8E1 ASCII", 2: "8O1 ASCII", 3: "8N1 RTU", 4: "8E1 RTU", 5: "8O1 RTU"}.get(raw, str(raw))
    if parameter == 170:
        return {0: "inverter temperature", 1: "counter", 2: "PID target", 3: "PID feedback", 4: "current powered hours", 5: "total powered hours"}.get(raw, str(raw))
    if parameter == 174:
        return f"raw {raw}; likely {number(raw / 10)} A, but supplied manual says 1 A/unit"
    if parameter == 175:
        return f"{raw}: {'constant torque' if raw == 0 else 'fan/pump'}"
    if parameter == 176:
        return f"{raw}: {'50 Hz' if raw == 0 else '60 Hz'}"
    if 177 <= parameter <= 181:
        return f"{raw} (0x{raw:04x})"
    if parameter == 182:
        return f"{raw} (0x{raw:04x}; packed date not decoded)"
    if parameter == 183:
        return f"{raw} (0x{raw:04x})"
    return str(raw)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    data = json.loads(args.input.read_text(encoding="utf-8"))
    supported = sum(record["status"] == "ok" for record in data["registers"])
    unsupported = sum(record["status"] == "unsupported" for record in data["registers"])
    errors = sum(record["status"] == "error" for record in data["registers"])
    first = min(record["number"] for record in data["registers"])
    last = max(record["number"] for record in data["registers"])
    lines = [
        "# Huanyang HY02D223B register backup",
        "",
        f"Captured `{data['captured_at']}` through `{data['device']}` at "
        f"{data['baud']} bit/s, {data['format']}, station {data['target']}.",
        "",
        "The capture program transmitted only Huanyang function `0x01` "
        "(read parameter). The raw, CRC-checked request and response frames are "
        f"preserved in [`data/{args.input.name}`](data/{args.input.name}).",
        "",
        f"The capture covers `PD{first:03d}`–`PD{last:03d}`: {supported} registers returned "
        f"values, {unsupported} returned CRC-valid unsupported replies, and {errors} ended in errors.",
        "",
        "Decoded units and descriptions initially came from "
        "[`datasheets/huanyang-hy02d223b-manual.pdf`](datasheets/huanyang-hy02d223b-manual.pdf). "
        "That project PDF is not the same revision as the handbook delivered with this VFD. "
        "Owner-confirmed handbook corrections are applied here; untranscribed conflicts are marked pending rather than guessed.",
        "",
        "In its factory-setting column, `*` retains the manual's notation for a model- or application-specific value; "
        "an em dash means the manual gives no fixed initial value.",
        "",
        "## Important recovered settings",
        "",
        "- Run commands and frequency both come from communications (`PD001=2`, `PD002=2`).",
        "- Serial settings are station 1, 19,200 bit/s, 8N1 RTU (`PD163=1`, `PD164=2`, `PD165=3`).",
        "- Base and maximum frequency are both 400 Hz (`PD004`, `PD005`).",
        "- The lower operating limit is 13.40 Hz (`PD011`), corresponding to about 804 rpm with `PD144=3000 rpm at 50 Hz`.",
        "- Motor data are 220 V, 10.0 A, 2 poles and 3000 rpm at 50 Hz (`PD141`–`PD144`). The 10.0 A setting conflicts with the spindle's informal paper value of 6 A and must be resolved before commissioning.",
        "- Reverse rotation is forbidden (`PD023=0`) and the panel STOP key is enabled (`PD024=1`).",
        "- One auxiliary pump is configured (`PD130=1`), and `PD133`–`PD139` contain non-default pump/sleep timings and thresholds. The coolant-pump conductor appears to be on `FA(MB)` or `FC(MB)`; verify it physically before changing anything.",
        "- No automatic abnormal restart is configured (`PD155=0`), and restart after instantaneous power loss is disabled (`PD153=0`).",
        "- The delivered handbook marks `PD184`–`PD250` reserved. The VFD nevertheless returned `PD184=20`, `PD185=0`, `PD186=0` and `PD200=0`; preserve these values without assigning a meaning or writing them. Apart from `PD200`, every query from `PD187`–`PD250` returned a CRC-valid unsupported reply.",
        "",
        "## Complete parameter table",
        "",
        "[1] Factory difference: blank = captured value equals the numeric factory setting; "
        "`X` = differs; `?` = comparison is not possible from this capture/manual.",
        "",
        "[2] Manual status: `R` = explicitly marked reserved in the delivered handbook; "
        "`N` = parameter is not present in the project PDF; blank = documented and not marked reserved.",
        "",
    ]

    table_rows = []
    for record in data["registers"]:
        parameter = record["number"]
        if record["status"] == "ok":
            raw = record["raw_value"]
            decoded = decode(parameter, raw)
            raw_text = str(raw)
        else:
            raw_text = "—"
            decoded = "Unsupported by this VFD (CRC-checked `0x81` reply)"
        row = [
            f"`PD{parameter:03d}`",
            raw_text,
            decoded,
            factory_setting(parameter),
            factory_difference(parameter, record),
            manual_status(parameter),
            name(parameter),
            purpose(parameter),
        ]
        table_rows.append([item.replace("|", "\\|") for item in row])

    lines.extend(
        render_markdown_table(
            [
                "Parameter",
                "Raw",
                "Decoded/current setting",
                "Factory setting",
                "Δ factory [1]",
                "Manual [2]",
                "Name",
                "What it controls",
            ],
            table_rows,
            ["left", "right", "left", "left", "center", "center", "left", "left"],
        )
    )

    lines += [
        "",
        "## Capture tool",
        "",
        "[`tools/read-huanyang-vfd.py`](tools/read-huanyang-vfd.py) is deliberately read-only: "
        "its request builder contains only function `0x01`. Do not replace it with `hy_vfd --regdump` "
        "for forensic captures, because the normal `hy_vfd` loop subsequently transmits control and frequency commands.",
        "",
    ]
    args.output.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
