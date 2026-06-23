import 'dart:convert';

/// JWT payload에서 사용자 ID를 추출합니다.
int? parseUserIdFromToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    var payload = parts[1];
    final padding = payload.length % 4;
    if (padding > 0) {
      payload += '=' * (4 - padding);
    }
    final decoded = json.decode(utf8.decode(base64Url.decode(payload)));
    if (decoded is! Map) return null;
    final raw = decoded['sub'] ?? decoded['userId'] ?? decoded['id'];
    return int.tryParse(raw?.toString() ?? '');
  } catch (_) {
    return null;
  }
}
