const verificationService = require("../services/emailVerification.service");
const pool = require("../db/pool");
const bcrypt = require("bcrypt"); // 비밀번호 암호화용

async function sendCode(req, res) {
  try {
    const { email } = req.body;
    const result = await verificationService.sendCode(email);
    res.status(200).json(result);
  } catch (error) {
    res.status(error.status || 500).json({ message: error.message });
  }
}

async function verifyCode(req, res) {
  try {
    const { email, code } = req.body;
    const result = await verificationService.verifyCode(email, code);
    res.status(200).json(result);
  } catch (error) {
    res.status(error.status || 500).json({ message: error.message });
  }
}

async function signup(req, res) {
  try {
    const { student_id, name, email, password } = req.body;
    /*
    if (!student_id || !name || !email || !password) {
      return res.status(400).json({ message: "학번, 이름, 이메일, 비밀번호를 모두 입력해주세요." });
    }

    if (!/^[0-9]{8}$/.test(student_id)) {
      return res.status(400).json({ message: "유효한 8자리 학번을 입력해주세요." });
    }
    */
    // 1. 이메일 중복 체크
    const emailExist = await pool.query("SELECT 1 FROM users WHERE email = $1", [email]);
    if (emailExist.rows.length > 0) {
      return res.status(409).json({ message: "이미 가입된 이메일입니다." });
    }

    // 2. 학번 중복 체크
    const studentIdExist = await pool.query("SELECT 1 FROM users WHERE student_id = $1", [student_id]);
    if (studentIdExist.rows.length > 0) {
      return res.status(409).json({ message: "이미 등록된 학번입니다." });
    }

    // 3. 비밀번호 암호화 (Salt Round: 10)
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // 4. DB 저장
    const query = `INSERT INTO users
      (student_id, name, email, password_hash, expires_at)
      VALUES ($1, $2, $3, $4, now())
      RETURNING id, student_id, name, email, email_verified`;
    const values = [student_id, name, email, hashedPassword];

    const newUser = await pool.query(query, values);

    res.status(201).json({
      message: "회원가입이 완료되었습니다.",
      user: newUser.rows[0]
    });
  } catch (error) {
    console.error("회원가입 에러:", error);
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