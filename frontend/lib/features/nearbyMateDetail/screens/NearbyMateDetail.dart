import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 파일 로드용

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

import '../widgets/TimeField.dart';
import 'package:frontend/core/widgets/SearchBoxButton.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';

import 'package:frontend/features/home/screens/place.dart';
import 'package:frontend/features/routeSearch/screens/placeSearchPage.dart';
import 'package:frontend/features/nearbyMateList/screens/nearbyMateList.dart';

class NearbyMateDetail extends StatefulWidget {
  //[TODO] 출발지, 목적지 정보 받아올 수 있도록 생성자 수정하기.
  //일단은 테스트 용으로, 생성자 없이 고정된 화면으로 만들어둔 상태입니다.
  const NearbyMateDetail({super.key});

  @override
  State<NearbyMateDetail> createState() => _NearbyMateDetailState();
}

class _NearbyMateDetailState extends State<NearbyMateDetail> {
  // 시간 입력을 위한 컨트롤러
  final TextEditingController hourController = TextEditingController();
  final TextEditingController minuteController = TextEditingController();

  Place? _departure;
  Place? _destination;

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }
  // home.dart와 함께 재사용되는 중
  Future<Place?> _openSearch(PlaceSearchType type) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(type: type),
      ),
    );

    if (!mounted || place == null) {
      return place;
    }

    setState(() {
      if (type == PlaceSearchType.departure) {
        _departure = place;
      } else {
        _destination = place;
      }
    });
    return place;
  }
  // 예약 생성 API 호출
  Future<void> _insertReservation() async {
    final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    try {
      if (_departure?.name == _destination?.name) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발지와 목적지는 서로 달라야 합니다.')),
        );
        return;
      }
      if (_departure == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발지를 선택해주세요.')),
        );
        return;
      }
      if (_destination == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목적지를 선택해주세요.')),
        );
        return;
      }
      if (hourController.text.isEmpty || minuteController.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발시간을 입력해주세요.')),
        );
        return;
      }

      final hour = int.tryParse(hourController.text.trim());
      final minute = int.tryParse(minuteController.text.trim());
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발시간은 0~23시, 0~59분 형태로 입력해주세요.')),
        );
        return;
      }

      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 예약할 수 있습니다.')),
        );
        return;
      }

      final now = DateTime.now();
      final departure = DateTime(now.year, now.month, now.day, hour, minute);

      final response = await http.post(
        Uri.parse('$baseUrl/api/reservations/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'departure_location': _departure!.name,
          'destination_location': _destination!.name,
          'departure_time': departure.toIso8601String(),
        }),
      );

      if (response.statusCode == 201) {
        developer.log('서버 DB 저장 완료');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const NearbyMateList(),
          ),
        );
      } else {
        developer.log('서버 DB 저장 실패: ${response.statusCode} ${response.body}');
        if (!mounted) return;
        String msg = '예약 생성에 실패했습니다.';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['message'] is String) {
            msg = body['message'] as String;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e, st) {
      developer.log('예약 생성 오류', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 통신 오류: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 뒤로가기 + 제목
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F1F1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '예약',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                const Text(
                  '출발지',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                SearchBoxButton(
                    label: _departure?.name ?? '출발지를 검색하세요',
                    subtitle: _departure?.roadAddress,
                    onTap: () => _openSearch(PlaceSearchType.departure),
                ),
                const SizedBox(height: 40),

                /// 목적지
                const Text(
                  '목적지',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                SearchBoxButton(
                    label: _destination?.name ?? '도착지를 검색하세요',
                    subtitle: _destination?.roadAddress,
                    onTap: () => _openSearch(PlaceSearchType.destination),
                ),

                const SizedBox(height: 40),

                /// 출발시간
                const Text(
                  '출발시간',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    TimeField(controller:hourController),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TimeField(controller:minuteController),
                  ],
                ),

                const SizedBox(height: 50),

                /// 예약 생성 버튼
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                  onPressed: () async{ await _insertReservation();},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F5DB3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '예약 생성',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}