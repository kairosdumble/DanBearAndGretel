import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/core/widgets/search_box_button.dart';

import '../../nearby_mate_list/screens/nearby_mate_list.dart';
import '../../route_search/screens/place_search.dart';
import '../../setting/screens/setting_screen.dart';
import '../../settle_up/models/settlement_calculator.dart';
import '../../settle_up/screens/final_dropoff.dart';
import '../../settle_up/screens/intermediate_dropoff.dart';
import '../../settle_up/services/settlement_api.dart';
import 'place.dart';
import 'tmap_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Place? _departure;
  Place? _destination;
  bool _openingMatchHistory = false;

  Future<void> _openSearch(PlaceSearchType type) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => PlaceSearchPage(type: type)),
    );

    if (!mounted || place == null) {
      return;
    }

    setState(() {
      if (type == PlaceSearchType.departure) {
        _departure = place;
      } else {
        _destination = place;
      }
    });
  }

  Future<void> _onFindMatePressed() async {
    final departure = _departure;
    final destination = _destination;
    if (departure == null || destination == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            NearbyMateList(departure: departure, destination: destination),
      ),
    );
  }

  Future<void> _openMatchingHistory() async {
    if (_openingMatchHistory) return;
    setState(() => _openingMatchHistory = true);

    try {
      final activeMatch = await _fetchActiveMatchedReservation();
      final reservationId = _asInt(activeMatch['id']);
      if (reservationId <= 0) {
        throw Exception('예약 ID가 없습니다.');
      }
      await _syncMyDestinationIfNeeded(reservationId, activeMatch);

      final settlement = await SettlementApi.fetchSettlement(reservationId);
      final result = calculateSettlement(
        passengers: settlement.passengers,
        totalFare: 1,
        creatorId: settlement.reservation.creatorId,
      );
      final isFinalDropoff =
          result.finalSettler?.id == settlement.currentUserId;

      final matchData = <String, dynamic>{
        'id': reservationId,
        'reservation_id': reservationId,
        'departure': settlement.reservation.departureLocation,
        'destination': settlement.reservation.destinationLocation,
        'fare': _asInt(activeMatch['fare']),
      };

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => isFinalDropoff
              ? FinalDropoffScreen(matchData: matchData)
              : IntermediateDropoffScreen(matchData: matchData),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingMatchHistory = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchActiveMatchedReservation() async {
    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.get(
      Uri.parse('$baseUrl/api/reservations/active-match'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 404) {
      throw Exception('진행 중인 예약이 없습니다.');
    }
    if (response.statusCode != 200) {
      throw Exception('매칭내역을 불러오지 못했습니다. (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('매칭내역 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _syncMyDestinationIfNeeded(
    int reservationId,
    Map<String, dynamic> activeMatch,
  ) async {
    final destination = _destination;
    if (destination == null || activeMatch['is_creator'] == true) {
      return;
    }

    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.post(
      Uri.parse('$baseUrl/api/reservations/proximity/$reservationId/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'destination_location': destination.name,
        'destination_lat': destination.latitude,
        'destination_lng': destination.longitude,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('입력한 목적지를 매칭 정보에 반영하지 못했습니다. (${response.statusCode})');
    }
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final canFindMate = _departure != null && _destination != null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: TMapView(
                  departure: _departure,
                  destination: _destination,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: 40,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '출발지 설정',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: _openingMatchHistory
                              ? null
                              : _openMatchingHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: Text(
                            _openingMatchHistory ? '조회 중' : '매칭내역',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SearchBoxButton(
                    label: _departure?.name ?? '출발지를 검색하세요',
                    subtitle: _departure?.roadAddress,
                    onTap: () => _openSearch(PlaceSearchType.departure),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    '목적지 설정',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SearchBoxButton(
                    label: _destination?.name ?? '목적지를 검색하세요',
                    subtitle: _destination?.roadAddress,
                    onTap: () => _openSearch(PlaceSearchType.destination),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: canFindMate ? _onFindMatePressed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3056A0),
                        disabledBackgroundColor: const Color(0xFFB9C6E2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        canFindMate ? '동승자 찾기' : '출발지와 목적지를 선택하세요',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.settings, size: 28, color: Colors.black54),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
