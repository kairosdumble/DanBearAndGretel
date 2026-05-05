const crypto = require("crypto"); // 암호화 도구
const pool = require("../db/pool"); // 데이터베이스 연결 풀
const { sendVerificationEmail } = require("../utils/mail");

const CODE_TTL_MINUTES = Number(process.env.VERIFICATION_CODE_TTL_MINUTES || 5);
const MAX_ATTEMPTS = Number(process.env.VERIFICATION_MAX_ATTEMPTS || 3);
const ALLOWED_DOMAIN = "@dankook.ac.kr"; // 우리 학교 학생만 인증 가능하도록 도메인 제한

function isAllowedSchoolEmail(email) {
  return typeof email === "string" && email.toLowerCase().endsWith(ALLOWED_DOMAIN);
}

function generateSixDigitCode() {
  return String(Math.floor(Math.random() * 1000000)).padStart(6, "0");
}

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

async function sendCode(email) {
  // 학교 이메일 형식인지 확인
  if (!isAllowedSchoolEmail(email)) {
    const err = new Error("학교 이메일(@dankook.ac.kr)만 가능합니다.");
    err.status = 400; // 에러 발생 시
    throw err;
  }

  // 6자리 인증 코드 생성 및 해싱
  const code = generateSixDigitCode();
  const codeHash = hashCode(code);

  await pool.query(
    `UPDATE email_verifications
     SET is_active = false, updated_at = now()
     WHERE email = $1 AND is_active = true`,
    [email]
  );

  await pool.query(
    `INSERT INTO email_verifications
      (email, code_hash, attempt_count, max_attempts, expires_at, is_active)
     VALUES
      ($1, $2, 0, $3, now() + ($4 || ' minutes')::interval, true)`,
    [email, codeHash, MAX_ATTEMPTS, String(CODE_TTL_MINUTES)]
  );

  await sendVerificationEmail(email, code);

  return { message: "인증번호를 전송했습니다." };
}

async function verifyCode(email, code) {
  const { rows } = await pool.query(
    `SELECT id, code_hash, attempt_count, max_attempts, expires_at
     FROM email_verifications
     WHERE email = $1 AND is_active = true
     ORDER BY created_at DESC
     LIMIT 1`,
    [email]
  );

  if (rows.length === 0) {
    const err = new Error("활성 인증 요청이 없습니다. 코드를 다시 요청하세요.");
    err.status = 400;
    throw err;
  }

  const row = rows[0];

  if (new Date(row.expires_at) < new Date()) {
    await pool.query(
      `UPDATE email_verifications SET is_active = false, updated_at = now() WHERE id = $1`,
      [row.id]
    );
    const err = new Error("인증번호가 만료되었습니다.");
    err.status = 410;
    throw err;
  }

  if (row.attempt_count >= row.max_attempts) {
    const err = new Error("최대 시도 횟수를 초과했습니다.");
    err.status = 429;
    throw err;
  }

  // 입력된 코드와 해시된 코드 비교
  const isMatch = hashCode(code) === row.code_hash;
  if (!isMatch) {
    const nextAttempt = row.attempt_count + 1;
    const shouldDeactivate = nextAttempt >= row.max_attempts;

    await pool.query(
      `UPDATE email_verifications
       SET attempt_count = $2, is_active = $3, updated_at = now()
       WHERE id = $1`,
      [row.id, nextAttempt, !shouldDeactivate]
    );

    const err = new Error("인증번호가 올바르지 않습니다.");
    err.status = shouldDeactivate ? 429 : 401;
    throw err;
  }

  await pool.query(
    `UPDATE email_verifications
     SET verified_at = now(), is_active = false, updated_at = now()
     WHERE id = $1`,
    [row.id]
  );

  return { message: "이메일 인증이 완료되었습니다." };
}

module.exports = {
  sendCode,
  verifyCode,
};