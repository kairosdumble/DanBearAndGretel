import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';
import 'package:frontend/features/nearbyMateDetail/screens/NearbyMateDetail.dart';

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
    final d =
        '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    final t =
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    '전체 예약',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 48),
                  ElevatedButton(
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
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '새 예약 생성',
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
                'DB 등록 예약 총 ${_reservations.length}건',
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
                  final bookerId = row['user_id']?.toString() ?? '-';
                  final chatTitle = dep.isEmpty && dest.isEmpty
                      ? 'Reservation #${reservationId ?? bookerId}'
                      : '$dep -> $dest';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        '$dep → $dest',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        when.isEmpty
                            ? '예약자 #$bookerId · 출발 시간 미정'
                            : '예약자 #$bookerId · 출발 $when',
                      ),
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
