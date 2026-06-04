import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  int _fare = 0; // 정산 금액
  bool _isLoading = true; // 금액 정보 로딩 여부
  bool _isSettled = false; // 정산 완료 여부

  final storage = const FlutterSecureStorage(); // 토큰 저장소
  
  @override
  void initState() {
    super.initState();
    _getFareInfo();
  }
  
  @override
  Widget build(BuildContext context) {
    final String departure = widget.matchData?['departure'] ?? '출발지 정보 없음';
    final String destination = widget.matchData?['destination'] ?? '목적지 정보 없음';
    //final int fare = widget.matchData?['fare'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : Padding(
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
            _buildInfoCard(departure, destination, _fare),
            
            const SizedBox(height: 25),
            
            // 정산하기 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSettled ? null : () => _processPayment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSettled ? Colors.grey : const Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isSettled ? "정산 완료" : "정산하기",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
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

  Future<void> _getFareInfo() async {
    final String apiUrl = "http://10.0.2.2:3000/api/settles/${widget.matchData?['id']}/fare_info";

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer <실제토큰>', // 로그인 시 저장한 토큰
        },
      );

      if (response.statusCode == 200) {
        // 서버 응답이 성공이면 JSON을 해석해서 금액을 넣어줌
        final data = jsonDecode(response.body);
        setState(() {
          _fare = data['fare']; // 서버가 주는 필드명(fare)에 맞춰 수정
          _isLoading = false;
        });
      } else {
        print("금액 가져오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("통신 에러: $e");
    }
  }

  // 1. 저장된 토큰을 가져오는 함수 (저장소 환경에 맞게 수정하세요)
Future<String?> _getToken() async {
  // 예: FlutterSecureStorage 사용 시
  return await storage.read(key: 'jwt_token'); 
}

// 2. API 호출 부분
Future<void> _processPayment() async {
  String? token = await _getToken(); // 토큰을 가져옵니다.

  if (token == null) {
    // 토큰이 없으면 결제 불가
    return;
  }

  final response = await http.post(
    Uri.parse("http://10.0.2.2:3000/api/settles/${widget.matchData?['id']}/total_upload"),
    headers: {
      'Content-Type': 'application/json',
      // 여기서 서버가 원하는 'Authorization' 규격을 맞춥니다!
      'Authorization': 'Bearer $token', 
    },
    body: jsonEncode({'fare': _fare}),
  );
  
  // ... 이후 응답 처리
}
}