// Read what an Android app *asks for* without installing or running it. A port of engine/scamsaathi/apk.py: both must give identical
// output on the files in packs/core/apk. Only the manifest is read, so a trap with few permissions is not seen: this finds dangerous
// *requests*, not every bad app. Works in the browser too (no dart:io).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as hash;

const _maxManifest = 5 * 1024 * 1024;
const _maxAttributes = 2000;

/// The file is not an APK we can read. [message] is safe to show.
class ApkError implements Exception {
  final String message;
  const ApkError(this.message);
  @override
  String toString() => message;
}

class ApkInfo {
  final String package, label, sha256;
  final List<String> permissions, componentPermissions, actions;
  final int? minSdk, targetSdk;
  String fileName;
  ApkInfo({
    required this.package,
    required this.label,
    required this.permissions,
    required this.componentPermissions,
    required this.actions,
    required this.minSdk,
    required this.targetSdk,
    required this.sha256,
    this.fileName = '',
  });
}

ApkInfo parseApk(Uint8List data) {
  Uint8List raw;
  try {
    final file = ZipDecoder().decodeBytes(data).findFile('AndroidManifest.xml');
    if (file == null) throw const ApkError('this does not look like an Android app (no readable AndroidManifest.xml)');
    if (file.size > _maxManifest) throw const ApkError('the manifest is too large to be real');
    raw = Uint8List.fromList(file.readBytes()!);
  } on ApkError {
    rethrow;
  } catch (_) {
    throw const ApkError('this does not look like an Android app (no readable AndroidManifest.xml)');
  }
  return parseManifest(raw, sha256: hash.sha256.convert(data).toString());
}

List<String> _stringPool(ByteData b, int off, int headerSize) {
  final count = b.getUint32(off + 8, Endian.little);
  final flags = b.getUint32(off + 16, Endian.little);
  final stringsStart = b.getUint32(off + 20, Endian.little);
  if (count > 100000) throw const ApkError('string table is implausibly large');
  final utf8Flag = (flags & 0x100) != 0;
  final base = off + stringsStart;
  final out = <String>[];
  for (var i = 0; i < count; i++) {
    var p = base + b.getUint32(off + headerSize + 4 * i, Endian.little);
    if (utf8Flag) {
      p += (b.getUint8(p) & 0x80) != 0 ? 2 : 1; // length in characters: not needed
      var n = b.getUint8(p);
      if ((n & 0x80) != 0) {
        n = ((n & 0x7F) << 8) | b.getUint8(p + 1);
        p += 2;
      } else {
        p += 1;
      }
      out.add(utf8.decode(Uint8List.sublistView(b, p, p + n), allowMalformed: true));
    } else {
      var n = b.getUint16(p, Endian.little);
      if ((n & 0x8000) != 0) {
        n = ((n & 0x7FFF) << 16) | b.getUint16(p + 2, Endian.little);
        p += 4;
      } else {
        p += 2;
      }
      final units = <int>[for (var k = 0; k < n; k++) b.getUint16(p + 2 * k, Endian.little)];
      out.add(String.fromCharCodes(units));
    }
  }
  return out;
}

ApkInfo parseManifest(Uint8List bytes, {String sha256 = ''}) {
  final perms = <String>{}, compPerms = <String>{}, actions = <String>{};
  var package = '', label = '';
  int? minSdk, targetSdk;
  try {
    final b = ByteData.sublistView(bytes);
    if (b.getUint16(0, Endian.little) != 0x0003) throw const ApkError("AndroidManifest.xml is not in Android's binary XML format");
    final header = b.getUint16(2, Endian.little);
    final end = b.getUint32(4, Endian.little) < bytes.length ? b.getUint32(4, Endian.little) : bytes.length;
    var strings = <String>[];
    final stack = <String>[];
    var off = header, seen = 0;
    while (off + 8 <= end) {
      final ctype = b.getUint16(off, Endian.little);
      final chdr = b.getUint16(off + 2, Endian.little);
      final csize = b.getUint32(off + 4, Endian.little);
      if (csize < 8) throw const ApkError('the manifest is damaged');
      if (ctype == 0x0001) {
        strings = _stringPool(b, off, chdr);
      } else if (ctype == 0x0102) {
        final nameIdx = b.getInt32(off + 20, Endian.little);
        final attrStart = b.getUint16(off + 24, Endian.little);
        final attrSize = b.getUint16(off + 26, Endian.little);
        final attrCount = b.getUint16(off + 28, Endian.little);
        final tag = strings[nameIdx];
        seen += attrCount;
        if (seen > _maxAttributes) throw const ApkError('the manifest has implausibly many attributes');
        final attrs = <String, Object>{};
        for (var i = 0; i < attrCount; i++) {
          final a = off + 16 + attrStart + i * attrSize;
          final aName = b.getInt32(a + 4, Endian.little);
          final rawValue = b.getInt32(a + 8, Endian.little);
          final dtype = b.getUint8(a + 15);
          final data = b.getUint32(a + 16, Endian.little);
          final key = strings[aName];
          if (dtype == 0x03) {
            attrs[key] = rawValue >= 0 ? strings[rawValue] : strings[data];
          } else if (dtype == 0x10) {
            attrs[key] = data;
          } else if (dtype == 0x12) {
            attrs[key] = data != 0;
          }
        }
        stack.add(tag);
        final name = attrs['name'], perm = attrs['permission'];
        if (tag == 'manifest') {
          package = (attrs['package'] ?? '').toString();
        } else if (tag == 'uses-sdk') {
          if (attrs['minSdkVersion'] is int) minSdk = attrs['minSdkVersion'] as int;
          if (attrs['targetSdkVersion'] is int) targetSdk = attrs['targetSdkVersion'] as int;
        } else if ((tag == 'uses-permission' || tag == 'uses-permission-sdk-23') && name is String) {
          perms.add(name);
        } else if (tag == 'application' && attrs['label'] is String) {
          label = attrs['label'] as String;
        } else if ((tag == 'service' || tag == 'receiver' || tag == 'activity' || tag == 'provider') && perm is String) {
          compPerms.add(perm);
        } else if (tag == 'action' && stack.length >= 2 && stack[stack.length - 2] == 'intent-filter' && name is String) {
          actions.add(name);
        }
      } else if (ctype == 0x0103) {
        if (stack.isNotEmpty) stack.removeLast();
      }
      off += csize;
    }
  } on ApkError {
    rethrow;
  } catch (_) {
    throw const ApkError('the manifest is damaged'); // RangeError, FormatException, ...: never leak an unexpected exception
  }
  List<String> sorted(Set<String> s) => s.toList()..sort();
  return ApkInfo(
    package: package, label: label, permissions: sorted(perms), componentPermissions: sorted(compPerms), actions: sorted(actions),
    minSdk: minSdk, targetSdk: targetSdk, sha256: sha256,
  );
}
