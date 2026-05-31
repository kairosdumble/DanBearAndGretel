import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';

class SettingEditScreen extends StatefulWidget {
  const SettingEditScreen({Key? key}) : super(key: key);

  @override
  State<SettingEditScreen> createState() => _SettingEditScreenState();
}

class _SettingEditScreenState extends State<SettingEditScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  String _selectedBank = '카카오뱅크';
  final List<String> _bankList = ['카카오뱅크', '신한은행', '국민은행', '우리은행', '토스뱅크'];

  Future<void> _saveProfile() async {
    try {
      final token = await AuthTokenStorage.getToken();
      final url = Uri.parse('${dotenv.env['BASE_URL']}/api/user/profile');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nickname': _nicknameController.text,
          'bank_name': _selectedBank,
          'account_number': _accountController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장되었습니다!")));
        Navigator.pop(context, true); // 설정 페이지로 성공 신호(true) 전달
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장 실패")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final token = await AuthTokenStorage.getToken();
      final url = Uri.parse('${dotenv.env['BASE_URL']}/api/user/profile');

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
          _nicknameController.text = data['nickname'] ?? '';
          _accountController.text = data['account_number'] ?? '';
          _selectedBank = data['bank_name'] ?? _selectedBank;
        });
      } else {
        print("데이터 로드 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("데이터 로드 중 오류 발생: $e");
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 프로필 이미지 수정 영역
            Center(
              child: _buildProfileImageEdit(),
            ),
            const SizedBox(height: 40),

            // 2. 닉네임 입력 폼
            const Text(
              '닉네임',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nicknameController,
              hintText: '닉네임을 입력해주세요', // 예시 이미지에 있는 placeholder
            ),
            const SizedBox(height: 30),

            // 3. 계좌 정보 입력 폼
            const Text(
              '계좌 정보',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            
            // 은행 선택 + 계좌번호 입력
            Row(
              children: [
                _buildBankDropdown(),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _accountController,
                    hintText: '계좌번호 입력',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // 여기에 서버로 정보를 보내는 _saveProfile() 함수를 연결하세요
                  _saveProfile(); 
                },
                style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "저장하기", 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ),
            ),
          ],
        ),
      ),
    );  
  }

  // ==========================================
  // 위젯 분리: 프로필 이미지 및 카메라 아이콘
  // ==========================================
  Widget _buildProfileImageEdit() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, size: 45, color: Colors.grey[400]),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              // TODO: 갤러리/카메라 접근하여 이미지 변경 로직
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 위젯 분리: 은행 선택 드롭다운
  // ==========================================
  Widget _buildBankDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBank,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: _bankList.map((String bank) {
            return DropdownMenuItem<String>(
              value: bank,
              child: Text(bank, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedBank = newValue!;
            });
          },
        ),
      ),
    );
  }

  // ==========================================
  // 위젯 분리: 공통 텍스트 필드 폼
  // ==========================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black54),
            borderRadius: BorderRadius.circular(8),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}