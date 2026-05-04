/*
import 'package:flutter/material.dart';

void main() {
  runApp(const DangretelApp());
}

/// 택시 공유 탑승 서비스 루트 위젯
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단곰이와 그레텔'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '성공적으로 실행되었습니다. HI~~',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:frontend/features/auth/screens/auth_header.dart';

void main() {
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
      // 앱 시작 화면
      home: const HomePage(),
      // 탭바 이동을 위한 경로(Route) 설정
      routes: {
        '/login': (context) => AuthHeaderPage(),
        '/signup': (context) => AuthHeaderPage(),
      },
    );
  }
}

/// 3초 동안 보여줄 스플래시(인사) 화면
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 3초 후 로그인 화면으로 자동 이동
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_taxi, size: 80, color: Colors.indigo),
            SizedBox(height: 20),
            Text(
              '단곰이와 그레텔',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            SizedBox(height: 10),
            Text(
              '성공적으로 실행되었습니다. HI~~',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}