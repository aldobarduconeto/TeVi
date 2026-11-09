import 'platform_support.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleIdentity;
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

import '../models/google_identity.dart';
import '../models/service_error.dart';
import 'core/security.dart';

/// Public OAuth clients for Android and iOS. Never put client secrets in a mobile app.
class GoogleOidcConfig {
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const appleClientId = String.fromEnvironment('GOOGLE_APPLE_CLIENT_ID');
  static final nonce = randomToken(32);
  static bool get supported => PlatformSupport.current.googleLogin;
  static bool get configured =>
      supported &&
      webClientId.endsWith('.apps.googleusercontent.com') &&
      (defaultTargetPlatform == TargetPlatform.android ||
          appleClientId.endsWith('.apps.googleusercontent.com'));
  static Set<String> get audiences => {
    if (webClientId.isNotEmpty) webClientId,
    if (appleClientId.isNotEmpty) appleClientId,
  };
}

class GoogleOidcService {
  static Future<void>? _initialization;
  Future<void> initialize() {
    if (!GoogleOidcConfig.configured) {
      throw const ServiceError(
        503,
        'Login Google ainda não configurado para esta plataforma.',
      );
    }
    return _initialization ??= GoogleSignIn.instance
        .initialize(
          clientId: defaultTargetPlatform == TargetPlatform.android
              ? null
              : GoogleOidcConfig.appleClientId,
          serverClientId: GoogleOidcConfig.webClientId,
          nonce: GoogleOidcConfig.nonce,
        )
        .catchError((Object error) {
          _initialization = null;
          throw error;
        });
  }

  Future<String?> authenticate() async {
    await initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const ServiceError(
          401,
          'Google não retornou um ID Token. Confira o Client ID.',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ServiceError(
        401,
        'Não foi possível entrar com Google. Tente novamente.',
      );
    }
  }

  Future<void> signOut() async {
    if (_initialization != null) {
      await _initialization;
      await GoogleSignIn.instance.signOut();
    }
  }
}

/// Only fixed Google JWKS are fetched; token-supplied URLs are never followed.
class GoogleTokenVerifier {
  GoogleTokenVerifier({
    http.Client? client,
    Set<String>? audiences,
    String? nonce,
    DateTime Function()? clock,
  }) : _client = client,
       _audiences = audiences ?? GoogleOidcConfig.audiences,
       _nonce = nonce ?? GoogleOidcConfig.nonce,
       _clock = clock ?? DateTime.now;
  final http.Client? _client;
  final Set<String> _audiences;
  final String _nonce;
  final DateTime Function() _clock;
  Map<String, dynamic> _keys = {};
  DateTime? _expires;
  Future<void> _loadKeys() async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('https://www.googleapis.com/oauth2/v3/certs'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const ServiceError(
          503,
          'Não foi possível validar o login Google.',
        );
      }
      final json = jsonDecode(response.body) as Map;
      _keys = {
        for (final key in json['keys'] as List)
          if (key['kty'] == 'RSA' && key['alg'] == 'RS256')
            key['kid'] as String: key,
      };
      final maxAge =
          int.tryParse(
            RegExp(r'max-age=(\d+)')
                    .firstMatch(response.headers['cache-control'] ?? '')
                    ?.group(1) ??
                '',
          ) ??
          600;
      _expires = _clock().add(Duration(seconds: maxAge.clamp(0, 3600)));
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<GoogleIdentity> verify(String token, {Duration? maxAge}) async {
    try {
      if (_audiences.isEmpty) {
        throw const ServiceError(503, 'Configure o Client ID do Google.');
      }
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
            RSAPublicKey(integer(key['n']), integer(key['e'])),
          ),
        );
      if (!verifier.verifySignature(
        Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
        RSASignature(base64Url.decode(base64Url.normalize(parts[2]))),
      )) {
        throw const FormatException();
      }
      final claims = decode(parts[1]);
      final now = _clock().millisecondsSinceEpoch / 1000;
      final aud = claims['aud'];
      final audience = aud is String
          ? [aud]
          : aud is List
          ? aud
          : [];
      if (![
            'https://accounts.google.com',
            'accounts.google.com',
          ].contains(claims['iss']) ||
          !audience.any(_audiences.contains) ||
          (audience.length > 1 && !_audiences.contains(claims['azp'])) ||
          (claims.containsKey('azp') && !_audiences.contains(claims['azp'])) ||
          claims['exp'] is! num ||
          !claims['exp'].isFinite ||
          claims['exp'] <= now ||
          claims['iat'] is! num ||
          !claims['iat'].isFinite ||
          claims['iat'] > now + 60 ||
          (maxAge != null && now - claims['iat'] > maxAge.inSeconds) ||
          claims['exp'] <= claims['iat'] ||
          (claims['nbf'] != null &&
              (claims['nbf'] is! num || claims['nbf'] > now + 60)) ||
          claims['nonce'] != _nonce ||
          claims['email_verified'] != true ||
          claims['sub'] is! String ||
          (claims['sub'] as String).isEmpty ||
          claims['email'] is! String ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(claims['email'])) {
        throw const FormatException();
      }
      return GoogleIdentity(
        subject: claims['sub'],
        email: claims['email'].toLowerCase(),
        name: claims['name'] is String ? claims['name'] : 'Pessoa',
      );
    } on ServiceError {
      rethrow;
    } catch (_) {
      throw const ServiceError(
        401,
        'Não foi possível validar o login Google. Entre novamente.',
      );
    }
  }
}
