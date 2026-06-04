import 'package:flutter/material.dart';

import 'package:frontend/core/widgets/search_box_button.dart';

import '../../nearby_mate_list/screens/nearby_mate_list.dart';
import '../../route_search/screens/place_search.dart';
import 'place.dart';
import 'tmap_view.dart';

import '../../settle_up/screens/final_dropoff.dart';
import '../../settle_up/screens/intermediate_dropoff.dart';
import '../../setting/screens/setting_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Place? _departure;
  Place? _destination;

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

  @override
  Widget build(BuildContext context) {
    final canFindMate = _departure != null && _destination != null; // 출발지, 목적지 입력 완료시 동승자 찾기 버튼 활성화
    final matchData = {
      'departure': _departure?.name ?? '출발지 정보 없음',
      'destination': _destination?.name ?? '목적지 정보 없음',
      'fare': 100000000, // [TODO] 실제 요금 계산 로직 필요
    };
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
                child: const TMapView(),
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => 
                                FinalDropoffScreen(key: null, matchData: matchData)),
                                //const IntermediateDropoffScreen(matchData: null,)),
                            );
                          }, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            '매칭내역',
                            style: TextStyle(
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
                    height: 55,
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
                MaterialPageRoute(builder: (context) => const SettingScreen()),
              );
            },
          ),
        ),
        ],
      ),
    );
  }
}
