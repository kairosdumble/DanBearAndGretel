/*
import 'package:flutter/material.dart';
import 'package:frontend/features/nearbyMateList/screens/mate_list_screen.dart';

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
import 'package:frontend/features/nearbyMateList/screens/mate_list_screen.dart'; 

void main() {
  runApp(const DangretelApp());
}

class DangretelApp extends StatelessWidget {
  const DangretelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단곰이와 그레텔',
      debugShowCheckedModeBanner: false, // 오른쪽 상단 디버그 띠 제거
      theme: ThemeData(
        primaryColor: const Color(0xFF3F51B5),
        scaffoldBackgroundColor: Colors.white,
      ),
      // 앱이 시작되자마자 방금 만든 화면이 뜨도록 설정!
      home: const MateListScreen(), 
      
      // 나중에 다른 화면들과 연결할 때 사용할 라우트들
      routes: {
        '/mate_list': (context) => const MateListScreen(),
        // '/login': (context) => const AuthHeaderPage(), // 기존 코드들
      },
    );
  }
}