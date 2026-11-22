#!/usr/bin/env python3
"""Generate a minimal DNF repository from a directory containing RPM files.

This fallback avoids requiring createrepo/createrepo_c for the very small
kinmin-branding repository. It generates primary, filelists and other metadata
plus repomd.xml using only the Python standard library and the rpm CLI.
"""

from __future__ import annotations

import gzip
import hashlib
import struct
import subprocess
import sys
import time
from pathlib import Path
from xml.sax.saxutils import escape

RPM_MAGIC = b"\x8e\xad\xe8\x01\x00\x00\x00\x00"
DEP_FLAGS = {
    "=": "EQ",
    "<=": "LE",
    ">=": "GE",
    "<": "LT",
    ">": "GT",
}


def q(path: Path, query: str) -> str:
    result = subprocess.run(
        ["rpm", "-qp", "--qf", query, str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def q_list(path: Path, query: str) -> list[str]:
    return [line.strip() for line in q(path, query).splitlines() if line.strip()]


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def gzip_bytes(data: bytes) -> bytes:
    return gzip.compress(data, compresslevel=9, mtime=0)


def header_range(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:4] != b"\xed\xab\xee\xdb":
        raise ValueError(f"not an RPM file: {path}")

    def header_end(offset: int) -> int:
        if data[offset : offset + 8] != RPM_MAGIC:
            raise ValueError(f"invalid RPM header at offset {offset}: {path}")
        count, store_size = struct.unpack(">II", data[offset + 8 : offset + 16])
        store_offset = offset + 16 + 16 * count
        return store_offset + store_size

    signature_end = header_end(96)
    main_start = (signature_end + 7) & ~7
    return main_start, header_end(main_start)


def split_evr(evr: str) -> tuple[str, str, str]:
    epoch = "0"
    if ":" in evr:
        epoch, evr = evr.split(":", 1)
    version, sep, release = evr.partition("-")
    return epoch, version, release if sep else ""


def dependency_entries(values: list[str], element: str) -> str:
    lines: list[str] = []
    for value in values:
        parts = value.split()
        if len(parts) >= 3 and parts[1] in DEP_FLAGS:
            name, flag, evr = parts[0], parts[1], parts[2]
            epoch, version, release = split_evr(evr)
            attrs = (
                f'name="{escape(name)}" flags="{DEP_FLAGS[flag]}" '
                f'epoch="{escape(epoch)}" ver="{escape(version)}"'
            )
            if release:
                attrs += f' rel="{escape(release)}"'
        else:
            attrs = f'name="{escape(value)}"'
        lines.append(f"      <rpm:entry {attrs}/>")
    if not lines:
        return f"    <rpm:{element}/>"
    return "\n".join([f"    <rpm:{element}>", *lines, f"    </rpm:{element}>"])


def package_metadata(rpm_path: Path, href: str, pkgid: str) -> dict[str, object]:
    start, end = header_range(rpm_path)
    files = q_list(rpm_path, "[%{FILENAMES}\n]")
    return {
        "name": q(rpm_path, "%{NAME}"),
        "arch": q(rpm_path, "%{ARCH}"),
        "epoch": q(rpm_path, "%{EPOCHNUM}") or "0",
        "version": q(rpm_path, "%{VERSION}"),
        "release": q(rpm_path, "%{RELEASE}"),
        "summary": q(rpm_path, "%{SUMMARY}"),
        "description": q(rpm_path, "%{DESCRIPTION}"),
        "packager": q(rpm_path, "%{PACKAGER}") or "KINMIN Studio",
        "url": q(rpm_path, "%{URL}"),
        "build_time": q(rpm_path, "%{BUILDTIME}") or str(int(rpm_path.stat().st_mtime)),
        "file_time": str(int(rpm_path.stat().st_mtime)),
        "size": q(rpm_path, "%{SIZE}") or "0",
        "archive_size": q(rpm_path, "%{ARCHIVESIZE}") or "0",
        "license": q(rpm_path, "%{LICENSE}"),
        "vendor": q(rpm_path, "%{VENDOR}") or "KINMIN Studio",
        "group": q(rpm_path, "%{GROUP}") or "Applications/System",
        "buildhost": q(rpm_path, "%{BUILDHOST}") or "localhost",
        "sourcerpm": q(rpm_path, "%{SOURCERPM}"),
        "header_start": str(start),
        "header_end": str(end),
        "provides": q_list(rpm_path, "[%{PROVIDENEVRS}\n]"),
        "requires": q_list(rpm_path, "[%{REQUIRENEVRS}\n]"),
        "files": files,
        "href": href,
        "pkgid": pkgid,
    }


def version_attrs(pkg: dict[str, object]) -> str:
    return (
        f'epoch="{escape(str(pkg["epoch"]))}" '
        f'ver="{escape(str(pkg["version"]))}" '
        f'rel="{escape(str(pkg["release"]))}"'
    )


def primary_xml(packages: list[dict[str, object]]) -> bytes:
    body = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<metadata xmlns="http://linux.duke.edu/metadata/common" '
        'xmlns:rpm="http://linux.duke.edu/metadata/rpm" '
        f'packages="{len(packages)}">',
    ]
    for pkg in packages:
        body.extend(
            [
                '<package type="rpm">',
                f'  <name>{escape(str(pkg["name"]))}</name>',
                f'  <arch>{escape(str(pkg["arch"]))}</arch>',
                f'  <version {version_attrs(pkg)}/>',
                '  <checksum type="sha256" pkgid="YES">'
                f'{escape(str(pkg["pkgid"]))}</checksum>',
                f'  <summary>{escape(str(pkg["summary"]))}</summary>',
                f'  <description>{escape(str(pkg["description"]))}</description>',
                f'  <packager>{escape(str(pkg["packager"]))}</packager>',
                f'  <url>{escape(str(pkg["url"]))}</url>',
                f'  <time file="{escape(str(pkg["file_time"]))}" '
                f'build="{escape(str(pkg["build_time"]))}"/>',
                f'  <size package="{escape(str(pkg["size"]))}" '
                f'installed="{escape(str(pkg["size"]))}" '
                f'archive="{escape(str(pkg["archive_size"]))}"/>',
                f'  <location href="{escape(str(pkg["href"]))}"/>',
                "  <format>",
                f'    <rpm:license>{escape(str(pkg["license"]))}</rpm:license>',
                f'    <rpm:vendor>{escape(str(pkg["vendor"]))}</rpm:vendor>',
                f'    <rpm:group>{escape(str(pkg["group"]))}</rpm:group>',
                f'    <rpm:buildhost>{escape(str(pkg["buildhost"]))}</rpm:buildhost>',
                f'    <rpm:sourcerpm>{escape(str(pkg["sourcerpm"]))}</rpm:sourcerpm>',
                '    <rpm:header-range '
                f'start="{escape(str(pkg["header_start"]))}" '
                f'end="{escape(str(pkg["header_end"]))}"/>',
                dependency_entries(list(pkg["provides"]), "provides"),
                dependency_entries(list(pkg["requires"]), "requires"),
                "  </format>",
                "</package>",
            ]
        )
    body.append("</metadata>")
    return ("\n".join(body) + "\n").encode("utf-8")


def filelists_xml(packages: list[dict[str, object]]) -> bytes:
    body = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<filelists xmlns="http://linux.duke.edu/metadata/filelists" '
        f'packages="{len(packages)}">',
    ]
    for pkg in packages:
        body.extend(
            [
                f'<package pkgid="{escape(str(pkg["pkgid"]))}" '
                f'name="{escape(str(pkg["name"]))}" '
                f'arch="{escape(str(pkg["arch"]))}">',
                f'  <version {version_attrs(pkg)}/>',
                "  <files>",
            ]
        )
        body.extend(f'    <file>{escape(str(path))}</file>' for path in pkg["files"])
        body.extend(["  </files>", "</package>"])
    body.append("</filelists>")
    return ("\n".join(body) + "\n").encode("utf-8")


