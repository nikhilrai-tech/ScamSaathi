"""Read what an Android app *asks for* without installing or running it.

An APK is a zip file. Its AndroidManifest.xml is stored in Android's binary XML format. This module reads that one file and reports the
package name, the permissions the app requests, the permissions it requires of its own services and receivers (this is how an
accessibility-service or device-admin app declares itself), and the system events it listens for (such as an incoming SMS).

Nothing is executed. Only the manifest is looked at, so an app that asks for few permissions can still be a trap: this finds the
dangerous *requests*, not every bad app. The Dart version (app/lib/engine/apk.dart) must give identical output; both are tested on the
same files in packs/core/apk/."""
from __future__ import annotations

import hashlib
import io
import struct
import zipfile

MAX_MANIFEST = 5 * 1024 * 1024  # a real manifest is a few KB; anything this large is not one
MAX_ATTRIBUTES = 2000
_STRING, _INT, _BOOL = 0x03, 0x10, 0x12


class ApkError(ValueError):
    """The file is not an APK we can read. The message is safe to show."""


def parse_apk(data: bytes) -> dict:
    """APK bytes -> {package, label, permissions, component_permissions, actions, min_sdk, target_sdk, sha256}."""
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            info = z.getinfo("AndroidManifest.xml")
            if info.file_size > MAX_MANIFEST:
                raise ApkError("the manifest is too large to be real")
            raw = z.read(info)
    except (zipfile.BadZipFile, KeyError, zlib_error, NotImplementedError, RuntimeError) as exc:
        raise ApkError("this does not look like an Android app (no readable AndroidManifest.xml)") from exc
    result = parse_manifest(raw)
    result["sha256"] = hashlib.sha256(data).hexdigest()
    return result


try:  # zlib.error is what a corrupt compressed entry raises
    from zlib import error as zlib_error
except ImportError:  # pragma: no cover
    zlib_error = ValueError


def _string_pool(b: bytes, off: int, header_size: int) -> list:
    count, _styles, flags, strings_start, _styles_start = struct.unpack_from("<IIIII", b, off + 8)
    if count > 100000:
        raise ApkError("string table is implausibly large")
    utf8 = bool(flags & 0x100)
    base = off + strings_start
    out = []
    for i in range(count):
        (rel,) = struct.unpack_from("<I", b, off + header_size + 4 * i)
        p = base + rel
        if utf8:
            if b[p] & 0x80:  # length in characters (we only need the byte length)
                p += 2
            else:
                p += 1
            n = b[p]
            if n & 0x80:
                n = ((n & 0x7F) << 8) | b[p + 1]
                p += 2
            else:
                p += 1
            out.append(b[p:p + n].decode("utf-8", errors="replace"))
        else:
            (n,) = struct.unpack_from("<H", b, p)
            if n & 0x8000:
                (low,) = struct.unpack_from("<H", b, p + 2)
                n = ((n & 0x7FFF) << 16) | low
                p += 4
            else:
                p += 2
            out.append(b[p:p + 2 * n].decode("utf-16-le", errors="replace"))
    return out


def parse_manifest(b: bytes) -> dict:
    result = {"package": "", "label": "", "permissions": set(), "component_permissions": set(), "actions": set(),
              "min_sdk": None, "target_sdk": None}
    try:
        kind, header, size = struct.unpack_from("<HHI", b, 0)
        if kind != 0x0003:
            raise ApkError("AndroidManifest.xml is not in Android's binary XML format")
        strings = []
        stack = []
        off = header
        end = min(size, len(b))
        attributes_seen = 0
        while off + 8 <= end:
            ctype, chdr, csize = struct.unpack_from("<HHI", b, off)
            if csize < 8:
                raise ApkError("the manifest is damaged")
            if ctype == 0x0001:
                strings = _string_pool(b, off, chdr)
            elif ctype == 0x0102:  # start of an element
                _line, _comment, _ns, name_idx, attr_start, attr_size, attr_count = struct.unpack_from("<IiiiHHH", b, off + 8)
                tag = strings[name_idx]
                attributes_seen += attr_count
                if attributes_seen > MAX_ATTRIBUTES:
                    raise ApkError("the manifest has implausibly many attributes")
                attrs = {}
                for i in range(attr_count):
                    a = off + 16 + attr_start + i * attr_size
                    _ns, a_name, raw_value, _size, _res, dtype, data = struct.unpack_from("<iiiHBBI", b, a)
                    key = strings[a_name]
                    if dtype == _STRING:
                        attrs[key] = strings[raw_value] if raw_value >= 0 else strings[data]
                    elif dtype == _INT:
                        attrs[key] = data
                    elif dtype == _BOOL:
                        attrs[key] = bool(data)
                stack.append(tag)
                _collect(tag, attrs, stack, result)
            elif ctype == 0x0103:  # end of an element
                if stack:
                    stack.pop()
            off += csize
    except (struct.error, IndexError, UnicodeDecodeError) as exc:
        raise ApkError("the manifest is damaged") from exc
    for key in ("permissions", "component_permissions", "actions"):
        result[key] = sorted(result[key])
    return result


def _collect(tag: str, attrs: dict, stack: list, result: dict) -> None:
    if tag == "manifest":
        result["package"] = str(attrs.get("package", ""))
    elif tag == "uses-sdk":
        for k, dest in (("minSdkVersion", "min_sdk"), ("targetSdkVersion", "target_sdk")):
            if isinstance(attrs.get(k), int):
                result[dest] = attrs[k]
    elif tag in ("uses-permission", "uses-permission-sdk-23") and isinstance(attrs.get("name"), str):
        result["permissions"].add(attrs["name"])
    elif tag == "application" and isinstance(attrs.get("label"), str):
        result["label"] = attrs["label"]
    elif tag in ("service", "receiver", "activity", "provider") and isinstance(attrs.get("permission"), str):
        result["component_permissions"].add(attrs["permission"])
    elif tag == "action" and len(stack) >= 2 and stack[-2] == "intent-filter" and isinstance(attrs.get("name"), str):
        result["actions"].add(attrs["name"])
