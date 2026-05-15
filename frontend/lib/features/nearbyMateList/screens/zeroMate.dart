// 매칭 가능 동승자가 없을 경우 뜨는 예약생성 화면
import 'package:flutter/material.dart';
import '../widgets/mate_card.dart';
import '../widgets/mate_empty_view.dart';

class ZeroMateScreen extends StatelessWidget {
  const ZeroMateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    
    final List<Map<String, String>> companions = []; 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "주변 동승자",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      
      body: companions.isEmpty 
          ? const MateEmptyView() 
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: companions.length,
              itemBuilder: (context, index) {
                final item = companions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: MateCard(
                    start: item["start"]!,
                    end: item["end"]!,
                    time: item["time"]!,
                    price: item["price"]!,
                  ),
                );
              },
            ),
    );
  }
}