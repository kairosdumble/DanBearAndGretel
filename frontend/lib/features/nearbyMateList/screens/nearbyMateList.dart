import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/features/chat/screens/mateChatScreen.dart';
import 'package:frontend/features/home/screens/place.dart';
import 'package:frontend/features/nearbyMateDetail/screens/NearbyMateDetail.dart';

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

  String _formatDepartureTime(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    final d =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final t =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  String? _formatDistance(dynamic value) {
    if (value == null) {
      return null;
    }

    final meters = num.tryParse(value.toString());
    if (meters == null) {
      return null;
    }

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)}km 떨어진 출발지';
    }
    return '${meters.round()}m 떨어진 출발지';
  }

  @override
  Widget build(BuildContext context) {
    final sortedByDistance = widget.departure != null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReservations,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
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
                  Expanded(
                    child: Text(
                      sortedByDistance ? '가까운 동승자' : '전체 예약',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NearbyMateDetail(
                            initialDeparture: widget.departure,
                            initialDestination: widget.destination,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C55A1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(92, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '예약 생성',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                sortedByDistance
                    ? '${widget.departure!.name} 기준 가까운 순서'
                    : 'DB 등록 예약 총 ${_reservations.length}건',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
                  final when = _formatDepartureTime(row['departure_time']);
                  final distance = _formatDistance(row['distance_meters']);
                  final chatTitle = dep.isEmpty && dest.isEmpty
                      ? 'Reservation #${reservationId ?? ''}'
                      : '$dep -> $dest';

                  final subtitleParts = [
                    ?distance,
                    if (when.isNotEmpty) '출발 $when' else '출발 시간 미정',
                  ];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        '$dep → $dest',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(subtitleParts.join(' · ')),
                      trailing: ElevatedButton(
                        onPressed: reservationId == null
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C55A1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(72, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '채팅',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
