import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/data/colors.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';

import '../models/settlement_calculator.dart';
import '../services/images/taximeter_extract_api.dart';
import '../services/images/taximeter_upload_api.dart';
import '../services/settlement_api.dart';

class FinalDropoffScreen extends StatefulWidget {
  const FinalDropoffScreen({super.key, required this.matchData});

  final Map<String, dynamic> matchData;

  @override
  State<FinalDropoffScreen> createState() => _FinalDropoffScreenState();
}

class _FinalDropoffScreenState extends State<FinalDropoffScreen> {
  final TextEditingController _fareInputController = TextEditingController(
    text: '18000',
  );
  final TaximeterUploadAPI _taximeterUploadApi = TaximeterUploadAPI();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImageFile;
  String? _taximeterImageUrl;
  SettlementData? _settlementData;
  bool _isLoadingSettlement = true;
  bool _isUploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fare = widget.matchData['fare'];
    if (fare is num && fare > 0) {
      _fareInputController.text = fare.toInt().toString();
    }
    _fareInputController.addListener(_recalculate);
    _loadSettlement();
  }

  @override
  void dispose() {
    _fareInputController.removeListener(_recalculate);
    _fareInputController.dispose();
    super.dispose();
  }

  int get _reservationId {
    final value = widget.matchData['id'] ?? widget.matchData['reservation_id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get _totalFare =>
      double.tryParse(_fareInputController.text.replaceAll(',', '').trim()) ??
      0;

  SettlementResult? get _settlement {
    final data = _settlementData;
    if (data == null) return null;
    return calculateSettlement(
      passengers: data.passengers,
      totalFare: _totalFare,
      creatorId: data.reservation.creatorId,
    );
  }

  Future<void> _loadSettlement() async {
    final reservationId = _reservationId;
    if (reservationId <= 0) {
      setState(() {
        _isLoadingSettlement = false;
        _error = '예약 정보가 없어 정산 정보를 불러올 수 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoadingSettlement = true;
      _error = null;
    });

    try {
      final data = await SettlementApi.fetchSettlement(reservationId);
      if (!mounted) return;
      setState(() {
        _settlementData = data;
        _isLoadingSettlement = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSettlement = false;
        _error = error.toString();
      });
    }
  }

  void _recalculate() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAndUploadTaximeterImage(ImageSource source) async {
    final reservationId = _reservationId;
    if (reservationId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예약 정보가 없어 미터기 사진을 업로드할 수 없습니다.')),
      );
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() {
      _selectedImageFile = File(pickedFile.path);
      _isUploadingImage = true;
    });

    final uploadResult = await _taximeterUploadApi.uploadTaximeterImage(
      _selectedImageFile!,
      reservationId: reservationId,
    );
    if (!mounted) return;

    if (!uploadResult.isSuccess) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uploadResult.errorMessage ?? '사진 업로드에 실패했습니다.')),
      );
      return;
    }

    _taximeterImageUrl = uploadResult.imageUrl;
    final recognizedFare = await TaximeterExtractAPI.recognizeFareFromImage(
      _taximeterImageUrl!,
    );
    if (!mounted) return;

    setState(() {
      _isUploadingImage = false;
      if (recognizedFare.isSuccess) {
        _fareInputController.text = recognizedFare.fare.toString();
      }
    });

    if (!recognizedFare.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(recognizedFare.errorMessage ?? '금액 인식에 실패했습니다.'),
        ),
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadTaximeterImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadTaximeterImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openChat() {
    final reservationId = _reservationId;
    if (reservationId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MateChatScreen(reservationId: reservationId, title: '동승자 채팅방'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _settlementData;
    final settlement = _settlement;
    final currentUserId = data?.currentUserId ?? '';
    final finalSettler = settlement?.finalSettler;
    final isFinalSettler = finalSettler?.id == currentUserId;
    final myFare = settlement?.fareByPassenger[currentUserId] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('최종 정산'),
        actions: [
          IconButton(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingSettlement
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadSettlement)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: AuthColors.bluePrimary,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        '동승자 매칭이 완료되었습니다.\n하차 시 정산을 진행하세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _RouteInfoCard(data: data!),
                    const SizedBox(height: 16),
                    _TaximeterUploadCard(
                      selectedImageFile: _selectedImageFile,
                      uploading: _isUploadingImage,
                      fareController: _fareInputController,
                      onPickImage: _showImageSourceSheet,
                    ),
                    const SizedBox(height: 16),
                    _MySettlementCard(
                      isFinalSettler: isFinalSettler,
                      myFare: myFare,
                      finalSettlerName: finalSettler?.displayName ?? '최종 정산자',
                    ),
                    const SizedBox(height: 16),
                    if (settlement != null)
                      _SettlementBreakdown(data: data, settlement: settlement),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  const _RouteInfoCard({required this.data});

  final SettlementData data;

  @override
  Widget build(BuildContext context) {
    final reservation = data.reservation;
    final currentPassenger = data.passengers.firstWhere(
      (passenger) => passenger.id == data.currentUserId,
      orElse: () => data.passengers.first,
    );

    return _InfoCard(
      title: '이동 정보',
      children: [
        _InfoRow('출발지', reservation.departureLocation),
        _InfoRow(
          '나의 도착지',
          currentPassenger.destinationLocation.isNotEmpty
              ? currentPassenger.destinationLocation
              : reservation.destinationLocation,
        ),
        _InfoRow(
          '나의 하차 거리',
          formatDistanceMeters(currentPassenger.dropoffDistanceMeters),
        ),
        _InfoRow(
          '전체 이동 거리',
          formatDistanceMeters(reservation.routeDistanceMeters),
        ),
      ],
    );
  }
}

class _TaximeterUploadCard extends StatelessWidget {
  const _TaximeterUploadCard({
    required this.selectedImageFile,
    required this.uploading,
    required this.fareController,
    required this.onPickImage,
  });

  final File? selectedImageFile;
  final bool uploading;
  final TextEditingController fareController;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '총 결제금액',
      children: [
        InkWell(
          onTap: uploading ? null : onPickImage,
          child: Container(
            width: double.infinity,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthColors.gray),
            ),
            child: Center(
              child: uploading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectedImageFile == null
                              ? Icons.upload_sharp
                              : Icons.check_circle_outline,
                          color: AuthColors.grayText,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedImageFile == null
                              ? '미터기 사진 업로드'
                              : '사진 업로드 완료',
                          style: const TextStyle(color: AuthColors.grayText),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: fareController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '총 결제금액',
            suffixText: '원',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _MySettlementCard extends StatelessWidget {
  const _MySettlementCard({
    required this.isFinalSettler,
    required this.myFare,
    required this.finalSettlerName,
  });

  final bool isFinalSettler;
  final double myFare;
  final String finalSettlerName;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '내 정산',
      children: [
        _InfoRow('내 결제금액', formatCurrency(myFare)),
        _InfoRow('최종 정산자', finalSettlerName),
        const SizedBox(height: 8),
        Text(
          isFinalSettler
              ? '최종 정산자는 내 금액만 확인하면 됩니다.'
              : '$finalSettlerName에게 ${formatCurrency(myFare)} 송금하세요.',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AuthColors.bluePrimary,
          ),
        ),
      ],
    );
  }
}

class _SettlementBreakdown extends StatelessWidget {
  const _SettlementBreakdown({required this.data, required this.settlement});

  final SettlementData data;
  final SettlementResult settlement;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '참여자별 금액',
      children: [
        for (final passenger in data.passengers)
          _InfoRow(
            '${passenger.displayName} (${formatDistanceMeters(passenger.dropoffDistanceMeters)})',
            formatCurrency(settlement.fareByPassenger[passenger.id] ?? 0),
          ),
        if (settlement.sections.isNotEmpty) ...[
          const Divider(height: 24),
          const Text(
            '구간별 계산',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final section in settlement.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${section.name}: ${formatCurrency(section.sectionFare)} / ${section.activePassengers.length}명',
                style: const TextStyle(
                  fontSize: 12,
                  color: AuthColors.grayText,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: AuthColors.grayText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
