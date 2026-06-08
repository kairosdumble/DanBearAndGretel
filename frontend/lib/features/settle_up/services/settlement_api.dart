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
}
