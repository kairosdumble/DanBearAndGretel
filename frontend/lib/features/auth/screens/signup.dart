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
  // 1. 입력값을 제어할 컨트롤러
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 2. 이메일 인증번호 발송 함수 (send-code 호출)
  Future<void> _sendVerificationCode() async {
    final url = Uri.parse('http://localhost:3000/auth/email/send-code');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": _emailController.text}),
      );
      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "인증번호 발송 성공")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "인증번호 발송에 실패했습니다.")),
        );
      }
    } catch (e) {
      print("에러 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 통신 중 오류가 발생했습니다.")),
      );
    }
  }

  // 3. 최종 회원가입 함수 (signup 호출)
  Future<void> _submitSignup() async {
    final url = Uri.parse('http://localhost:3000/auth/signup');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "student_id": _studentIdController.text,
          "name": _nameController.text,
          "email": _emailController.text,
          "password": _passwordController.text, // 백엔드의 password_hash로 저장됨
        }),
      );
      final result = json.decode(response.body);
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "회원가입이 완료되었습니다.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "회원가입에 실패했습니다.")),
        );
      }
    } catch (e) {
      print("에러 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 통신 중 오류가 발생했습니다.")),
      );
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
              decoration: InputDecoration(suffixIcon: Icon(Icons.visibility_off)),
            ),
            
            SizedBox(height: 100),

            // 완료 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitSignup, // [완료] 버튼
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3F51B5)),
                child: Text("완료", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}