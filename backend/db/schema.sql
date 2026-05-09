-- 단국대(@dankook.ac.kr 등) 메일 인증 기반 사용자 테이블
CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  -- 학번 (단국대 기준 8글자)
  student_id VARCHAR(8) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  -- 단국대 이메일 (회원가입·로그인 식별자)
  email VARCHAR(100) NOT NULL UNIQUE,
  -- 비밀번호는 평문 저장 금지 — bcrypt 등으로 해시한 값만 저장
  password_hash VARCHAR(100) NOT NULL,
  -- 이메일 인증용 일회성 코드 (미인증·재발급 시 갱신, 인증 완료 후 NULL 권장)
  email_verification_code VARCHAR(6),
  -- 이메일 인증 시도 횟수
  attempt_count INT NOT NULL DEFAULT 0,
  -- 이메일 인증 시도 횟수 제한
  max_attempts INT NOT NULL DEFAULT 3,
  -- 이메일 인증 코드 만료 시간
  expires_at TIMESTAMPTZ NOT NULL,
  -- 이메일 인증 완료 시간
  verified_at TIMESTAMPTZ NULL,
  -- 메일 인증 완료 여부
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- 메일 검증 테이블
CREATE TABLE IF NOT EXISTS email_verifications(
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  code_hash VARCHAR(64) NOT NULL, -- 인증번호 해시값
  attempt_count INTEGER DEFAULT 0, -- 시도 횟수
  max_attempts INTEGER DEFAULT 3, -- 최대 허용 횟수
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL, -- 만료 시간
  verified_at TIMESTAMP WITH TIME ZONE, -- 인증 완료 시간
  is_active BOOLEAN DEFAULT true, -- 활성화 여부
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_student_id ON users (student_id);
CREATE INDEX IF NOT EXISTS idx_email_verifications_email_active ON email_verifications (email, is_active);

-- 예약 정보
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,          -- 로그인한 사용자 ID
    departure_location TEXT NOT NULL, -- 출발장소
    destination_location TEXT NOT NULL, -- 도착장소
    departure_time TIMESTAMP NOT NULL, -- 출발시간
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 생성시간
);