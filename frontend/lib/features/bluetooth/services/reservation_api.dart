import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:http/http.dart' as http;

class ReservationApi {
  static String get _baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  /// 방장: 매칭 중(READY/MATCHED) 예약 삭제
  static Future<({bool success, String message})> deleteReservation(
    int reservationId,
  ) async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return (success: false, message: '로그인이 필요합니다.');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/reservations/$reservationId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return (success: true, message: '예약이 삭제되었습니다.');
    }

    String message = '예약 삭제에 실패했습니다.';
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    return (success: false, message: message);
  }
}
