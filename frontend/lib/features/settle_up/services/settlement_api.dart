import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import '../models/settlement_calculator.dart';

class SettlementApi {
  static Future<SettlementData> fetchSettlement(int reservationId) async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.get(
      Uri.parse('$baseUrl/api/reservations/$reservationId/settlement'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('정산 정보를 불러오지 못했습니다. (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('정산 정보 형식이 올바르지 않습니다.');
    }

    return SettlementData.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<Map<String, dynamic>> fetchSettlementStatus(
    int reservationId,
  ) async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.get(
      Uri.parse('$baseUrl/api/settle/$reservationId/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('정산 상태를 불러오지 못했습니다. (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('정산 상태 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<Map<String, dynamic>> fetchSettlementNotification() async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.get(
      Uri.parse('$baseUrl/api/settle/notification'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('정산 알림을 불러오지 못했습니다. (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('정산 알림 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> requestSettlement({
    required int reservationId,
    required num totalFare,
  }) async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.post(
      Uri.parse('$baseUrl/api/settle/$reservationId/request'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'total_fare': totalFare.round()}),
    );

    if (response.statusCode != 200) {
      final message = _messageFromBody(response.body) ?? '정산 요청에 실패했습니다.';
      throw Exception(message);
    }
  }

  static Future<Map<String, dynamic>> transferSettlement(
    int reservationId,
  ) async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.post(
      Uri.parse('$baseUrl/api/settle/$reservationId/transfer'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final message = _messageFromBody(response.body) ?? '송금에 실패했습니다.';
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('송금 결과 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return null;
  }
}
