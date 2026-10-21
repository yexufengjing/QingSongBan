"""Read-only, in-memory check of the wage XLSX currently in Android Downloads."""

from __future__ import annotations

import argparse
import io
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from decimal import Decimal, InvalidOperation
from pathlib import PurePosixPath


def _xml_texts(root: ET.Element, tag: str) -> list[str]:
    return [node.text or "" for node in root.iter(tag)]


def _package_values(package: zipfile.ZipFile, sheet_name: str) -> tuple[bool, list[str]]:
    ns = {
        "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
        "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
        "pkg": "http://schemas.openxmlformats.org/package/2006/relationships",
    }
    workbook = ET.fromstring(package.read("xl/workbook.xml"))
    rels = ET.fromstring(package.read("xl/_rels/workbook.xml.rels"))
    targets = {
        rel.attrib["Id"]: rel.attrib["Target"]
        for rel in rels.findall("pkg:Relationship", ns)
    }
    sheet = next(
        (
            node
            for node in workbook.findall("main:sheets/main:sheet", ns)
            if node.attrib.get("name") == sheet_name
        ),
        None,
    )
    if sheet is None:
        return False, []
    target = targets.get(sheet.attrib.get(f"{{{ns['rel']}}}id", ""))
    if not target:
        return False, []
    sheet_path = str(PurePosixPath("xl") / target)
    while sheet_path.startswith("xl/xl/"):
        sheet_path = sheet_path[3:]
    root = ET.fromstring(package.read(sheet_path))
    strings: list[str] = []
    if "xl/sharedStrings.xml" in package.namelist():
        shared = ET.fromstring(package.read("xl/sharedStrings.xml"))
        strings = [
            "".join(_xml_texts(item, f"{{{ns['main']}}}t"))
            for item in shared.findall("main:si", ns)
        ]
    values: list[str] = []
    for cell in root.findall(".//main:c", ns):
        cell_type = cell.attrib.get("t")
        if cell_type == "s":
            value = cell.findtext("main:v", default="", namespaces=ns)
            try:
                values.append(strings[int(value)])
            except (ValueError, IndexError):
                continue
        elif cell_type == "inlineStr":
            values.append("".join(_xml_texts(cell, f"{{{ns['main']}}}t")))
        else:
            value = cell.findtext("main:v", default="", namespaces=ns)
            if value:
                values.append(value)
    return True, values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--filename", default="2026年10月临时工工资表.xlsx")
    parser.add_argument("--employee-no", default="DEMO-ASSISTANT-EMP-001")
    parser.add_argument("--amount", default="4500.00")
    args = parser.parse_args()

    result = subprocess.run(
        [
            "adb",
            "-s",
            args.serial,
            "exec-out",
            "cat",
            f"/sdcard/Download/{args.filename}",
        ],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0 or not result.stdout:
        print(json.dumps({"downloadRead": False}, ensure_ascii=False))
        return 1

    try:
        with zipfile.ZipFile(io.BytesIO(result.stdout)) as package:
            package.testzip()
            has_sheet, values = _package_values(package, "临时工工资")
        has_employee = args.employee_no in values
        amount = Decimal(args.amount)
        has_amount = False
        for value in values:
            try:
                if Decimal(value.replace(",", "")) == amount:
                    has_amount = True
                    break
            except (InvalidOperation, AttributeError):
                continue
        status = {
            "downloadRead": True,
            "zipXmlValid": has_sheet,
            "wageSheetPresent": has_sheet,
            "demoEmployeePresent": has_employee,
            "expectedAmountPresent": has_amount,
        }
        print(json.dumps(status, ensure_ascii=False))
        return 0 if all(status.values()) else 1
    except (OSError, KeyError, ET.ParseError, zipfile.BadZipFile, InvalidOperation):
        print(
            json.dumps(
                {
                    "downloadRead": True,
                    "zipXmlValid": False,
                    "wageSheetPresent": False,
                    "demoEmployeePresent": False,
                    "expectedAmountPresent": False,
                },
                ensure_ascii=False,
            )
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
