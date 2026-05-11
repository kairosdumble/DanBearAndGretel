/*
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:frontend/features/auth/screens/auth_header.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const DangretelApp());
}

class DangretelApp extends StatelessWidget {
  const DangretelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단곰이와 그레텔',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3F51B5),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const CompanionListScreen(),
      routes: {
        '/companion_list': (context) => const CompanionListScreen(),
      },
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // env 파일을 읽기 위해 필요
import 'package:frontend/features/auth/screens/login.dart';
import 'package:frontend/features/auth/screens/signup.dart';
// HomePage 위젯이 정의된 파일을 임포트하세요. 
// 보통 auth_header.dart 안에 HomePage가 있다면 그 파일을 임포트하면 됩니다.
import 'package:frontend/features/auth/screens/auth_header.dart'; 

void main() async {
  // 백엔드와 통신하기 위한 필수 설정
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ .env 파일을 찾을 수 없습니다. 기본 설정을 사용합니다.");
  }
  runApp(const DangretelApp());
}

class DangretelApp extends StatelessWidget {
  const DangretelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단곰이와 그레텔',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      
      home: const AuthHeaderPage(), 
      
      // 화면 이동을 위한 경로 설정
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => SignupScreen(),
      },
    );
  }
}