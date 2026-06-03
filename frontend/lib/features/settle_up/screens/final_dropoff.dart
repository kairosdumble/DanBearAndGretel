import 'dart:io';
import "dart:developer" as developer;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/colors.dart';

import '../../chat/screens/mate_chat_screen.dart';
import '../services/images/taximeter_upload_api.dart'; // 미터기 사진 업로드 API 서비스
import '../services/images/taximeter_extract_api.dart'; // 미터기 금액 인식 API 서비스

class FinalDropoffScreen extends StatefulWidget {
  final Map<String, dynamic> matchData;

  const FinalDropoffScreen({Key? key, required this.matchData}) : super(key: key);

  @override
  State<FinalDropoffScreen> createState() => _FinalDropoffScreenState();
}

class _FinalDropoffScreenState extends State<FinalDropoffScreen> {
  // 선택된 택시 미터기 사진 파일
  File? _selectedImageFile;
  // 택시 사진 업로드 후 반환된 이미지 URL을 저장하는 변수
  String? _TaxiImageUrl;
  // 사진 업로드 상태를 나타내는 변수
  bool _isUploadingImage = false; 

  final TextEditingController _fareInputController = TextEditingController();
  final TaximeterUploadAPI _taxmeterUploadAPI = TaximeterUploadAPI();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final String departure = widget.matchData['departure'] ?? '출발지 정보 없음';
    final String destination = widget.matchData['destination'] ?? '목적지 정보 없음';
    final int fare = widget.matchData['fare'] ?? 0;

     return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Center(
                child: Icon(Icons.check_circle, color: Color(0xFF3F51B5), size: 80),
              ),
              const SizedBox(height: 15),
              const Center(
                child: Text("동승자 매칭이 완료되었습니다!\n하차시 정산을 위해 미터기 사진을 찍어주세요.", 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 15),
              
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // 채팅방 이동 로직
                    final int resId = widget.matchData['id'] ?? 0; 
    
                    if (resId != 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                        builder: (context) => MateChatScreen(
                        reservationId: resId, 
                        title: "동승자 채팅방",
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("찾을 수 없습니다.")),
                  );
                }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text("해당 채팅방으로 이동하기"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // 정보 표시 박스
              _buildInfoCard(departure, destination, fare),
              
              const SizedBox(height: 20),
              
              // 미터기 사진 업로드 영역 추가
              _buildPhotoUploadArea(),
              const SizedBox(height: 20),

              // 정산하기 버튼
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // 서버에 금액 전송
                    final String enteredFare = _fareInputController.text;
                    if (enteredFare.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('금액을 입력해주세요.')),
                      );
                      return;
                    }
                    // 서버로 금액 전송 로직 구현 필요
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('입력된 금액: $enteredFare 원')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3F51B5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("정산하기", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // 미터기 이미지 업로드
  Future<void> _pickAndUploadTaxiMeterImage(ImageSource source) async {
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

      final reservationId = widget.matchData['id'];
      if (reservationId is! int || reservationId <= 0) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약 정보가 없어 미터기 업로드를 진행할 수 없습니다.')),
        );
        return;
      }

      // 1. 미터기 이미지 업로드
      final uploadResult = await _taxmeterUploadAPI.uploadTaximeterImage(
        imageFile,
        reservationId: reservationId,
      );
      // 업로드 완료 후 상태 업데이트
      if (!mounted) return;

      if (uploadResult.isSuccess) {
        // 1. 업로드 성공 시 이미지 URL 저장 및 사용자에게 알림
        setState(() {
          _TaxiImageUrl = uploadResult.imageUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 저장되었습니다.')),
        );
        // 2. 업로드 성공 시 금액 인식 API 호출 후 결과 표기
        final recognizedFare = await TaximeterExtractAPI.recognizeFareFromImage(_TaxiImageUrl!);
        if (recognizedFare.isSuccess) {
          setState(() {
            _fareInputController.text = recognizedFare.fare.toString();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(recognizedFare.errorMessage ?? '금액 인식에 실패했습니다.')),
          );
        }
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

  // 사진 선택 옵션 시트 표시
  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadTaxiMeterImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadTaxiMeterImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 사진 업로드 위젯
  Widget _buildPhotoUploadArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("미터기 사진을 올려주세요", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        InkWell(
          onTap: _isUploadingImage ? null : _showImageSourceSheet,
          child: _selectedImageFile == null
              ? Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthColors.gray, width: 1),
            ),
            child:Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_sharp, color: Colors.grey[600], size: 40),
                    const SizedBox(height: 8),
                    Text("총 금액이 보이게 확인해주세요", style: TextStyle(color: Colors.grey[600])),
                  ],
                ),                
              )
              : TextFormField(
                controller: _fareInputController, // 컨트롤러 연결
                keyboardType: TextInputType.number, // 숫자 키패드가 뜨도록 설정
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                decoration: InputDecoration(
                  hintText: '금액이 인식되면 여기에 표시됩니다.',
                  suffixText: '원', // 오른쪽에 '원' 표시 고정
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AuthColors.gray, width: 1), // 기본 회색 테두리
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AuthColors.bluePrimary, width: 2), // 포커스 시 파란색 테두리
                  ),
                ),
                // 사용자가 직접 값을 수정할 때마다 실행되는 이벤트
                onChanged: (value) {
                  _fareInputController.text = value;
                  developer.log('사용자가 수정한 금액: $_fareInputController.text');
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String dep, String dest, int fare) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(title: Text("출발지"), trailing: Text(dep)),
          ListTile(title: Text("하차지"), trailing: Text(dest)),
          const Divider(),
          ListTile(title: Text("정산 금액", style: TextStyle(fontWeight: FontWeight.bold)), 
                   trailing: Text("${fare}원", style: TextStyle(fontWeight: FontWeight.bold, color: AuthColors.bluePrimary))),
        ],
      ),
    );
  }
}