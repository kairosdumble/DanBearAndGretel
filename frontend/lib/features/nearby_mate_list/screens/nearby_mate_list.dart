import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/data/colors.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';
import 'package:frontend/features/home/screens/place.dart';
import 'package:frontend/features/nearby_mate_detail/screens/nearby_mate_detail.dart';

class NearbyMateList extends StatefulWidget {
  const NearbyMateList({super.key, this.departure, this.destination});

  final Place? departure;
  final Place? destination;

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
      final uri = _reservationsUri(baseUrl);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final list = decoded is List ? decoded : <dynamic>[];
        setState(() {
          _reservations = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
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
  Uri _reservationsUri(String baseUrl) {
    final departure = widget.departure;
    final destination = widget.destination;
    final uri = Uri.parse('$baseUrl/api/reservations/all');
    if (departure == null) {
      return uri;
    }

    final queryParameters = {
      'lat': departure.latitude.toString(),
      'lng': departure.longitude.toString(),
    };

    if (destination != null) {
      queryParameters.addAll({
        'destinationLat': destination.latitude.toString(),
        'destinationLng': destination.longitude.toString(),
      });
    }
    return uri.replace(queryParameters: queryParameters);
  }

  static const List<String> _weekdayLabels = [
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  DateTime? _parseDepartureTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String? _departureDayBadge(DateTime? departure) {
    if (departure == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(departure.year, departure.month, departure.day);
    if (day == today) return '오늘';
    if (day == today.add(const Duration(days: 1))) return '내일';
    return null;
  }

  String _formatCardTime(DateTime? departure) {
    if (departure == null) return '--:--';
    return '${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}';
  }

  String _formatCardDate(DateTime? departure) {
    if (departure == null) return '날짜 미정';
    final weekday = _weekdayLabels[departure.weekday - 1];
    return '${departure.month.toString().padLeft(2, '0')}.${departure.day.toString().padLeft(2, '0')} ($weekday)';
  }

  int _participantCount(Map<String, dynamic> row) {
    final raw = row['participant_count'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  ({String label, Color color}) _statusStyle(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'RUNNING':
        return (label: '진행 중', color: AuthColors.bluePrimary);
      case 'COMPLETED':
        return (label: '완료', color: AuthColors.grayText);
      case 'READY':
      default:
        return (label: '모집 중', color: AuthColors.green);
    }
  }

  void _openCreateReservation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NearbyMateDetail()),
    );
  }

  Widget _buildCreateReservationButton() {
    return Positioned(
      right: 20,
      bottom: 16,
      child: Material(
        color: AuthColors.bluePrimary,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: _openCreateReservation,
          borderRadius: BorderRadius.circular(28),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: AuthColors.whiteText, size: 20),
                SizedBox(width: 6),
                Text(
                  '새 예약 만들기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.whiteText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadReservations,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 36,
                          height: 36,
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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 48,),
                    child: Text(
                      '총 ${_reservations.length.toString()}개의 모집글',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AuthColors.grayText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  final departure = _parseDepartureTime(row['departure_time']);
                  final chatTitle = dep.isEmpty && dest.isEmpty
                      ? 'Reservation #${reservationId ?? '-'}'
                      : '$dep -> $dest';

                  return _buildReservationCard(
                    departure: departure,
                    departureLabel: dep.isEmpty ? '출발지 미정' : dep,
                    destinationLabel: dest.isEmpty ? '도착지 미정' : dest,
                    status: row['status'],
                    participantCount: _participantCount(row),
                    onTap: reservationId == null
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
            _buildCreateReservationButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard({
    required DateTime? departure,
    required String departureLabel,
    required String destinationLabel,
    required dynamic status,
    required int participantCount,
    required VoidCallback? onTap,
  }) {
    final dayBadge = _departureDayBadge(departure);
    final statusStyle = _statusStyle(status);
    final displayParticipants = participantCount > 0 ? participantCount : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: AuthColors.bluePrimary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              if (dayBadge != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AuthColors.blueSecondary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dayBadge,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AuthColors.bluePrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                _formatCardTime(departure),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111111),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatCardDate(departure),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AuthColors.grayText,
                                ),
                              ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.only(left: 4, right: 10),
                          color: const Color(0xFFE8E8E8),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRouteRow(
                                icon: Icons.train_rounded,
                                iconColor: AuthColors.bluePrimary,
                                label: departureLabel,
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 7, top: 2, bottom: 2),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Color(0xFFB0B0B0),
                                ),
                              ),
                              _buildRouteRow(
                                icon: Icons.home_rounded,
                                iconColor: AuthColors.green,
                                label: destinationLabel,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              statusStyle.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: statusStyle.color,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: AuthColors.grayText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$displayParticipants명 참여',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AuthColors.grayText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Color(0xFFB8B8B8),
                        ),
                      ],
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

  Widget _buildRouteRow({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: iconColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}
