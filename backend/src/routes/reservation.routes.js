const express = require("express");
const router = express.Router();
const reservationController = require("../controllers/reservation.controller");
const { authenticate } = require("../middleware/auth.middleware");

// app.use("/api/reservations", router) → POST/GET /api/reservations, PUT /api/reservations/:id
router.use(authenticate);
router.post("/create", reservationController.createReservation);

//예약별
router.post("/create", reservationController.createReservation); // 예약 생성
router.get("/get", reservationController.getReservation); // 특정 예약 조회
router.get("/all", reservationController.getAllReservations); // 현재 DB에 존재하는 모든 예약 조회
router.get("/:id", reservationController.getReservationById); // 단일 예약 조회
router.put("/put/:id", reservationController.putReservation); // 특정 예약 수정

//사용자별
router.post("/proximity/:reservation_id/confirm", reservationController.confirmProximityMatch);// 예약 확정자로 추가
router.post("/proximity/:reservation_id/cancel", reservationController.cancelProximityMatch); // 예약 확정자에서 삭제
router.get("/proximity/:reservation_id/get",reservationController.getProximityMatch);

module.exports = router;
