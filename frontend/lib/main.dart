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
