import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'dart:developer' as developer;

class TaximeterUploadResult {
  final String? imageUrl;
  final String? errorMessage;

  const TaximeterUploadResult({this.imageUrl, this.errorMessage});

  bool get isSuccess => imageUrl != null && imageUrl!.isNotEmpty;
}

/// 미터기 사진 업로드·조회 API
class TaximeterUploadAPI {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  Future<TaximeterUploadResult> uploadTaximeterImage(File imageFile, {required int reservationId,}
  ) async {
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        return const TaximeterUploadResult(errorMessage: '로그인 토큰이 없습니다.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/image/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['reservation_id'] = reservationId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final result = jsonDecode(responseData) as Map<String, dynamic>;
        return TaximeterUploadResult(
          imageUrl: result['imageUrl'] as String?,
        );
      }

      String message = '업로드 실패 (HTTP ${response.statusCode})';
      try {
        final body = jsonDecode(responseData) as Map<String, dynamic>;
        message = body['message']?.toString() ?? message;
        if (body['detail'] != null) {
          developer.log('미터기 업로드 detail: ${body['detail']}');
        }
      } catch (_) {}

      developer.log('미터기 이미지 업로드 실패: $message');
      return TaximeterUploadResult(errorMessage: message);
    } catch (e) {
      developer.log('미터기 이미지 업로드 에러: $e');
      return TaximeterUploadResult(errorMessage: '네트워크 오류: $e');
    }
  }

  /// PostgreSQL에 저장된 미터기 이미지 URL을 조회합니다.
  Future<String?> getTaximeterImageUrl() async {
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        developer.log('미터기 이미지 조회 실패: 토큰이 없습니다.');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/user/taxi_meter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['taxi_meter_image_url'];
        if (url == null || (url is String && url.isEmpty)) {
          developer.log('미터기 이미지 조회 실패: 이미지 URL이 없습니다.');
          return null;
        }
        return url as String;
      } else {
        developer.log('미터기 이미지 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      developer.log('미터기 이미지 조회 에러: $e');
      return null;
    }
  }
}
