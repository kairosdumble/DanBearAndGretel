import 'package:flutter/material.dart';
import 'package:frontend/features/auth/screens/auth_email.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 파일 로드용

void main() async {
  await dotenv.load(fileName: ".env");
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
      //[테스트용] email_auth 화면으로 이동하는 버튼
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AuthEmailScreen(email: "yir1125@dankook.ac.kr"),
            ),
          );
        },
        child: const Icon(Icons.keyboard_arrow_up_rounded),
      ),
    );
  }
}
