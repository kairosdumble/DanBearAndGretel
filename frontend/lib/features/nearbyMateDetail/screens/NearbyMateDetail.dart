import 'package:flutter/material.dart';
import '../widgets/TimeField.dart';
import 'package:frontend/core/widgets/SearchBoxButton.dart';
import 'package:frontend/features/home/screens/place.dart';
import 'package:frontend/features/routeSearch/screens/placeSearchPage.dart';
import 'package:frontend/features/nearbyMateList/screens/nearbyMateList.dart';
//[TODO] onPressed에서 예약 생성 로직 추가하기 (벡엔드, DB는 존재.)

class Nearbymatedetail extends StatefulWidget {
  const Nearbymatedetail({super.key});

  @override
  State<Nearbymatedetail> createState() => _NearbymatedetailState();
}

class _NearbymatedetailState extends State<Nearbymatedetail> {
  // 출발지와 목적지 입력을 위한 컨트롤러
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController =TextEditingController();

  // 시간 입력을 위한 컨트롤러
  final TextEditingController hourController = TextEditingController();
  final TextEditingController minuteController = TextEditingController();
  Place? _departure;
  Place? _destination;
  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }
  // home.dart와 함께 재사용되는 중
  Future<void> _openSearch(PlaceSearchType type) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(type: type),
      ),
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
                    onPressed: () {
                       Navigator.pushReplacement(
                         context,
                         MaterialPageRoute(
                           builder: (context) =>
                              const nearbyMateList(), 
                        ),
                      );
                    },
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