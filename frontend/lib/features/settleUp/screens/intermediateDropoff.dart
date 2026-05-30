import 'package:flutter/material.dart';
import 'package:frontend/features/chat/screens/mateChatScreen.dart';

class IntermediateDropoffScreen extends StatefulWidget {
  final Map<String, dynamic>? matchData;

  const IntermediateDropoffScreen({
    Key? key,
    this.matchData,
  }) : super(key: key);

  @override
  State<IntermediateDropoffScreen> createState() => _IntermediateDropoffScreenState();
}

class _IntermediateDropoffScreenState extends State<IntermediateDropoffScreen> {
  @override
  Widget build(BuildContext context) {
    final String departure = widget.matchData?['departure'] ?? '출발지 정보 없음';
    final String destination = widget.matchData?['destination'] ?? '목적지 정보 없음';
    final int fare = widget.matchData?['fare'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Center(
              child: Icon(Icons.check_circle, color: Color(0xFF3F51B5), size: 80),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text("동승자 매칭이 완료되었습니다!", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  // 채팅방 이동 로직
                  final int resId = widget.matchData?['id'] ?? 0; 
  
                  if (resId != 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                      builder: (context) => MateChatScreen(
                      reservationId: resId, 
                      title: "동승자 채팅방",
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("채팅방 정보를 찾을 수 없습니다.")),
                );
              }
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text("해당 채팅방으로 이동하기"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black54,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 25),
            // 정보 표시 박스
            _buildInfoCard(departure, destination, fare),
            
            const SizedBox(height: 25),
            
            // 정산하기 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 정산 로직 및 팝업 호출
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("정산하기", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String dep, String dest, int fare) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(title: Text("출발지"), trailing: Text(dep)),
          ListTile(title: Text("하차지"), trailing: Text(dest)),
          const Divider(),
          ListTile(title: Text("정산 금액", style: TextStyle(fontWeight: FontWeight.bold)), 
                   trailing: Text("${fare}원", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)))),
        ],
      ),
    );
  }
}