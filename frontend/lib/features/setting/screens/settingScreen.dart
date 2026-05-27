import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/features/auth/screens/auth_header.dart';
import 'package:frontend/features/auth/screens/login.dart';
import 'settingEditScreen.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // ---------------------------------------------------------
  // [데이터 상태 관리]
  // 나중에 API/로그인 정보로 채워질 데이터들입니다. 지금은 비워둡니다.
  // ---------------------------------------------------------
  String profileImageUrl = ""; // 프로필 이미지 URL
  String userName = "";
  String nickname = "";   
  String balance = "";
  String bankName = "";
  String accountNumber = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final token = await AuthTokenStorage.getToken();
      final response = await http.get(
        Uri.parse('${dotenv.env['BASE_URL']}/api/user/profile'), // 서버 주소 다시 확인!
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // 서버에서 받아온 데이터를 화면용 변수에 저장
          userName = data['name'];
          nickname = data['nickname'] ?? "닉네임을 설정하세요";
          balance = data['balance'] ?? 0;
          bankName = data['bank_name'] ?? "";
          accountNumber = data['account_number'] ?? "계좌를 등록하세요";
        });
      }
    } catch (e) {
      print("데이터 로드 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // 1. 프로필 영역
            _buildProfileSection(),
            const SizedBox(height: 30),
            
            // 2. 설정 리스트 영역 (잔액, 계좌, 로그아웃 등)
            _buildSettingList(),
          ],
        ),
      ),
    );
  }

  // 위젯 분리: 프로필 영역
  Widget _buildProfileSection() {
    return Column(
      children: [
        // 프로필 이미지
        CircleAvatar(
          radius: 45,
          backgroundColor: Colors.grey[200],
          backgroundImage: profileImageUrl.isNotEmpty
              ? NetworkImage(profileImageUrl)
              : null, // 비어있으면 null로 두어 기본 배경색 표시
          child: profileImageUrl.isEmpty
              ? Icon(Icons.person, size: 45, color: Colors.grey[400])
              : null,
        ),
        const SizedBox(height: 16),
        
        // 이름 (데이터가 없으면 빈 칸 렌더링 유지)
        Text(
          userName.isNotEmpty ? userName : ' ', 
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        
        // 닉네임 (데이터가 없으면 빈 칸 렌더링 유지)
        Text(
          nickname.isNotEmpty ? nickname : ' ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        
        // 기본 정보 변경 버튼
        OutlinedButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingEditScreen()),
            );
            if (result == true) {
              await _loadUserData(); // 정보가 변경된 후 다시 데이터 로드
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: const Text(
            '기본 정보 변경',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 위젯 분리: 설정 리스트 메뉴 영역
  // ==========================================
  Widget _buildSettingList() {
    return Column(
      children: [
        Divider(thickness: 8, color: Colors.grey[100]),
        
        _buildListTile(
          title: '남은 잔액',
          trailingText: balance,
        ),
        _buildListTile(
          title: '출금 계좌',
          trailingText: '$bankName $accountNumber',
        ),
        _buildListTile(
          title: '충전하기',
          titleColor: Colors.redAccent,
          onTap: () {
            // TODO: 충전 로직 구현
          },
        ),
        
        Divider(thickness: 8, color: Colors.grey[100]),
        
        _buildListTile(
          title: '로그아웃',
          titleColor: const Color(0xFF3F51B5),
          onTap: () async {
            await AuthTokenStorage.clearToken();

            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const AuthHeaderPage(),
                ),
                (Route<dynamic> route) => false,
              );
            }
          },
        ),
        
      ],
    );
  }

  // 재사용 가능한 ListTile 컴포넌트
  Widget _buildListTile({
    required String title,
    String? trailingText,
    Color titleColor = Colors.black87,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailingText != null && trailingText.isNotEmpty
          ? Text(
              trailingText,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            )
          : null, // trailingText가 비어있으면 표시 안 함
      onTap: onTap,
    );
  }
}