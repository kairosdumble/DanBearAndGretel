const verificationService = require("../services/emailVerification.service");
const pool = require("../db/pool"); // DB 연결
const { use } = require("react");

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
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message:"이름, 이메일, 비밀번호를 모두 입력해주세요."});
    }
    const query = "INSERT INTO users (name, email, password) VALUES ($1, $2, $3) RETRUNING *";
    const values = [name, email, password];

    const newUser = await pool.query(query, values);

    res.status(201).json({
      message: "회원가입이 완료되었습니다.",
      user: {
        id: newUser.rows[0].id,
        email: newUser.rows[0].emil
      }
    });
  } catch (error) {
    console.error("회원가입 에러:", error);
    res.status(500).json({ message: "서버 내부 에러가 발생했습니다."});
  }
}

async function login(req, res) {
  try {
    const { email, password} = req.body;

    const user = await pool.query("SELECT * FROM users WHERE email = $1", [email]);

    if (user.rows[0].password_hash !== password) {
      return res.status(401).json({ message: "비밀번호가 일치하지 않습니다."});
    }
    res.status(200).json({
      message: "로그인 성공!",
      user: { id: user.rows[0].id, name: user.rows[0].name, email: user.rows[0].email }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "로그인 중 에러 발생"});
  }
}

module.exports = {
  sendCode,
  verifyCode,
  signup,
  login,
};