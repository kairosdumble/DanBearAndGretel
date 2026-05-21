import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:http/http.dart' as http;

class ProximityMatchApi {
  static Future<bool> confirm(int reservationId) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/reservations/proximity/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'reservation_id': reservationId}),
    );

    return response.statusCode == 200;
  }

  static Future<bool> cancel(int reservationId) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/reservations/proximity/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'reservation_id': reservationId}),
    );

    return response.statusCode == 200;
  }
}
