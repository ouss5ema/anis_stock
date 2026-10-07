import 'dart:convert';

/// Reads the `exp` claim of a JWT without verifying its signature.
/// Returns null when the token has no `exp` claim.
/// Throws [FormatException] when the token is not a decodable JWT.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Malformed JWT');
  }
  final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Malformed JWT payload');
  }
  final exp = payload['exp'];
  if (exp is! num) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
}

/// True when the token is expired or cannot be decoded.
bool isJwtExpired(String token, {DateTime? now}) {
  try {
    final expiry = jwtExpiry(token);
    if (expiry == null) {
      return false;
    }
    return !expiry.isAfter((now ?? DateTime.now()).toUtc());
  } on FormatException {
    return true;
  }
}
