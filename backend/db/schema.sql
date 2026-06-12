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
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- 프로필 이미지 URL
  profile_image_url VARCHAR(512) NULL,
  -- 닉네임
  nickname VARCHAR(50),
  -- 은행명
  bank_name VARCHAR(50),
  -- 계좌번호
  account_number VARCHAR(100),
  balance BIGINT DEFAULT 0
);

-- 기존 users 테이블에도 누락 컬럼 반영
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_url VARCHAR(512) NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS nickname VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bank_name VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS account_number VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS balance BIGINT DEFAULT 0;

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
CREATE TABLE IF NOT EXISTS reservations (
    id SERIAL PRIMARY KEY, -- 예약 id
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, -- 예약자 id
    departure_location TEXT NOT NULL, -- 출발장소
    destination_location TEXT NOT NULL, -- 도착장소
    departure_time TIMESTAMP NOT NULL, -- 출발시간
    -- 예약 상태
    -- READY: 모집 중 (블루투스 매칭 전)
    -- MATCHED: 방장이 동승자 선택 후 승인 대기/매칭 확정한 단계
    -- RUNNING: 블루투스 전체 연결 후(택시 타는 동안)
    -- COMPLETED: 최종하차자 하차 후
    status TEXT NOT NULL DEFAULT 'READY' CHECK (status IN ('MATCHED', 'READY', 'RUNNING', 'COMPLETED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 생성시간
        ADD COLUMN IF NOT EXISTS departure_lat DOUBLE PRECISION,
    departure_lng DOUBLE PRECISION,
    destination_lat DOUBLE PRECISION,
    destination_lng DOUBLE PRECISION;
);

-- 참여자 관리 테이블
CREATE TABLE IF NOT EXISTS reservation_bluetooth_participants (
    reservation_id INTEGER REFERENCES reservations(id) ON DELETE CASCADE, -- 예약 항목 번호
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, -- 참여자 id
    dropoff_completed BOOLEAN NOT NULL DEFAULT FALSE, -- 택시 하차여부
    distance BIGINT NULL, -- 출발지로부터 거리 (예: 1500m는 1500) -> 정산 시점에 계산되어 업데이트
    fare BIGINT NULL, -- 개인별 요금 (예: 1500원은 1500)-> 정산 시점에 계산되어 업데이트
    PRIMARY KEY (reservation_id, user_id) -- 한 명의 사용자가 같은 예약에 중복 체크인 방지
);

-- 채팅방 참여하는 사람 테이블
CREATE TABLE IF NOT EXISTS reservation_chat_participants(
    reservation_id INTEGER REFERENCES reservations(id) ON DELETE CASCADE, -- 예약 항목 번호
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, -- 참여자 id
    PRIMARY KEY (reservation_id, user_id) -- 한 명의 사용자가 같은 예약에 중복 체크인 방지
);

-- 예약 챗 메시지 테이블
CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGSERIAL PRIMARY KEY, -- 메시지 고유 id
    reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE, -- 예약 항목 번호
    sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- 보낸 사용자 id
    message TEXT NOT NULL, -- 메시지 내용
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW() -- 생성시간
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_reservation_created ON chat_messages (reservation_id, created_at, id);

-- BLE 근접 매칭: 방장 요청 + 참여자 승인
CREATE TABLE IF NOT EXISTS reservation_proximity_requests (
    id SERIAL PRIMARY KEY,
    reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
    leader_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    selected_user_ids INTEGER[] NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'CONFIRMED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reservation_proximity_approvals (
    request_id INTEGER NOT NULL REFERENCES reservation_proximity_requests(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    approved_at TIMESTAMPTZ,
    PRIMARY KEY (request_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_proximity_requests_reservation_status
    ON reservation_proximity_requests (reservation_id, status);

CREATE TABLE IF NOT EXISTS reservation_proximity_presence (
    reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (reservation_id, user_id)
);
-- 예약별 결제 테이블
-- 생성시점: 미터기 이미지 업로드 시점
-- 정산은 reservation_bluetooth_participants 테이블에 존재하는 사람들과 거리를 기준으로 계산
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY, -- 결제 고유 id
    reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE, -- 예약 항목 번호
    final_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- 결제한 사용자 id(최종 하차자)
    taximeter_image_url VARCHAR(255) NULL, -- 결제한 사용자의 택시 미터 이미지 URL
    --settle.service.js의 updateTotal 함수에서 fare 컬럼 추가함
);