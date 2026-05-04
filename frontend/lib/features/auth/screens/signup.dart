//회원가입 구현 파일
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 서버 통신을 위해 필요
import 'dart:convert';
import 'auth_header.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 1. 입력값을 제어할 컨트롤러 (디자인의 각 입력창에 대응)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 2. 이메일 인증번호 발송 함수 (팀원의 send-code 호출)
  Future<void> _sendVerificationCode() async {
    final url = Uri.parse('http://localhost:3000/api/auth/email/send-code');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": _emailController.text}),
      );
      if (response.statusCode == 200) {
        // 성공 시 인증번호 입력 화면으로 이동하거나 메시지 표시
        print("인증번호 발송 성공");
      }
    } catch (e) {
      print("에러 발생: $e");
    }
  }

  // 3. 최종 회원가입 함수 (signup 호출)
  Future<void> _submitSignup() async {
    final url = Uri.parse('http://localhost:3000/api/auth/signup');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "name": _nameController.text,
          "email": _emailController.text,
          "password": _passwordController.text, // 백엔드의 password_hash로 저장됨
        }),
      );
      if (response.statusCode == 201) {
        print("회원가입 완료!");
      }
    } catch (e) {
      print("에러 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("회원가입", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 성명 입력칸
            Text("성명", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _nameController, decoration: InputDecoration(hintText: "성명을 입력하세요")),
            SizedBox(height: 20),

            // 이메일 입력칸 + 인증하기 버튼
            Text("이메일", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _emailController, decoration: InputDecoration(hintText: "1234@dankook.ac.kr")),
                ),
                ElevatedButton(
                  onPressed: _sendVerificationCode, // [인증하기] 버튼
                  child: Text("인증하기"),
                ),
              ],
            ),
            SizedBox(height: 20),

            // 비밀번호 입력칸
            Text("비밀번호", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              obscureText: true, // 비밀번호 가리기
              decoration: InputDecoration(hintText: "••••••••••••", suffixIcon: Icon(Icons.visibility_off)),
            ),
            
            SizedBox(height: 100),

            // 완료 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitSignup, // [완료] 버튼
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3F51B5)), // 디자인의 남색 버튼
                child: Text("완료", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}