// 이메일 인증을 위한 라우터 설정
const express = require("express");
const router = express.Router();
const authController = require("../controllers/auth.controller");
const reservationController = require("../controllers/reservationController");

// 회원가입 및 로그인 엔드포인트
router.post("/signup", authController.signup);
router.post("/login", authController.login);

//이메일 인증 코드 전송 및 검증 엔드포인트
router.post("/email/send-code", authController.sendCode); // 이메일 인증 코드 전송
router.post("/email/verify-code", authController.verifyCode); // 이메일 인증 코드 검증

//새 예약 정보 엔드포인트
router.post("/reservations", reservationController.createReservation); // 예약 정보 생성
router.get("/reservations", reservationController.getReservation); // 예약 정보 조회
router.put("/reservations/:id", reservationController.putReservation);

module.exports = router;