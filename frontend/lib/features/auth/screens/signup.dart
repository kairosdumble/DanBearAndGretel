//회원가입 구현 파일

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 서버 통신을 위해 필요
import 'dart:convert';
import 'package:frontend/features/auth/screens/auth_email.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 파일 로드용

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 1. 입력값을 제어할 컨트롤러
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 최종 회원가입 함수 (signup 호출)
  
  Future<void> _submitSignup() async {
    final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
  
    // 입력값 유효성 검사 (서버에 쏘기 전 프론트에서 컷!)
    if (_studentIdController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 정보를 입력해주세요.")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "student_id": _studentIdController.text,
          "name": _nameController.text,
          "email": _emailController.text,
          "password": _passwordController.text,
        }),
      );

      // 응답 본문이 비어있지 않은지 확인 후 디코딩
      dynamic result;
      if (response.headers['content-type']?.contains('application/json') ?? false) {
        result = json.decode(response.body);
      }

      if (!mounted) return;

      // 성공(201) 시에만 명확하게 pop 실행
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['message'] ?? "회원가입이 완료되었습니다.")),
        );
        
        // 성공 시에만 0.5초 뒤 화면 닫기
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
        
      } else {
        // 실패(400, 401, 500 등) 시에는 절대 pop을 하지 않습니다.
        String errorMessage = result?['message'] ?? "회원가입에 실패했습니다.";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent, // 실패는 빨간색으로 강조
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print("네트워크 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 통신 오류: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 학번 입력칸
            Text("학번", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _studentIdController),
            SizedBox(height: 20),

            // 성명 입력칸
            Text("성명", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _nameController),
            SizedBox(height: 20),

            // 이메일 입력칸 + 인증하기 버튼
            Text("이메일", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _emailController),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_emailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("이메일을 입력해주세요.")),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuthEmailScreen(email: _emailController.text),
                      ),
                    );
                  },
                  child: Text("인증하기"),
                ),
              ],
            ),
            SizedBox(height: 20),

            // 비밀번호 입력칸
            Text("비밀번호", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              obscureText: false, // 비밀번호 가리기
            ),
            
            SizedBox(height: 100),

            // 완료 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async{
                  await _submitSignup();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("완료", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}