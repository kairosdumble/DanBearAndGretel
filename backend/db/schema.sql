-- 단국대(@dankook.ac.kr 등) 메일 인증 기반 사용자 테이블
-- PostgreSQL 기준 DDL입니다. MySQL 사용 시 타입만 조정하면 됩니다.

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  -- 학번 (단국대 학번 형식은 애플리케이션에서 검증)
  student_id VARCHAR(32) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  -- 단국대 이메일 (회원가입·로그인 식별자)
  email VARCHAR(255) NOT NULL UNIQUE,
  -- 비밀번호는 평문 저장 금지 — bcrypt 등으로 해시한 값만 저장
  password_hash VARCHAR(255) NOT NULL,
  -- 이메일 인증용 일회성 코드 (미인증·재발급 시 갱신, 인증 완료 후 NULL 권장)
  email_verification_code VARCHAR(32),
  -- 메일 인증 완료 여부
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_student_id ON users (student_id);
