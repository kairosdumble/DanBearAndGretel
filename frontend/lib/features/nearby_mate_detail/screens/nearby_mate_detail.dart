import 'dart:convert';
import 'dart:developer' as developer;

import '../widgets/time_field.dart';
import 'package:frontend/core/widgets/search_box_button.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/features/home/screens/place.dart';
import 'package:frontend/features/route_search/screens/place_search.dart';
import 'package:frontend/features/nearby_mate_list/screens/nearby_mate_list.dart';


class NearbyMateDetail extends StatefulWidget {
  const NearbyMateDetail({
    super.key,
    this.initialDeparture,
    this.initialDestination,
  });

  final Place? initialDeparture;
  final Place? initialDestination;

  @override
  State<NearbyMateDetail> createState() => _NearbyMateDetailState();
}

class _NearbyMateDetailState extends State<NearbyMateDetail> {
  final TextEditingController hourController = TextEditingController();
  final TextEditingController minuteController = TextEditingController();

  Place? _departure;
  Place? _destination;
  late DateTime _departureDate;

  static const List<String> _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatDepartureDateLabel(DateTime date) {
    final weekday = _weekdayLabels[date.weekday - 1];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
  }

  Future<void> _pickDepartureDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      setState(() {
        _departureDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String _formatLocalDateTimeForApi(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:00';
  }

  @override
  void initState() {
    super.initState();
    _departure = widget.initialDeparture;
    _destination = widget.initialDestination;
    final now = DateTime.now();
    _departureDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }

  Future<Place?> _openSearch(PlaceSearchType type) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => PlaceSearchPage(type: type)),
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

  Future<void> _insertReservation() async {
    final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

    try {
      final departurePlace = _departure;
      final destinationPlace = _destination;

      if (departurePlace == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('출발지를 선택해주세요.')));
        return;
      }

      if (destinationPlace == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('목적지를 선택해주세요.')));
        return;
      }

      if (departurePlace.name == destinationPlace.name) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('출발지와 목적지는 서로 달라야 합니다.')));
        return;
      }

      if (hourController.text.isEmpty || minuteController.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('출발 시간을 입력해주세요.')));
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
          const SnackBar(content: Text('출발 시간은 0~23시, 0~59분으로 입력해주세요.')),
        );
        return;
      }

      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 후 예약할 수 있습니다.')));
        return;
      }

      final departureTime = DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        hour,
        minute,
      );

      if (departureTime.isBefore(DateTime.now())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발 일시는 현재 시간 이후여야 합니다.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/reservations/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'departure_location': departurePlace.name,
          'destination_location': destinationPlace.name,
          'departure_lat': departurePlace.latitude,
          'departure_lng': departurePlace.longitude,
          'destination_lat': destinationPlace.latitude,
          'destination_lng': destinationPlace.longitude,
          'departure_time': _formatLocalDateTimeForApi(departureTime),
        }),
      );

      if (response.statusCode == 201) {
        developer.log('예약 저장 완료');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NearbyMateList(
              departure: departurePlace,
              destination: destinationPlace,
            ),
          ),
        );
      } else {
        developer.log('예약 저장 실패: ${response.statusCode} ${response.body}');
        if (!mounted) return;
        String msg = '예약 생성에 실패했습니다.';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['message'] is String) {
            msg = body['message'] as String;
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      developer.log('예약 생성 오류', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('서버 통신 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '출발지',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                SearchBoxButton(
                  label: _departure?.name ?? '출발지를 검색하세요',
                  subtitle: _departure?.roadAddress,
                  onTap: () => _openSearch(PlaceSearchType.departure),
                ),
                const SizedBox(height: 20),
                const Text(
                  '목적지',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                SearchBoxButton(
                  label: _destination?.name ?? '목적지를 검색하세요',
                  subtitle: _destination?.roadAddress,
                  onTap: () => _openSearch(PlaceSearchType.destination),
                ),
                const SizedBox(height: 20),
                const Text(
                  '출발 날짜',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: _pickDepartureDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDepartureDateLabel(_departureDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '출발 시간',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TimeField(controller: hourController),
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
                    TimeField(controller: minuteController),
                  ],
                ),
                const SizedBox(height: 80),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _insertReservation,
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
                        fontSize: 18,
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
