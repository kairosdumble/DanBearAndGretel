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
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,tions (email, is_active);
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_student_id ON users (student_id);
CREATE INDEX IF NOT EXISTS idx_email_verifications_email_active 
ON email_verifications (email, is_active);

