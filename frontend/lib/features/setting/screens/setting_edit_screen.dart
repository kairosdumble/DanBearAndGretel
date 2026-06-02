import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/features/setting/services/images/profile_upload_api.dart';
import 'package:image_picker/image_picker.dart';

class SettingEditScreen extends StatefulWidget {
  const SettingEditScreen({Key? key}) : super(key: key);

  @override
  State<SettingEditScreen> createState() => _SettingEditScreenState();
}

class _SettingEditScreenState extends State<SettingEditScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final ProfileUploadAPI _profileUploadAPI = ProfileUploadAPI();
  final ImagePicker _imagePicker = ImagePicker();

  String? _profileImageUrl;
  File? _selectedImageFile;
  bool _isUploadingImage = false;

  String _selectedBank = '카카오뱅크';
  final List<String> _bankList = ['카카오뱅크', '신한은행', '국민은행', '우리은행', '토스뱅크'];
  
  // 프로필 정보 저장
  Future<void> _saveProfile() async {
    try {
      final token = await AuthTokenStorage.getToken();
      final url = Uri.parse('${dotenv.env['BASE_URL']}/api/user/profile');

      final response = await http.put(url,
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

  // 프로필 이미지 조회
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
          _profileImageUrl = data['profile_image_url'];
        });
      } else {
        print("데이터 로드 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("데이터 로드 중 오류 발생: $e");
    }
  }
  
  // 프로필 이미지 업로드
  Future<void> _pickAndUploadProfileImage(ImageSource source) async {
    try {
      // 5MB 이하 이미지 선택
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      setState(() {
        _selectedImageFile = imageFile;
        _isUploadingImage = true;
      });

      // 프로필 이미지 업로드
      final uploadResult = await _profileUploadAPI.uploadProfileImage(imageFile);
      // 업로드 완료 후 상태 업데이트
      if (!mounted) return;

      if (uploadResult.isSuccess) {
        setState(() {
          _profileImageUrl = uploadResult.imageUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 저장되었습니다.')),
        );
      } else {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadResult.errorMessage ?? ' 사진 업로드에 실패했습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 선택 오류: $e')),
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfileImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
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
    ImageProvider? imageProvider;
    if (_selectedImageFile != null) {
      imageProvider = FileImage(_selectedImageFile!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_profileImageUrl!);
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: Colors.grey[200],
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Icon(Icons.person, size: 45, color: Colors.grey[400])
              : null,
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploadingImage ? null : _showImageSourceSheet,
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