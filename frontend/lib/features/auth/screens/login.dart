//로그인 구현 파일
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/features/home/screens/home.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['BASE_URL']}/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200) {
        final token = result['token'];
        if (token is String && token.isNotEmpty) {
          await AuthTokenStorage.saveToken(token);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인에 성공했습니다!")),
        );
        Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "로그인 실패")),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("[로그인] 서버 통신 중 오류가 발생했습니다. error: $e")),
      );
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
            const Text("이메일", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _emailController,
            ),
            const SizedBox(height: 30),

            const Text("비밀번호", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              obscureText: true,
            ),

            SizedBox(height: 100),

            // Continue 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  _handleLogin();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("로그인", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),            
          ],
        ),
      ),
    );
  }
}