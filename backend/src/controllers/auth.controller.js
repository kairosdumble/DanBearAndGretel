const verificationService = require("../services/emailVerification.service");

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

module.exports = {
  sendCode,
  verifyCode,
};