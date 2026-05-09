// 테스트용 예시 화면임
import 'package:flutter/material.dart';

class nearbyMateList extends StatefulWidget {
  const nearbyMateList({super.key});

  @override
  State<nearbyMateList> createState() => _nearbyMateListState();
}
class _nearbyMateListState extends State<nearbyMateList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '주변 메이트',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 10, // 예시로 10개의 메이트를 표시
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text('메이트 ${index + 1}'),
                        subtitle: Text('출발지 - 목적지'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // 메이트 상세 페이지로 이동하는 로직 추가
                          },
                          child: const Text('상세보기'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}