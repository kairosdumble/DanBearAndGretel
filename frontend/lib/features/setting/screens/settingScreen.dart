import 'package:flutter/material.dart';
import 'settingEditScreen.dart'; 

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
    // TODO: 화면 진입 시 서버나 로컬 스토리지에서 사용자 정보를 불러오는 함수 호출
    // _loadUserData();
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
        // 얇은 구분선
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
          onTap: () {
            // TODO: 로그아웃 로직 구현
          },
        ),
        _buildListTile(
          title: '탈퇴하기',
          titleColor: Colors.redAccent,
          onTap: () {
            // TODO: 회원탈퇴 로직 구현
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