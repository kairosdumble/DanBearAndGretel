import 'dart:developer' as developer;

class TaximeterExtractResult {
  final int? fare;
  final String? errorMessage;

  const TaximeterExtractResult({this.fare, this.errorMessage});

  bool get isSuccess => fare != null;
}
class TaximeterExtractAPI {
  static Future<TaximeterExtractResult> recognizeFareFromImage(String imageUrl) async {
    try {
      // Implementation for recognizing fare from image
      return const TaximeterExtractResult(fare: 15000);
    } catch (e) {
      developer.log('Error occurred while recognizing fare from image: $e');
      return const TaximeterExtractResult(errorMessage: 'Failed to recognize fare from image.');
    }
  }
}