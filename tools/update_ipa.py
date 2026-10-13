#!/usr/bin/env python3
"""Swap the TGExtra dylib and bundle inside an already injected IPA.

The IPA built by telegram.yml already loads @rpath/TGExtra.dylib, so a tweak
change only needs the new dylib (thinned to arm64, as cyan does) and the new
TGExtra.bundle copied in. The signer re-signs every binary afterwards.

usage: python tools/update_ipa.py --ipa base.ipa --deb com.choco.tg_X_iphoneos-arm.deb -o out.ipa
"""
import argparse
import gzip
import hashlib
import io
import lzma
import struct
import sys
import tarfile
import zipfile

DYLIB_NAME = "TGExtra.dylib"
BUNDLE_DIR = "TGExtra.bundle/"
CPU_TYPE_ARM64 = 0x0100000C
CPU_SUBTYPE_ARM64_ALL = 0


def read_ar(data):
    if data[:8] != b"!<arch>\n":
        raise SystemExit("not a .deb (ar) file")
    members, off = {}, 8
    while off < len(data):
        name = data[off:off + 16].decode().strip().rstrip("/")
        size = int(data[off + 48:off + 58].decode().strip())
        members[name] = data[off + 60:off + 60 + size]
        off += 60 + size + (size % 2)
    return members


def deb_files(path):
    members = read_ar(open(path, "rb").read())
    name = next((n for n in members if n.startswith("data.tar")), None)
    if name is None:
        raise SystemExit("data.tar.* not found in .deb")
    raw = members[name]
    if name.endswith((".lzma", ".xz")):
        raw = lzma.decompress(raw)
    elif name.endswith(".gz"):
        raw = gzip.decompress(raw)
    elif not name.endswith(".tar"):
        raise SystemExit(f"unsupported compression: {name}")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
        for m in tar.getmembers():
            if m.isfile():
                files[m.name.lstrip("./")] = tar.extractfile(m).read()
    return files


def thin_arm64(data):
    magic = data[:4]
    if magic in (b"\xcf\xfa\xed\xfe",):
        return data
    if magic not in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        raise SystemExit("dylib is not a Mach-O file")
    is64 = magic == b"\xca\xfe\xba\xbf"
    (count,) = struct.unpack(">I", data[4:8])
    off = 8
    for _ in range(count):
        if is64:
            cputype, subtype, offset, size, _align, _res = struct.unpack(">iiQQII", data[off:off + 32])
            off += 32
        else:
            cputype, subtype, offset, size, _align = struct.unpack(">iiIII", data[off:off + 20])
            off += 20
        if cputype == CPU_TYPE_ARM64 and (subtype & 0x00FFFFFF) == CPU_SUBTYPE_ARM64_ALL:
            return data[offset:offset + size]
    raise SystemExit("no arm64 slice in dylib")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ipa", required=True, help="IPA that already has TGExtra injected")
    ap.add_argument("--deb", required=True, help="TGExtra .deb built by tweak.yml")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    files = deb_files(args.deb)
    dylib_path = next((p for p in files if p.endswith("/" + DYLIB_NAME)), None)
    if dylib_path is None:
        raise SystemExit(f"{DYLIB_NAME} not found in .deb")
    dylib = thin_arm64(files[dylib_path])
    bundle = {p.split("/" + BUNDLE_DIR, 1)[1]: d for p, d in files.items() if "/" + BUNDLE_DIR in p}

    src = zipfile.ZipFile(args.ipa)
    names = src.namelist()
    app = next((n.split("/")[1] for n in names if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/") == 2), None)
    if app is None:
        raise SystemExit("Payload/*.app not found in IPA")
    app_dir = f"Payload/{app}/"
    dylib_entry = app_dir + "Frameworks/" + DYLIB_NAME
    bundle_prefix = app_dir + BUNDLE_DIR
    if dylib_entry not in names:
        raise SystemExit(f"{dylib_entry} not in IPA: inject TGExtra once with ipa.yml/telegram.yml first")

    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as dst:
        for info in src.infolist():
            if info.filename.startswith(bundle_prefix) and not info.is_dir():
                continue
            data = dylib if info.filename == dylib_entry else src.read(info)
            dst.writestr(info, data)
        for rel, data in sorted(bundle.items()):
            info = zipfile.ZipInfo(bundle_prefix + rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.external_attr = 0o644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            dst.writestr(info, data)

    digest = hashlib.sha256(open(args.output, "rb").read()).hexdigest()
    print(f"{args.output}\n  {DYLIB_NAME}: {len(dylib)} bytes (arm64), bundle files: {len(bundle)}\n  sha256: {digest}")


if __name__ == "__main__":
    sys.exit(main())
