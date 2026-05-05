# Dangretel Backend Render 배포 및 이메일 인증 보안 가이드

## 1. Render 서버 배포 준비->ok

- backend/package.json에 nodemailer가 포함되어 있습니다.
- backend/.env 파일에 메일 환경변수(MAIL_HOST, MAIL_PORT, MAIL_USER, MAIL_PASS, MAIL_FROM)를 반드시 Render 환경변수로 등록하세요.
- DATABASE_URL도 Render 환경변수로 등록 필요.

## 2. Render 배포 절차 -> ok

1. Render.com에서 New Web Service → GitHub 저장소 연결
2. Root Directory를 `backend`로 지정
3. Build Command: `npm install` 또는 `npm run build` (필요시)
4. Start Command: `npm run start` 또는 `node src/index.js`
5. 환경변수(ENV Vars)에 .env의 값들을 등록

## 3. 이메일 인증 API 보안

- 이메일 인증 API는 학교 이메일(@dankook.ac.kr)만 허용합니다.
- 인증코드는 DB에 해시값으로 저장되어 노출되지 않습니다.
- 인증코드는 5분간 유효하며, 최대 3회까지만 시도할 수 있습니다.
- 인증 요청 시마다 기존 활성화된 코드는 비활성화 처리됩니다.
- 메일 발송은 nodemailer로, SMTP 계정은 Render 환경변수로 보호하세요.

## 4. 추가 보안 권장사항

- 인증 API에 rate limit(속도 제한) 미들웨어 적용 권장 (예: express-rate-limit)
- 인증 관련 로그는 민감정보를 포함하지 않도록 주의
- 메일 발송 계정은 앱 비밀번호 등 안전한 인증 방식 사용

## 5. 프론트엔드 연동

- BASE_URL을 Render에서 배포된 backend API 주소로 변경
- 인증코드 전송/검증 API는 `/auth/email/send-code`, `/auth/email/verify-code` 입니다.
