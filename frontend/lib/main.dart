import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:frontend/features/auth/screens/auth_header.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';// env 파일을 읽기 위해 필요
import 'package:frontend/features/auth/screens/login.dart';
import 'package:frontend/features/auth/screens/signup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    developer.log(" .env 파일을 찾을 수 없습니다. 기본 설정을 사용합니다.");
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
        primaryColor: const Color(0xFF3F51B5),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthHeaderPage(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => SignupScreen(),
      },
    );
  }
}