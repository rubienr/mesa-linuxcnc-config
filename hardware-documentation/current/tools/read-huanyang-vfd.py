#!/usr/bin/env python3
"""Read Huanyang VFD PD parameters without implementing any write command."""

from __future__ import annotations

import argparse
import json
import os
import select
import sys
import termios
import time
from datetime import datetime, timezone


READ_PARAMETER = 0x01


def crc16_modbus(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


def read_frame(fd: int, timeout: float) -> bytes:
    deadline = time.monotonic() + timeout
    response = bytearray()
    expected = None
    while time.monotonic() < deadline:
        remaining = deadline - time.monotonic()
        readable, _, _ = select.select([fd], [], [], remaining)
        if not readable:
            break
        chunk = os.read(fd, 64)
        if not chunk:
            break
        response.extend(chunk)
        if expected is None and len(response) >= 3:
            expected = response[2] + 5
        if expected is not None and len(response) >= expected:
            return bytes(response[:expected])
    raise TimeoutError(f"incomplete response: {response.hex(' ')}")


def query_parameter(
    fd: int, target: int, parameter: int, timeout: float
) -> tuple[int | None, str, str, str]:
    # This is the only request shape this program can construct:
    # target, Huanyang FUNCTION_READ, length=3, PD number, data=0.
    body = bytes((target, READ_PARAMETER, 0x03, parameter, 0x00, 0x00))
    crc = crc16_modbus(body)
    request = body + bytes((crc & 0xFF, crc >> 8))

    termios.tcflush(fd, termios.TCIFLUSH)
    os.write(fd, request)
    response = read_frame(fd, timeout)

    if len(response) < 6:
        raise ValueError(f"short response: {response.hex(' ')}")
    response_crc = response[-2] | response[-1] << 8
    calculated_crc = crc16_modbus(response[:-2])
    if response_crc != calculated_crc:
        raise ValueError(
            f"CRC mismatch: received 0x{response_crc:04x}, calculated 0x{calculated_crc:04x}"
        )
    if response[0] != target:
        raise ValueError(f"unexpected target {response[0]}")
    if (
        response[1] == (READ_PARAMETER | 0x80)
        and response[2] == 1
        and response[3] == parameter
    ):
        return None, request.hex(" "), response.hex(" "), "unsupported"
    if response[1] != READ_PARAMETER:
        raise ValueError(f"unexpected function 0x{response[1]:02x}")
    if response[3] != parameter:
        raise ValueError(f"response is for PD{response[3]:03d}")

    data_length = response[2]
    if data_length == 2:
        value = response[4]
    elif data_length == 3:
        value = response[4] << 8 | response[5]
    else:
        raise ValueError(f"unexpected data length {data_length}")
    return value, request.hex(" "), response.hex(" "), "ok"


def configure_port(fd: int, baud: int) -> list:
    speeds = {
        4800: termios.B4800,
        9600: termios.B9600,
        19200: termios.B19200,
        38400: termios.B38400,
    }
    if baud not in speeds:
        raise ValueError(f"unsupported baud rate {baud}")

    original = termios.tcgetattr(fd)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
    attrs[3] = 0
    attrs[4] = speeds[baud]
    attrs[5] = speeds[baud]
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    return original


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="/dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=19200)
    parser.add_argument("--target", type=int, default=1)
    parser.add_argument("--first", type=int, default=0)
    parser.add_argument("--last", type=int, default=183)
    parser.add_argument("--timeout", type=float, default=0.75)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--output", help="write the complete result as JSON")
    parser.add_argument(
        "--show-frame",
        action="store_true",
        help="include request and response bytes in terminal output",
    )
    args = parser.parse_args()

    if not 1 <= args.target <= 254:
        parser.error("target must be in the range 1..254")
    if not 0 <= args.first <= args.last <= 255:
        parser.error("register range must satisfy 0 <= first <= last <= 255")

    fd = os.open(args.device, os.O_RDWR | os.O_NOCTTY | os.O_CLOEXEC)
    original = configure_port(fd, args.baud)
    records = []
    try:
        for parameter in range(args.first, args.last + 1):
            record = {"parameter": f"PD{parameter:03d}", "number": parameter}
            for attempt in range(args.retries + 1):
                try:
                    value, request, response, status = query_parameter(
                        fd, args.target, parameter, args.timeout
                    )
                    record.update(
                        status=status, request=request, response=response
                    )
                    if value is not None:
                        record["raw_value"] = value
                    break
                except (TimeoutError, ValueError, OSError) as error:
                    record.update(status="error", error=str(error))
                    if attempt < args.retries:
                        time.sleep(0.05)
            records.append(record)
            line = f"{record['parameter']} = "
            if record["status"] == "ok":
                line += str(record["raw_value"])
            elif record["status"] == "unsupported":
                line += "UNSUPPORTED"
            else:
                line += record["error"]
            if args.show_frame and record["status"] != "error":
                line += f"  TX[{record['request']}] RX[{record['response']}]"
            print(line, flush=True)
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, original)
        os.close(fd)

    result = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "device": args.device,
        "baud": args.baud,
        "format": "8N1",
        "target": args.target,
        "protocol": "Huanyang proprietary RTU",
        "transmitted_function_codes": [READ_PARAMETER],
        "registers": records,
    }
    if args.output:
        with open(args.output, "w", encoding="utf-8") as stream:
            json.dump(result, stream, indent=2)
            stream.write("\n")

    failures = sum(record["status"] == "error" for record in records)
    supported = sum(record["status"] == "ok" for record in records)
    unsupported = sum(record["status"] == "unsupported" for record in records)
    print(
        f"read {supported} values; {unsupported} unsupported; {failures} errors",
        file=sys.stderr,
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
