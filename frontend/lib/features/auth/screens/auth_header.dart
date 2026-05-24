// 로그인과 회원가입을 이동할 수 있는 부모 파일
//탭 바(Tab Bar)를 가지고 있으며, 선택된 탭에 따라 아래 내용을 갈아끼워 주는 역할만

// frontend/lib/features/auth/screens/auth_header.dart
import 'package:flutter/material.dart';
import 'login.dart';
import 'signup.dart';

class AuthHeaderPage extends StatelessWidget {
  const AuthHeaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    
    return DefaultTabController(
      length: 2, // 로그인, 회원가입 2개
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 80,
          title: const Align(
            alignment: Alignment.bottomLeft,
            child: TabBar(
              isScrollable: true,
              labelColor: Color(0xFF3F51B5), // 선택 시 파란색
              unselectedLabelColor: Colors.grey, // 비활성 시 회색
              indicatorColor: Color(0xFF3F51B5), // 밑줄 색상
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "로그인"),
                Tab(text: "회원가입"),
              ],
            ),
          ),
        ),
        
        body: TabBarView(
          children: [
            LoginScreen(),
            SignupScreen(),
          ],
        ),
      ),
    );
  }
}