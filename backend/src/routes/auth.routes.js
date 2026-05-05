// 이메일 인증을 위한 라우터 설정
const express = require("express");
const authController = require("../controllers/auth.controller");

const router = express.Router();

//이메일 인증 코드 전송 및 검증 엔드포인트
router.post("/email/send-code", authController.sendCode); // 이메일 인증 코드 전송
router.post("/email/verify-code", authController.verifyCode); // 이메일 인증 코드 검증

module.exports = router;