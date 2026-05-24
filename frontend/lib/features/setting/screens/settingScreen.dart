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
  String userName = "";        // 예: 단곰
  String nickname = "";        // 예: 익명123
  String balance = "";         // 예: 10,000원
  String accountInfo = "";     // 예: 카카오뱅크 1234-56-7890

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String? token = await AuthTokenStorage.getToken();

      if (token == null || token.isEmpty) {
        print("저장된 토큰이 없습니다. 로그인 필요.");
        return;
      }
      final url = Uri.parse('${dotenv.env['BASE_URL']}/api/user/profile'); // 백엔드 API 엔드포인트
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data['name']; // 백엔드에서 보낸 필드명과 일치해야 함
        });
      } else {
        print("데이터 로드 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("통신 에러: $e");
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
            // 2. 돌아온 데이터가 있다면 변수에 넣고 화면 새로고침 (setState)
            if (result != null && result is Map<String, dynamic>) {
              setState(() {
                // 닉네임 업데이트 (빈 값이 아닐 때만)
                if (result['nickname'] != null && result['nickname'].toString().isNotEmpty) {
                  nickname = result['nickname'];
                }
                
                // 계좌번호 업데이트 (빈 값이 아닐 때만)
                if (result['account'] != null && result['account'].toString().isNotEmpty) {
                  accountInfo = "${result['bank']} ${result['account']}";
                }
              });
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
          trailingText: accountInfo,
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