import 'package:flutter/material.dart';

class SettingEditScreen extends StatefulWidget {
  const SettingEditScreen({Key? key}) : super(key: key);

  @override
  State<SettingEditScreen> createState() => _SettingEditScreenState();
}

class _SettingEditScreenState extends State<SettingEditScreen> {
  // ---------------------------------------------------------
  // [컨트롤러 및 상태 변수]
  // ---------------------------------------------------------
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _verifyCodeController = TextEditingController();

  String _selectedBank = '카카오뱅크';
  final List<String> _bankList = ['카카오뱅크', '신한은행', '국민은행', '우리은행', '토스뱅크'];

  bool _isVerifyCodeSent = false; // 인증번호 전송 여부
  bool _isVerified = false;       // 인증 완료 여부

  @override
  void initState() {
    super.initState();
    // TODO: 화면 진입 시 기존 정보가 있다면 컨트롤러에 초기값으로 세팅
    // _nicknameController.text = "기존 닉네임";
    // _accountController.text = "기존 계좌번호";
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _accountController.dispose();
    _verifyCodeController.dispose();
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'nickname': _nicknameController.text,
                'bank': _selectedBank,
                'account': _accountController.text,
              });
            },
            child: const Text(
              '변경 완료',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
              hintText: '단곰', // 예시 이미지에 있는 placeholder
            ),
            const SizedBox(height: 30),

            // 3. 계좌 정보 입력 폼
            const Text(
              '계좌 정보',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            
            // 은행 선택 + 계좌번호 입력 + 인증번호 전송 버튼
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
            const SizedBox(height: 8),
            
            // 인증번호 전송 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isVerifyCodeSent = true;
                    _isVerified = false; // 재전송 시 인증상태 초기화
                  });
                  // TODO: 서버로 인증번호 발송 API 호출
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('인증번호가 전송되었습니다.')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('인증번호 전송', style: TextStyle(color: Colors.black87)),
              ),
            ),

            // 4. 인증번호 입력 폼 (전송 버튼을 누른 후에만 표시됨)
            if (_isVerifyCodeSent) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _verifyCodeController,
                      hintText: '인증번호를 입력해주세요',
                      keyboardType: TextInputType.number,
                      enabled: !_isVerified, // 인증 완료 시 입력 불가
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isVerified
                          ? null
                          : () {
                              setState(() {
                                _isVerified = true;
                              });
                              // TODO: 서버로 인증번호 검증 API 호출
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('인증이 완료되었습니다.')),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isVerified ? Colors.grey : Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(_isVerified ? '완료' : '확인', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
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