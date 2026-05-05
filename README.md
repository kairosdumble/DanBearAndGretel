[2026-1 캡스톤 프로젝트] 택시 공동 탑승 어플(DanBearAndGretel)

# 프로그램 실행방법

1. backend
backend부터 실행(서버 구동)

- (윈도우 기준) cmd창에서 cd backend를 입력
- npm run dev 입력

2. frontend
애뮬레이터나 실제기기 연결 시
- cd frontend를 입력
- npm run dev 입력

웹으로 보기
- flutter run 입력


# 파일 구조 (frontend/lib)
├── main.dart                # 앱의 시작점
├── app.dart                 # 전체적인 테마, 라우팅 설정
├── core/                    # 앱 전반에 공통으로 쓰이는 것들
│   ├── constants/           # 색상, 스타일, API 주소 등
│   └── utils/               # 날짜 포맷팅, 유효성 검사 등 공용 함수
├── features/                # 핵심 기능별 폴더 (추천!)
│   ├── auth/                # 로그인, 회원가입 관련
│   │   ├── screens/         # AuthScreen, LoginForm, SignupForm
│   │   └── widgets/         # 인증 화면 전용 작은 컴포넌트
│   ├── home/                # 메인 홈 화면 관련
│   │   ├── screens/
│   │   └── widgets/
│   └── settings/            # 설정, 프로필 관련
│       ├── screens/         # SettingsScreen
│       └── widgets/
└── data/                    # 서버 통신 및 데이터 모델
    ├── models/              # User, Product 등 데이터 클래스
    └── providers/           # 상태 관리 (Provider, Riverpod 등)

screens: 화면 스크린 UI 
widgets: 재사용성이 높은 위젯들을 따로 정리, 또는 screens 코드가 너무 길어지면 위젯을 분리해서 여기에 선언언