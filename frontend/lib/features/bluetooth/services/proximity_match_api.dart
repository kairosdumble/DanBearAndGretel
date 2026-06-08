import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:http/http.dart' as http;

class ProximityMatchApi {
  static Future<bool> confirm(
    int reservationId, {
    String? destinationLocation,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    final body = <String, dynamic>{};
    if (destinationLocation != null && destinationLocation.trim().isNotEmpty) {
      body['destination_location'] = destinationLocation.trim();
    }
    if (destinationLat != null) {
      body['destination_lat'] = destinationLat;
    }
    if (destinationLng != null) {
      body['destination_lng'] = destinationLng;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/reservations/proximity/$reservationId/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
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
      Uri.parse('$baseUrl/api/reservations/proximity/$reservationId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({}),
    );
    return response.statusCode == 200;
  }

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
