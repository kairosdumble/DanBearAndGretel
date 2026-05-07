// frontend/lib/features/ride/widgets/companion_card.dart
import 'package:flutter/material.dart';

class CompanionCard extends StatelessWidget {
  final String start;
  final String end;
  final String time;
  final String price;

  const CompanionCard({
    super.key,
    required this.start,
    required this.end,
    required this.time,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("출발지", start),
          _buildInfoRow("도착지", end),
          _buildInfoRow("출발시간", time),
          _buildInfoRow("예상 금액", price),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                // 채팅하기 로직
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("채팅하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 반복되는 텍스트 줄을 위한 작은 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        "$label: $value",
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
}