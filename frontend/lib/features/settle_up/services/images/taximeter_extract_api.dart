import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:http/http.dart' as http;

class TaximeterExtractResult {
  final int? fare;
  final String? errorMessage;

  const TaximeterExtractResult({this.fare, this.errorMessage});

  bool get isSuccess => fare != null;
}

class TaximeterExtractAPI {
  static String get _baseUrl =>
      (dotenv.env['BASE_URL'] ?? 'http://localhost:3000')
          .replaceFirst(RegExp(r'/$'), '');

  static Future<TaximeterExtractResult> recognizeFareFromImage(
    File imageFile,
  ) async {
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        return const TaximeterExtractResult(errorMessage: '로그인 토큰이 없습니다.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/image/taxi_meter/extract'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final result = jsonDecode(responseData) as Map<String, dynamic>;
        if (result['success'] == true) {
          final fare = result['fare'];
          if (fare is num && fare > 0) {
            return TaximeterExtractResult(fare: fare.toInt());
          }
          return const TaximeterExtractResult(
            errorMessage: '금액 인식 결과가 올바르지 않습니다.',
          );
        }
      }

      String message = '금액 인식 실패 (HTTP ${response.statusCode})';
      try {
        final body = jsonDecode(responseData) as Map<String, dynamic>;
        message = body['message']?.toString() ?? message;
        if (body['detail'] != null) {
          developer.log('미터기 금액 인식 detail: ${body['detail']}');
        }
      } catch (_) {}

      developer.log('미터기 금액 인식 실패: $message');
      return TaximeterExtractResult(errorMessage: message);
    } catch (e) {
      developer.log('미터기 금액 인식 에러: $e');
      return TaximeterExtractResult(errorMessage: '네트워크 오류: $e');
    }
  }
}
