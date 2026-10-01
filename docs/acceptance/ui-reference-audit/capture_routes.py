#!/usr/bin/env python3
"""Capture UI routes from a JSON manifest on an attached Android device."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path


PACKAGE = "com.yexufengjing.qingsongban"
COMPONENT = f"{PACKAGE}/.MainActivity"
DEVICE_SCREENSHOT = "/sdcard/qsb-ui-audit.png"
DEVICE_XML = "/sdcard/qsb-ui-audit.xml"


def adb(args: list[str], serial: str | None, *, timeout: int = 30) -> str:
    command = ["adb"]
    if serial:
        command += ["-s", serial]
    result = subprocess.run(
        command + args,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    if result.returncode:
        raise RuntimeError(f"adb {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-.") or "route"


def load_routes(path: Path) -> list[tuple[str, str]]:
    routes = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(routes, list) or not routes:
        raise ValueError("manifest must be a non-empty JSON array")
    result = []
    names = set()
    for index, item in enumerate(routes, 1):
        if not isinstance(item, dict) or not isinstance(item.get("route"), str):
            raise ValueError(f"route {index} must contain a string 'route'")
        route = item["route"].strip()
        if not route.startswith("/"):
            raise ValueError(f"route {index} must start with '/'")
        name = safe_name(str(item.get("name", f"route-{index:02d}")))
        if name in names:
            raise ValueError(f"duplicate route output name: {name}")
        names.add(name)
        result.append((name, route))
    return result


def hierarchy_ready(xml: str) -> bool:
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return False
    labels = set()
    for node in root.iter("node"):
        if node.attrib.get("visible-to-user", "true") != "true":
            continue
        label = (node.attrib.get("text") or node.attrib.get("content-desc") or "").strip()
        if len(label) < 2 or re.fullmatch(r"\d{1,2}:\d{2}|\d+%", label):
            continue
        if label.lower() in {"loading", "please wait", "wifi", "battery", "signal"}:
            continue
        labels.add(label)
    return len(labels) >= 3


def pull(remote: str, destination: Path, serial: str | None) -> None:
    args = ["pull", remote, str(destination)]
    adb(args, serial)
    if not destination.is_file():
        raise RuntimeError(f"adb pull did not create {destination}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("docs/acceptance/ui-reference-audit/final-20261001"),
    )
    parser.add_argument("--serial", default="emulator-5554")
    args = parser.parse_args()

    try:
        routes = load_routes(args.manifest)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        parser.error(str(error))
    args.out_dir.mkdir(parents=True, exist_ok=True)
    log_path = args.out_dir / "capture.log"
    failures = 0

    for name, route in routes:
        started = datetime.now().astimezone().isoformat(timespec="seconds")
        try:
            adb(["shell", "am", "force-stop", PACKAGE], args.serial)
            adb(
                [
                    "shell",
                    "am",
                    "start",
                    "-n",
                    COMPONENT,
                    "--es",
                    "route",
                    route,
                ],
                args.serial,
            )
            time.sleep(4)
            ready = False
            xml_captured = False
            xml = ""
            for _ in range(4):
                try:
                    dump_output = adb(
                        ["shell", "uiautomator", "dump", "--compressed", DEVICE_XML],
                        args.serial,
                    )
                    if "dumped to:" not in dump_output.lower():
                        time.sleep(1)
                        continue
                    xml = adb(["shell", "cat", DEVICE_XML], args.serial)
                    ET.fromstring(xml)
                    xml_captured = True
                except (
                    RuntimeError,
                    OSError,
                    ET.ParseError,
                    subprocess.TimeoutExpired,
                ):
                    time.sleep(1)
                    continue
                if hierarchy_ready(xml):
                    ready = True
                    break
                time.sleep(1)

            if not xml_captured:
                raise RuntimeError("uiautomator did not produce a readable XML hierarchy")

            screenshot = args.out_dir / f"final-{name}.png"
            hierarchy = args.out_dir / f"final-{name}.xml"
            adb(["shell", "screencap", "-p", DEVICE_SCREENSHOT], args.serial)
            pull(DEVICE_SCREENSHOT, screenshot, args.serial)
            pull(DEVICE_XML, hierarchy, args.serial)
            status = "captured; review screenshot before visual acceptance"
            if not ready:
                status = "captured after hierarchy timeout; review required"
            print(f"{name}: {status}")
            with log_path.open("a", encoding="utf-8") as log:
                log.write(
                    f"{started}\t{name}\t{route}\t{status}\t"
                    f"{screenshot.name}\t{hierarchy.name}\n"
                )
            if not ready:
                failures += 1
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
            failures += 1
            finished = datetime.now().astimezone().isoformat(timespec="seconds")
            with log_path.open("a", encoding="utf-8") as log:
                log.write(f"{started}\t{name}\t{route}\terror: {error}\n")
            print(f"{name}: capture failed at {finished}: {error}")
        finally:
            try:
                adb(
                    ["shell", "rm", "-f", DEVICE_SCREENSHOT, DEVICE_XML],
                    args.serial,
                )
            except (RuntimeError, subprocess.TimeoutExpired) as error:
                failures += 1
                with log_path.open("a", encoding="utf-8") as log:
                    log.write(f"{datetime.now().astimezone().isoformat()}\t"
                              f"{name}\t{route}\tdevice cleanup failed: {error}\n")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
