import 'package:flutter/material.dart';
//import 'tmap_view.dart';

void main() {
  runApp(const DangretelApp());
}

class DangretelApp extends StatelessWidget {
  const DangretelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단곰이와 그레텔',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3056A0)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
body: Stack(

        children: [

          // 지도 영역

          Positioned(

            top: 60, // 상태바 아래 적절한 여백

            left: 20,

            right: 20,

            child: Container(

              height: 350, // 네모 상자의 높이 설정

              decoration: BoxDecoration(

                color: const Color(0xFFF2F2F2), // 지도 배경색

                borderRadius: BorderRadius.circular(15), // 모서리를 살짝 둥글게

                border: Border.all(color: const Color(0xFFE0E0E0)), // 테두리 추가

              ),

              child: ClipRRect(

                borderRadius: BorderRadius.circular(15),

                child: Column(

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: const [

                    Icon(Icons.map_outlined, size: 40, color: Colors.grey),

                    SizedBox(height: 10),

                    Text(

                      '이 네모 상자에 지도가 표시됩니다',

                      style: TextStyle(color: Colors.grey),

                    ),

                  ],

                ),

              ),

            ),

          ),

          // 하단 UI 패널
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 40),
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
                mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 높이 차지
                children: [
                  // 출발지 설정, 이전내역 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '출발지 설정',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            // 이전 내역 페이지나 모달 띄우기
                            print('이전 내역 버튼 클릭');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0), // 회색 배경
                            foregroundColor: Colors.black, // 글자색
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text('이전내역', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 출발지 검색 박스 (버튼)
                  _buildSearchBoxButton(
                    context: context,
                    onTap: () {
                      // 출발지 검색 페이지로 이동
                      print('출발지 검색 페이지로 이동');
                    },
                  ),
                  const SizedBox(height: 30),

                  // 목적지 설정
                  const Text(
                    '목적지 설정',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // 목적지 검색 박스 (버튼)
                  _buildSearchBoxButton(
                    context: context,
                    onTap: () {
                      // 목적지 검색 페이지로 이동
                      print('목적지 검색 페이지로 이동');
                    },
                  ),
                  const SizedBox(height: 30),

                  // 동승자 찾기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        // 동승자 찾는 다음 페이지로 이동
                        print('동승자 찾기 페이지로 이동');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3056A0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '동승자 찾기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 검색 박스 모양의 버튼을 만드는 공통 위젯 함수
  Widget _buildSearchBoxButton({required BuildContext context, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, // 클릭 시 실행될 함수 연결
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD4D4D4), width: 1.5), // 테두리 색상
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end, // 아이콘을 오른쪽 끝으로 배치
          children: [
            Icon(Icons.search, color: Color(0xFF3056A0)), // 파란색 돋보기 아이콘
          ],
        ),
      ),
    );
  }
}