import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:http/http.dart' as http;

class ProximityMatchApi {
  //추가
  static Future<bool> confirm(int reservationId) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final token = await AuthTokenStorage.getToken(); // userId가 들어 있음
    if (token == null || token.isEmpty) {
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/reservations/proximity/$reservationId/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // middleware에서 사용자 아이디가 암호화 되어 전달됨.
      },
      body: json.encode({}),
    );

    return response.statusCode == 200;
  }
  //삭제
  static Future<bool> cancel(int reservationId) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/api/reservations/proximity/$reservationId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // 사용자 아이디가 암호화되어 전달됨.
      },
      body: json.encode({}),
    );
    return response.statusCode == 200;
  }
  //검색
  static Future<bool> get(int reservationId) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    final response = await http.get(
      Uri.parse('$baseUrl/api/reservations/proximity/$reservationId/get'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    return false;
  }
}
