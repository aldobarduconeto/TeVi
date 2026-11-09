import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/apple_identity.dart';
import '../models/service_error.dart';
import 'core/security.dart';
import 'platform_support.dart';

/// Public Apple Sign In configuration for mobile targets (iOS & Android).
class AppleOidcConfig {
  static const clientId = String.fromEnvironment('APPLE_CLIENT_ID');
  static const bundleId = 'com.awesome.tevi';
  static final rawNonce = randomToken(32);
  static String get nonceSha256 =>
      crypto.sha256.convert(utf8.encode(rawNonce)).toString();

  static bool get supported => PlatformSupport.current.appleLogin;
  static bool get configured =>
      supported &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static Set<String> get audiences => {
    bundleId,
    if (clientId.isNotEmpty) clientId,
  };
}

class AppleAuthResult {
  const AppleAuthResult({
    required this.identityToken,
    this.givenName,
    this.familyName,
    this.email,
  });

  final String identityToken;
  final String? givenName;
  final String? familyName;
  final String? email;

  String get fullName {
    final parts = [givenName, familyName]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty);
    return parts.join(' ').trim();
  }
}

class AppleOidcService {
  Future<AppleAuthResult?> authenticate() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: AppleOidcConfig.nonceSha256,
      );

      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw const ServiceError(
          401,
          'A Apple não retornou um ID Token válido. Verifique a configuração.',
        );
      }

      return AppleAuthResult(
        identityToken: token,
        givenName: credential.givenName,
        familyName: credential.familyName,
        email: credential.email,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw ServiceError(
        401,
        'Não foi possível entrar com Apple: ${e.message}',
      );
    } catch (e) {
      if (e is ServiceError) rethrow;
      throw const ServiceError(
        401,
        'Não foi possível autenticar com Apple. Tente novamente.',
      );
    }
  }
}

/// Cryptographic verifier for Apple ID Tokens using Apple's public JWKS.
class AppleTokenVerifier {
  AppleTokenVerifier({
    http.Client? client,
    Set<String>? audiences,
    String? nonceSha256,
    DateTime Function()? clock,
  })  : _client = client,
        _audiences = audiences ?? AppleOidcConfig.audiences,
        _nonceSha256 = nonceSha256 ?? AppleOidcConfig.nonceSha256,
        _clock = clock ?? DateTime.now;

  final http.Client? _client;
  final Set<String> _audiences;
  final String _nonceSha256;
  final DateTime Function() _clock;
  Map<String, dynamic> _keys = {};
  DateTime? _expires;

  Future<void> _loadKeys() async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('https://appleid.apple.com/auth/keys'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const ServiceError(
          503,
          'Não foi possível consultar as chaves públicas da Apple.',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _keys = {
        for (final key in json['keys'] as List)
          if (key['kty'] == 'RSA')
            key['kid'] as String: key,
      };
      final maxAge = int.tryParse(
            RegExp(r'max-age=(\d+)')
                    .firstMatch(response.headers['cache-control'] ?? '')
                    ?.group(1) ??
                '',
          ) ??
          3600;
      _expires = _clock().add(Duration(seconds: maxAge.clamp(60, 86400)));
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<AppleIdentity> verify(
    String token, {
    String? fallbackName,
    Duration? maxAge,
  }) async {
    try {
      if (token.length > 16384) throw const FormatException();
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();

      Map<String, dynamic> decode(String part) => Map<String, dynamic>.from(
            jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part)))),
          );

      final header = decode(parts[0]);
      if (header['alg'] != 'RS256' || header['kid'] is! String) {
        throw const FormatException();
      }

      if (_expires == null || !_expires!.isAfter(_clock())) await _loadKeys();
      if (!_keys.containsKey(header['kid'])) await _loadKeys();

      final key = _keys[header['kid']];
      if (key == null) throw const FormatException();

      BigInt integer(String value) => BigInt.parse(
            base64Url
                .decode(base64Url.normalize(value))
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(),
            radix: 16,
          );

      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201')
        ..init(
          false,
          PublicKeyParameter<RSAPublicKey>(
            RSAPublicKey(integer(key['n'] as String), integer(key['e'] as String)),
          ),
        );

      if (!verifier.verifySignature(
        Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
        RSASignature(base64Url.decode(base64Url.normalize(parts[2]))),
      )) {
        throw const FormatException('Assinatura do token Apple inválida.');
      }

      final claims = decode(parts[1]);
      final now = _clock().millisecondsSinceEpoch / 1000;
      final aud = claims['aud'];
      final audience = aud is String
          ? [aud]
          : aud is List
              ? aud.cast<String>()
              : <String>[];

      final matchesAudience = _audiences.isEmpty ||
          audience.any(_audiences.contains);

      if (claims['iss'] != 'https://appleid.apple.com' ||
          !matchesAudience ||
          claims['exp'] is! num ||
          !claims['exp'].isFinite ||
          claims['exp'] <= now ||
          claims['iat'] is! num ||
          !claims['iat'].isFinite ||
          claims['iat'] > now + 60 ||
          (maxAge != null && now - claims['iat'] > maxAge.inSeconds) ||
          claims['exp'] <= claims['iat'] ||
          claims['sub'] is! String ||
          (claims['sub'] as String).isEmpty) {
        throw const FormatException('Reivindicações do token Apple inválidas.');
      }

      if (claims['nonce'] != null &&
          claims['nonce'] != _nonceSha256 &&
          claims['nonce'] != AppleOidcConfig.rawNonce) {
        throw const FormatException('Nonce do token Apple incorreto.');
      }

      final email = claims['email'] is String ? claims['email'] as String : '';

      return AppleIdentity(
        subject: claims['sub'] as String,
        email: email.toLowerCase(),
        name: (fallbackName != null && fallbackName.trim().isNotEmpty)
            ? fallbackName.trim()
            : 'Pessoa',
      );
    } on ServiceError {
      rethrow;
    } catch (_) {
      throw const ServiceError(
        401,
        'Não foi possível validar o token da Apple. Entre novamente.',
      );
    }
  }
}
