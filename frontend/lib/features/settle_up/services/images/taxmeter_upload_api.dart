import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageUploadService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'https://...onrender.com';

  /// 미터기 사진을 Node.js 백엔드로 전송하는 API 호출 함수
  Future<String?> uploadMeterImage(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      
      // 추가로 미터기 관련 데이터가 필요하다면 여기에 request.fields[...] 추가 가능

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var result = jsonDecode(responseData);
        return result['imageUrl']; // 백엔드가 준 Supabase 이미지 URL 반환
      }
      return null;
    } catch (e) {
      print('미터기 이미지 업로드 에러: $e');
      return null;
    }
  }
}