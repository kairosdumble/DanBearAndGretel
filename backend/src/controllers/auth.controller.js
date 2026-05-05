const verificationService = require("../services/emailVerification.service");

// 이메일 전송 컨트롤러
async function sendCode(req, res) { // req: 요청 객체, res:응답 객체
  try {
    const { email } = req.body;
    const result = await verificationService.sendCode(email);
    res.status(200).json(result);
  } catch (error) {
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
    res.status(error.status || 500).json({ message: error.message });
  }
}

module.exports = {
  sendCode,
  verifyCode,
};