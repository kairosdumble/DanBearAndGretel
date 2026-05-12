const verificationService = require("../services/emailVerification.service");
const pool = require("../db/pool");
const bcrypt = require("bcrypt"); // 비밀번호 암호화용

// 이메일 전송 컨트롤러
async function sendCode(req, res) { // req: 요청 객체, res:응답 객체
  try {
    const { email } = req.body;
    const result = await verificationService.sendCode(email);
    res.status(200).json(result);
  } catch (error) {
    console.error("sendCode 에러 발생:", error); 
    res.status(error.status || 500).json({ message: error.message });
  }
}

//이메일 인증 코드 검증 컨트롤러
async function verifyCode(req, res) {
  try {
    const { email, code } = req.body;
    const result = await verificationService.verifyCode(email, code);
    res.status(200).json(result);
  } catch (error) {
    console.error("verifyCode 에러 발생:", error);
    res.status(error.status || 500).json({ message: error.message });
  }
}

async function signup(req, res) {
  try {
    const { student_id, name, email, password } = req.body;

    // [추가] 0. 백엔드 수신 로그
    console.log("========================================");
    console.log("회원가입 요청 수신");
    console.log(`학번: [${student_id}], 이름: [${name}], 이메일: [${email}]`);
    console.log("========================================");

    // [보완] 1. 빈 값 방어 로직 (trim() 추가)
    if (!student_id?.trim() || !name?.trim() || !email?.trim() || !password?.trim()) {
      console.log("실패: 필수 입력값이 누락되었습니다.");
      return res.status(400).json({ message: "모든 항목을 입력해주세요." });
    }

    // 1. 이메일 중복 체크
    const emailExist = await pool.query("SELECT 1 FROM users WHERE email = $1", [email]);
    if (emailExist.rows.length > 0) {
      console.log("실패: 이메일 중복 (Conflict)");
      return res.status(409).json({ message: "이미 가입된 이메일입니다." });
    }

    // 2. 학번 중복 체크
    const studentIdExist = await pool.query("SELECT 1 FROM users WHERE student_id = $1", [student_id]);
    if (studentIdExist.rows.length > 0) {
      console.log("실패: 학번 중복 (Conflict)");
      return res.status(409).json({ message: "이미 등록된 학번입니다." });
    }

    console.log("비밀번호 암호화 및 DB 저장 시작...");

    // 3. 비밀번호 암호화
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // 4. DB 저장
    const query = `INSERT INTO users
      (student_id, name, email, password_hash, expires_at)
      VALUES ($1, $2, $3, $4, now())
      RETURNING id, student_id, name, email, email_verified`;
    const values = [student_id, name, email, hashedPassword];

    const newUser = await pool.query(query, values);

    console.log("성공: 새로운 회원 등록 완료! ID:", newUser.rows[0].id);

    res.status(201).json({
      message: "회원가입이 완료되었습니다.",
      user: newUser.rows[0]
    });
  } catch (error) {
    // [보완] catch문 안의 print()는 에러의 원인이니 지우고 console.error만 남기세요.
    console.error("회원가입 서버 내부 에러 발생:", error);
    res.status(500).json({ message: "서버 내부 에러가 발생했습니다." });
  }
}
async function login(req, res) {
  try {
    const { email, password } = req.body;

    // 1. 사용자 조회
    const result = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
    const user = result.rows[0];

    // 2. 사용자가 존재하는지 확인
    if (!user) {
      return res.status(401).json({ message: "존재하지 않는 이메일입니다." });
    }

    // 3. 암호화된 비밀번호 비교 (bcrypt.compare 사용)
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ message: "비밀번호가 일치하지 않습니다." });
    }

    res.status(200).json({
      message: "로그인 성공!",
      user: { 
        id: user.id, 
        name: user.name, 
        email: user.email 
      }
    });
  } catch (error) {
    console.error("로그인 에러:", error);
    res.status(500).json({ message: "로그인 중 에러 발생" });
  }
}

module.exports = {
  sendCode,
  verifyCode,
  signup,
  login,
};