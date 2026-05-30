import 'package:flutter/material.dart';
import '../../nearbyMateDetail/screens/nearbyMateDetail.dart';

class MateEmptyView extends StatelessWidget {
  const MateEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "현재 매칭 가능 동승자가 없습니다.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          
          const SizedBox(height: 60),

          // 예약 생성 버튼
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NearbyMateDetail()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("예약 생성", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),

          // 취소하기 버튼
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.grey.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("취소하기", style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}