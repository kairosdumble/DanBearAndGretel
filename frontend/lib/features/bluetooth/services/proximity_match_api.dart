import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:http/http.dart' as http;

class ProximityNearbyUser {
  final int userId;
  final String name;
  final String nickname;

  const ProximityNearbyUser({
    required this.userId,
    required this.name,
    required this.nickname,
  });

  factory ProximityNearbyUser.fromJson(Map<String, dynamic> json) {
    return ProximityNearbyUser(
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
    );
  }

  String get displayLabel {
    if (nickname.trim().isNotEmpty) return nickname.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return '사용자 $userId';
  }
}

class ProximityApprovalStatus {
  final String mode;
  final bool canApprove;
  final String message;

  const ProximityApprovalStatus({
    required this.mode,
    required this.canApprove,
    required this.message,
  });

  factory ProximityApprovalStatus.fromJson(Map<String, dynamic> json) {
    return ProximityApprovalStatus(
      mode: json['mode']?.toString() ?? 'waiting_leader',
      canApprove: json['canApprove'] == true,
      message: json['message']?.toString() ?? '',
    );
  }
}

class ProximityConfirmResult {
  final bool success;
  final String message;

  const ProximityConfirmResult({
    required this.success,
    required this.message,
  });
}

class ProximityMatchApi {
  static Future<Map<String, String>?> _authHeaders() async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String get _baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  /// 방장: 선택한 동승자로 모임 확정 요청 (하이브리드 1차 요청)
  static Future<bool> confirmGroup({
    required int reservationId,
    required List<int> participantIds,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) return false;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/bluetooth/confirm'),
      headers: headers,
      body: json.encode({
        'reservation_id': reservationId,
        'participant_ids': participantIds,
      }),
    );

    return response.statusCode == 201;
  }

  /// 매칭 화면 진입 시 주기적으로 호출해 근접 상태를 서버에 알립니다.
  static Future<bool> sendPresence(int reservationId) async {
    final headers = await _authHeaders();
    if (headers == null) return false;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/bluetooth/proximity/$reservationId/presence'),
      headers: headers,
      body: json.encode({}),
    );
    return response.statusCode == 200;
  }

  /// 방장 화면: 근처 동승자 목록 조회
  static Future<({List<ProximityNearbyUser> users, String? error})>
      fetchNearbyUsers(int reservationId) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return (users: <ProximityNearbyUser>[], error: '로그인이 필요합니다.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/api/bluetooth/proximity/$reservationId/nearby'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      return (
        users: <ProximityNearbyUser>[],
        error: '주변 동승자 목록을 불러오지 못했습니다. (${response.statusCode})',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      return (users: <ProximityNearbyUser>[], error: '응답 형식이 올바르지 않습니다.');
    }

    final users = decoded
        .whereType<Map>()
        .map((row) => ProximityNearbyUser.fromJson(Map<String, dynamic>.from(row)))
        .where((user) => user.userId > 0)
        .toList();

    return (users: users, error: null);
  }

  /// 팀원: 현재 승인 가능 여부 조회
  static Future<ProximityApprovalStatus?> fetchApprovalStatus(
    int reservationId,
  ) async {
    final headers = await _authHeaders();
    if (headers == null) return null;

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/bluetooth/proximity/$reservationId/approval-status',
      ),
      headers: headers,
    );
    if (response.statusCode != 200) return null;

    final decoded = json.decode(response.body);
    if (decoded is! Map) return null;
    return ProximityApprovalStatus.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// 참여자: 승인(방장 요청이 있을 때만 가능)
  static Future<ProximityConfirmResult> confirm(
    int reservationId, {
    String? destinationLocation,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const ProximityConfirmResult(
        success: false,
        message: '로그인이 필요합니다.',
      );
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
      Uri.parse('$_baseUrl/api/bluetooth/proximity/$reservationId/confirm'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return const ProximityConfirmResult(
        success: true,
        message: '매칭 승인이 완료되었습니다.',
      );
    }

    String message = '매칭 승인에 실패했습니다.';
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    return ProximityConfirmResult(success: false, message: message);
  }

  static Future<bool> cancel(int reservationId) async {
    final headers = await _authHeaders();
    if (headers == null) return false;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/bluetooth/proximity/$reservationId/cancel'),
      headers: headers,
      body: json.encode({}),
    );
    return response.statusCode == 200;
  }


  static Future<bool> get(int reservationId) async {
    final headers = await _authHeaders();
    if (headers == null) return false;

    final response = await http.get(
      Uri.parse('$_baseUrl/api/bluetooth/proximity/$reservationId/get'),
      headers: headers,
    );
    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    return false;
  }
}