def other_xml(packages: list[dict[str, object]]) -> bytes:
    body = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<otherdata xmlns="http://linux.duke.edu/metadata/other" '
        f'packages="{len(packages)}">',
    ]
    for pkg in packages:
        body.extend(
            [
                f'<package pkgid="{escape(str(pkg["pkgid"]))}" '
                f'name="{escape(str(pkg["name"]))}" '
                f'arch="{escape(str(pkg["arch"]))}">',
                f'  <version {version_attrs(pkg)}/>',
                "  <changelog/>",
                "</package>",
            ]
        )
    body.append("</otherdata>")
    return ("\n".join(body) + "\n").encode("utf-8")


def write_metadata(repo_dir: Path, name: str, data: bytes, timestamp: int) -> dict[str, str]:
    compressed = gzip_bytes(data)
    (repo_dir / "repodata" / name).write_bytes(compressed)
    return {
        "name": name,
        "checksum": sha256_bytes(compressed),
        "open_checksum": sha256_bytes(data),
        "size": str(len(compressed)),
        "open_size": str(len(data)),
        "timestamp": str(timestamp),
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} REPO_DIR", file=sys.stderr)
        return 2

    repo_dir = Path(sys.argv[1]).resolve()
    if not repo_dir.is_dir():
        print(f"ERROR: repository directory does not exist: {repo_dir}", file=sys.stderr)
        return 1

    rpms = sorted(repo_dir.glob("*.rpm"))
    if not rpms:
        print(f"ERROR: no RPM files found in {repo_dir}", file=sys.stderr)
        return 1

    repodata_dir = repo_dir / "repodata"
    repodata_dir.mkdir(parents=True, exist_ok=True)
    for stale in repodata_dir.glob("*.xml*"):
        stale.unlink()

    packages: list[dict[str, object]] = []
    for rpm_path in rpms:
        pkgid = sha256_bytes(rpm_path.read_bytes())
        packages.append(package_metadata(rpm_path, rpm_path.name, pkgid))

    timestamp = int(time.time())
    metadata = [
        ("primary", write_metadata(repo_dir, "primary.xml.gz", primary_xml(packages), timestamp)),
        ("filelists", write_metadata(repo_dir, "filelists.xml.gz", filelists_xml(packages), timestamp)),
        ("other", write_metadata(repo_dir, "other.xml.gz", other_xml(packages), timestamp)),
    ]

    repomd = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<repomd xmlns="http://linux.duke.edu/metadata/repo" '
        'xmlns:rpm="http://linux.duke.edu/metadata/rpm">',
        f"  <revision>{timestamp}</revision>",
    ]
    for data_type, info in metadata:
        repomd.extend(
            [
                f'  <data type="{data_type}">',
                f'    <checksum type="sha256">{info["checksum"]}</checksum>',
                f'    <open-checksum type="sha256">{info["open_checksum"]}</open-checksum>',
                f'    <location href="repodata/{info["name"]}"/>',
                f'    <timestamp>{info["timestamp"]}</timestamp>',
                f'    <size>{info["size"]}</size>',
                f'    <open-size>{info["open_size"]}</open-size>',
                "  </data>",
            ]
        )
    repomd.append("</repomd>")
    (repodata_dir / "repomd.xml").write_text("\n".join(repomd) + "\n", encoding="utf-8")

    print(f"Generated repository metadata for {len(packages)} package(s) in {repo_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
