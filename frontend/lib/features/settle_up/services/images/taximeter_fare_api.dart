import "package:http/http.dart" as http;
import "dart:convert";  
import 'package:flutter_dotenv/flutter_dotenv.dart';
import "dart:developer" as developer;
import "package:frontend/core/auth/auth_token_storage.dart";

class TaximeterFareResult{
  final int fare;
  const TaximeterFareResult({required this.fare});
}

class TaximeterFareAPI {
  // 서버로 금액 전송
  Future<void> _sendFareToServer(int fare,int reservationId) async {
    final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        developer.log('인증 토큰이 없습니다.');
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/reservations/$reservationId/fare'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fare': fare}),
      );

      if (response.statusCode == 200) {
        developer.log('금액이 서버에 저장되었습니다.');
      } else {
        developer.log('금액 저장 실패 (HTTP ${response.statusCode})');
        developer.log('응답 본문: ${response.body}');
      }
    } catch (e) {
      developer.log('네트워크 오류: $e');
    }
  }
}