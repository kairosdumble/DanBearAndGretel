//로그인 구현 파일
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 로그인 통신 함수
  Future<void> _handleLogin() async {
    final url = Uri.parse('http://localhost:3000/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인에 성공했습니다!")),
        );
        // 성공 시 다음 화면(메인 등)으로 이동하는 코드
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "로그인 실패")),
        );
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // 상단 탭 (로그인/회원가입 선택 바)
            Row(
              children: [
                Column(
                  children: [
                    const Text("로그인", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),
                    Container(height: 2, width: 60, color: const Color(0xFF3F51B5)),
                  ],
                ),
                const SizedBox(width: 30),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/signup'), // 회원가입으로 이동
                  child: const Text("회원가입", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 50),

            const Text("이메일", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: "1234@dankook.ac.kr"),
            ),
            const SizedBox(height: 30),

            const Text("비밀번호", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "••••••••••••",
                suffixIcon: Icon(Icons.visibility_off_outlined),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {}, 
                child: const Text("비밀번호를 잊으셨나요?", style: TextStyle(fontSize: 12, color: Color(0xFF3F51B5))),
              ),
            ),
            const SizedBox(height: 40),

            // Continue 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Continue", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}