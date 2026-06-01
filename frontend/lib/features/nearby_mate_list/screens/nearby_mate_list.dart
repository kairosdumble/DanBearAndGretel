import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';
import 'package:frontend/features/nearby_mate_detail/screens/nearby_mate_detail.dart';

class NearbyMateList extends StatefulWidget {
  const NearbyMateList({super.key});

  @override
  State<NearbyMateList> createState() => _NearbyMateListState();
}

class _NearbyMateListState extends State<NearbyMateList> {
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '로그인이 필요합니다.';
          _reservations = [];
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/reservations/all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final list = decoded is List ? decoded : <dynamic>[];
        setState(() {
          _reservations = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = '예약 목록을 불러오지 못했습니다. (${response.statusCode})';
          _reservations = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '네트워크 오류: $e';
        _reservations = [];
      });
    }
  }

  String _formatDepartureTime(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final period = parsed.hour < 12 ? '오전' : '오후';
    final hourOfPeriod = parsed.hour % 12;
    final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final minute = parsed.minute == 0
        ? ''
        : ' ${parsed.minute.toString().padLeft(2, '0')}분';
    return '$period $hour시$minute';
  }

  String _formatDepartureDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '';
    return '${parsed.year}년 ${parsed.month.toString().padLeft(2, '0')}월 ${parsed.day.toString().padLeft(2, '0')}일';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReservations,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 24,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '주변 동승자',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NearbyMateDetail(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C55A1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(122, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '새 예약 생성',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              else if (_reservations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('등록된 예약이 없습니다.')),
                )
              else
                ..._reservations.map((row) {
                  final reservationId = int.tryParse(
                    row['id']?.toString() ?? '',
                  );
                  final dep = row['departure_location']?.toString() ?? '';
                  final dest = row['destination_location']?.toString() ?? '';
                  final departureDate = _formatDepartureDate(
                    row['departure_time'],
                  );
                  final departureTime = _formatDepartureTime(
                    row['departure_time'],
                  );
                  final routeText = dep.isEmpty && dest.isEmpty
                      ? '예약 장소 미정'
                      : '$dep\n->$dest';
                  final chatTitle = dep.isEmpty && dest.isEmpty
                      ? 'Reservation #${reservationId ?? '-'}'
                      : '$dep \n-> $dest';

                  return _buildReservationCard(
                    routeText: routeText,
                    departureDate: departureDate,
                    departureTime: departureTime,
                    onChat: reservationId == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MateChatScreen(
                                  reservationId: reservationId,
                                  title: chatTitle,
                                ),
                              ),
                            );
                          },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationCard({
    required String routeText,
    required String departureDate,
    required String departureTime,
    required VoidCallback? onChat,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  routeText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  departureDate.isEmpty ? '출발날짜: 미정' : '출발날짜: $departureDate',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  departureTime.isEmpty ? '출발시간: 미정' : '출발시간:$departureTime',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 52,
            height: 42,
            child: ElevatedButton(
              onPressed: onChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C55A1),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '채팅',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
