import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/core/widgets/search_box_button.dart';
import 'package:frontend/data/colors.dart';

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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Place? _departure;
  Place? _destination;
  bool _showSettlementBanner = false;
  bool _settlementBannerIsFinalDropoff = false;
  int? _settlementBannerReservationId;
  String _settlementBannerDeparture = '';
  String _settlementBannerDestination = '';
  int _settlementBannerMyFare = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettlementBanner();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadSettlementBanner(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettlementBanner();
    }
  }

  Future<void> _openSearch(PlaceSearchType type) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => PlaceSearchPage(type: type)),
    );

    if (!mounted || place == null) return;

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
    if (departure == null || destination == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            NearbyMateList(departure: departure, destination: destination),
      ),
    );
    await _loadSettlementBanner();
  }

  void _clearSettlementBanner() {
    if (!mounted) return;
    setState(() {
      _showSettlementBanner = false;
      _settlementBannerIsFinalDropoff = false;
      _settlementBannerReservationId = null;
      _settlementBannerDeparture = '';
      _settlementBannerDestination = '';
      _settlementBannerMyFare = 0;
    });
  }

  Future<void> _loadSettlementBanner() async {
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        _clearSettlementBanner();
        return;
      }

      Map<String, dynamic>? activeMatch;
      try {
        activeMatch = await _fetchActiveMatchedReservation();
      } catch (_) {
        activeMatch = null;
      }

      var reservationId = activeMatch == null ? 0 : _asInt(activeMatch['id']);
      if (reservationId <= 0) {
        final notification = await SettlementApi.fetchSettlementNotification();
        if (notification['notification'] != true) {
          _clearSettlementBanner();
          return;
        }
        reservationId = _asInt(notification['reservation_id']);
        if (reservationId <= 0) {
          _clearSettlementBanner();
          return;
        }
      }

      final settlement = await SettlementApi.fetchSettlement(reservationId);
      final status = await SettlementApi.fetchSettlementStatus(reservationId);
      final totalFare = (status['total_fare'] as num?)?.toDouble() ?? 1;
      final result = calculateSettlement(
        passengers: settlement.passengers,
        totalFare: totalFare > 0 ? totalFare : 1,
        creatorId: settlement.reservation.creatorId,
      );
      final isFinalDropoff = result.finalSettler?.id == settlement.currentUserId;
      final hasIntermediateNotification = status['notification'] == true;

      if (!isFinalDropoff && !hasIntermediateNotification) {
        _clearSettlementBanner();
        return;
      }

      if (!mounted) return;
      setState(() {
        _showSettlementBanner = true;
        _settlementBannerIsFinalDropoff = isFinalDropoff;
        _settlementBannerReservationId = reservationId;
        _settlementBannerDeparture = settlement.reservation.departureLocation;
        _settlementBannerDestination = settlement.reservation.destinationLocation;
        _settlementBannerMyFare = _asInt(status['my_fare']);
      });
    } catch (_) {
      _clearSettlementBanner();
    }
  }

  Future<void> _onSettlementBannerTap() async {
    final reservationId = _settlementBannerReservationId;
    if (reservationId == null || reservationId <= 0) return;

    try {
      await _syncMyDestinationIfNeeded(reservationId);

      Map<String, dynamic> activeMatch;
      try {
        activeMatch = await _fetchActiveMatchedReservation();
      } catch (_) {
        activeMatch = {'id': reservationId};
      }

      final matchData = <String, dynamic>{
        'id': reservationId,
        'reservation_id': reservationId,
        'departure': _settlementBannerDeparture,
        'destination': _settlementBannerDestination,
        'fare': _asInt(activeMatch['fare']),
      };

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _settlementBannerIsFinalDropoff
              ? FinalDropoffScreen(matchData: matchData)
              : IntermediateDropoffScreen(matchData: matchData),
        ),
      );
      await _loadSettlementBanner();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildSettlementBanner() {
    final routeLabel = '$_settlementBannerDeparture → $_settlementBannerDestination';
    final subtitle = _settlementBannerIsFinalDropoff
        ? '해당 예약을 정산 합시다'
        : '최종하차자에게 바로 ${formatCurrency(_settlementBannerMyFare)}을 정산해주세요';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onSettlementBannerTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                color: Color(0xFF3056A0),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _syncMyDestinationIfNeeded(int reservationId) async {
    final destination = _destination;
    if (destination == null) {
      return;
    }

    final token = await AuthTokenStorage.getToken();
    if (token == null || token.isEmpty) return;

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.post(
      Uri.parse('$baseUrl/api/bluetooth/proximity/$reservationId/confirm'),
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

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD0D0D0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildBottomSheetContent(ScrollController scrollController) {
    final canFindMate = _departure != null && _destination != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
      children: [
        _buildDragHandle(),
        if (_showSettlementBanner) ...[
          _buildSettlementBanner(),
          const SizedBox(height: 20),
        ],
        const Text(
          '출발지 설정',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TMapView(
              departure: _departure,
              destination: _destination,
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.22,
            maxChildSize: 0.62,
            snap: true,
            snapSizes: const [0.22, 0.48, 0.62],
            builder: (context, scrollController) {
              return DecoratedBox(
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
                child: _buildBottomSheetContent(scrollController),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: Material(
                  color: AuthColors.darkGray,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(
                      Icons.person,
                      size: 24,
                      color: AuthColors.white,
                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
