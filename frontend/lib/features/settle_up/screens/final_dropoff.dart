import 'package:flutter/material.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';
import 'dart:io'; // 파일 처리를 위해 필요
import '../services/images/taxmeter_upload_api.dart'; // 미터기 사진 업로드 API 서비스
import 'package:image_picker/image_picker.dart';

class FinalDropoffScreen extends StatefulWidget {
  final Map<String, dynamic> matchData;

  const FinalDropoffScreen({
    Key? key, 
    required this.matchData
  }) : super(key: key);

  @override
  State<FinalDropoffScreen> createState() => _FinalDropoffScreenState();
}

class _FinalDropoffScreenState extends State<FinalDropoffScreen> {
  File? _image; // 선택된 사진을 담을 변수
  File? _selectedImageFile;
  String? _TaxiImageUrl;
  bool _isUploadingImage = false; // 사진 업로드 상태를 나타내는 변수
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
                    // TODO: 정산 로직
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

      // 미터기 이미지 업로드
      final uploadResult = await _taxmeterUploadAPI.uploadTaximeterImage(imageFile);
      // 업로드 완료 후 상태 업데이트
      if (!mounted) return;

      if (uploadResult.isSuccess) {
        setState(() {
          _TaxiImageUrl = uploadResult.imageUrl;
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
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_sharp, color: Colors.grey[600], size: 40),
                    const SizedBox(height: 8),
                    Text("총 금액이 보이게 확인해주세요", style: TextStyle(color: Colors.grey[600])),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
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
                   trailing: Text("${fare}원", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)))),
        ],
      ),
    );
  }
}