import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' show Scrypt, ScryptParameters;

final _random = Random.secure();
String randomToken([int bytes = 32]) => base64Url
    .encode(List.generate(bytes, (_) => _random.nextInt(256)))
    .replaceAll('=', '');
String digestToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();
String _hex(List<int> bytes) =>
    bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

/// Per-account random salt and scrypt password derivation.
String hashPassword(String password, {String? salt}) {
  salt ??= _hex(List.generate(16, (_) => _random.nextInt(256)));
  final scrypt = Scrypt()
    ..init(
      ScryptParameters(16384, 8, 1, 64, Uint8List.fromList(utf8.encode(salt))),
    );
  final key = scrypt.process(Uint8List.fromList(utf8.encode(password)));
  return '$salt:${_hex(key)}';
}

bool constantTimeEquals(String a, String b) {
  final left = utf8.encode(a), right = utf8.encode(b);
  var different = left.length ^ right.length;
  for (var i = 0; i < max(left.length, right.length); i++) {
    different |=
        (i < left.length ? left[i] : 0) ^ (i < right.length ? right[i] : 0);
  }
  return different == 0;
}

bool verifyPassword(String password, String encoded) {
  final parts = encoded.split(':');
  if (parts.length != 2 ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(parts[0]) ||
      !RegExp(r'^[a-f0-9]{128}$').hasMatch(parts[1])) {
    return false;
  }
  return constantTimeEquals(encoded, hashPassword(password, salt: parts[0]));
}
