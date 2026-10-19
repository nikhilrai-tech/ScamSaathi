import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../engine/engine.dart';

/// Verifies a rule pack against the Ed25519 public key pinned in the app. Anything else is rejected.
class PackVerifier {
  final String publicKeyBase64;
  PackVerifier(this.publicKeyBase64);

  List<int> get _publicRaw => base64.decode(publicKeyBase64.trim());

  String get keyId => hash.sha256.convert(_publicRaw).toString().substring(0, 16);

  Future<bool> verify(List<int> packBytes, Map<String, dynamic> sig) async {
    try {
      if (sig['alg'] != 'ed25519' || sig['key_id'] != keyId) return false;
      if (sig['sha256'] != hash.sha256.convert(packBytes).toString()) return false;
      final ok = await Ed25519().verify(
        packBytes,
        signature: Signature(
          base64.decode(sig['signature'] as String),
          publicKey: SimplePublicKey(_publicRaw, type: KeyPairType.ed25519),
        ),
      );
      if (!ok) return false;
      return Pack.fromBytes(packBytes).version == sig['version'];
    } catch (_) {
      return false; // malformed anything: fail closed
    }
  }
}

/// Where an updated (downloaded) pack and its signature are kept.
abstract class PackStorage {
  Future<(List<int>, Map<String, dynamic>)?> read();
  Future<void> write(List<int> packBytes, Map<String, dynamic> sig);
}

class FilePackStorage implements PackStorage {
  Future<Directory> _dir() async => Directory('${(await getApplicationSupportDirectory()).path}/packs')..createSync(recursive: true);

  @override
  Future<(List<int>, Map<String, dynamic>)?> read() async {
    final d = await _dir();
    final p = File('${d.path}/pack.json'), s = File('${d.path}/pack.sig.json');
    if (!p.existsSync() || !s.existsSync()) return null;
    return (p.readAsBytesSync(), jsonDecode(s.readAsStringSync()) as Map<String, dynamic>);
  }

  @override
  Future<void> write(List<int> packBytes, Map<String, dynamic> sig) async {
    final d = await _dir();
    File('${d.path}/pack.json').writeAsBytesSync(packBytes);
    File('${d.path}/pack.sig.json').writeAsStringSync(jsonEncode(sig));
  }
}

class MemoryPackStorage implements PackStorage {
  (List<int>, Map<String, dynamic>)? value;
  @override
  Future<(List<int>, Map<String, dynamic>)?> read() async => value;
  @override
  Future<void> write(List<int> packBytes, Map<String, dynamic> sig) async => value = (packBytes, sig);
}

enum UpdateResult { updated, upToDate, rejected, offline }

/// The bundled pack always works offline. A downloaded pack is used only if it verifies against the pinned key
/// (re-checked on every load) and has a higher version than the bundled one. Downgrades are never accepted.
class PackStore {
  final PackVerifier verifier;
  final PackStorage storage;
  final List<int> bundledBytes;
  Pack _current;

  PackStore._(this.verifier, this.storage, this.bundledBytes, this._current);

  Pack get current => _current;

  static Future<PackStore> load({required PackVerifier verifier, required PackStorage storage, required List<int> bundled}) async {
    var best = Pack.fromBytes(bundled);
    final stored = await storage.read();
    if (stored != null && await verifier.verify(stored.$1, stored.$2)) {
      final candidate = Pack.fromBytes(stored.$1);
      if (candidate.version > best.version) best = candidate;
    }
    return PackStore._(verifier, storage, bundled, best);
  }

  Future<UpdateResult> update(http.Client client, Uri base) async {
    try {
      final mres = await client.get(base.resolve('/v1/packs/core/manifest')).timeout(const Duration(seconds: 15));
      if (mres.statusCode != 200) return UpdateResult.offline;
      final manifest = jsonDecode(mres.body) as Map<String, dynamic>;
      final version = manifest['version'];
      if (version is! int) return UpdateResult.rejected;
      if (version <= _current.version) return UpdateResult.upToDate;
      final pres = await client.get(base.resolve(manifest['url'] as String)).timeout(const Duration(seconds: 30));
      if (pres.statusCode != 200) return UpdateResult.offline;
      final sig = {
        'alg': manifest['alg'], 'key_id': manifest['key_id'], 'version': version,
        'sha256': manifest['sha256'], 'signature': manifest['signature'],
      };
      if (!await verifier.verify(pres.bodyBytes, sig)) return UpdateResult.rejected;
      await storage.write(pres.bodyBytes, sig);
      _current = Pack.fromBytes(pres.bodyBytes);
      return UpdateResult.updated;
    } on Exception {
      return UpdateResult.offline;
    }
  }
}
