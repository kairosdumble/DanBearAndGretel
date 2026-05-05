import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'place.dart';

enum PlaceSearchType { departure, destination }

class SearchRequestException implements Exception {
  const SearchRequestException(this.message);

  final String message;
}

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({
    super.key,
    required this.type,
    this.initialQuery = '',
  });

  final PlaceSearchType type;
  final String initialQuery;

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  List<Place> _items = const [];

  String get _resolvedBaseUrl => _baseUrl();

  String get _title {
    switch (widget.type) {
      case PlaceSearchType.departure:
        return '출발지 검색';
      case PlaceSearchType.destination:
        return '목적지 검색';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    if (widget.initialQuery.trim().length >= 2) {
      _search(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (query.length < 2) {
        if (!mounted) {
          return;
        }
        setState(() {
          _items = const [];
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse(
        '$_resolvedBaseUrl/places/search?q=${Uri.encodeQueryComponent(query)}',
      );
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();
      Map<String, dynamic>? decodedResponse;

      try {
        decodedResponse =
            body.isEmpty ? null : jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        decodedResponse = null;
      }

      if (response.statusCode != 200) {
        final error = decodedResponse?['error'];
        final detail = decodedResponse?['detail'];
        final message = [
          'Unexpected status ${response.statusCode}',
          if (error is String && error.isNotEmpty) error,
          if (detail is String && detail.isNotEmpty) detail,
        ].join(' | ');
        throw SearchRequestException(message);
      }

      final decoded = decodedResponse ?? (jsonDecode(body) as Map<String, dynamic>);
      final items = (decoded['items'] as List<dynamic>)
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _items = const [];
        _isLoading = false;
        _errorMessage = _buildTimeoutMessage();
      });
    } on SocketException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _items = const [];
        _isLoading = false;
        _errorMessage = _buildSocketErrorMessage(error);
      });
    } on SearchRequestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _items = const [];
        _isLoading = false;
        _errorMessage =
            '검색 서버 응답이 올바르지 않습니다.\n${error.message}\n($_resolvedBaseUrl)';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _items = const [];
        _isLoading = false;
        _errorMessage = '검색 결과를 불러오지 못했습니다. $_resolvedBaseUrl';
      });
    } finally {
      client?.close(force: true);
    }
  }

  String _buildTimeoutMessage() {
    if (defaultTargetPlatform == TargetPlatform.android &&
        _configuredBaseUrl.isEmpty) {
      return '서버 연결 시간이 초과되었습니다. 에뮬레이터면 $_resolvedBaseUrl 가 맞지만, 실제 안드로이드 기기면 PC의 IP로 API_BASE_URL을 지정해야 합니다.';
    }

    return '서버 연결 시간이 초과되었습니다. $_resolvedBaseUrl 를 확인하세요.';
  }

  String _buildSocketErrorMessage(SocketException error) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        _configuredBaseUrl.isEmpty) {
      return '검색 서버에 연결할 수 없습니다. 현재 주소는 $_resolvedBaseUrl 입니다. 에뮬레이터가 아니라 실제 안드로이드 기기라면 --dart-define=API_BASE_URL=http://PC_IP:3000 으로 실행해야 합니다. (${error.message})';
    }

    return '검색 서버에 연결할 수 없습니다. $_resolvedBaseUrl (${error.message})';
  }

  String _baseUrl() {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD8D8DD)),
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '장소를 검색하세요',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF3056A0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final query = _controller.text.trim();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3056A0),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    if (query.length < 2) {
      return const Center(
        child: Text(
          '두 글자 이상 입력하면 검색 결과가 표시됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final place = _items[index];
        final addressLine = place.distanceLabel == null
            ? place.roadAddress
            : '${place.distanceLabel} | ${place.roadAddress}';
        return InkWell(
          onTap: () => Navigator.of(context).pop(place),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Color(0xFF969AA5),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        addressLine,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7B8090),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
