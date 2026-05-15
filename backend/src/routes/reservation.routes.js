const express = require("express");
const router = express.Router();
const reservationController = require("../controllers/reservationController");
const { authenticate } = require("../middleware/auth.middleware");

// app.use("/api/reservations", router) → POST/GET /api/reservations, PUT /api/reservations/:id
router.use(authenticate);

router.post("/create", reservationController.createReservation); // 예약 생성
router.get("/get", reservationController.getReservation); // 특정 예약 조회
router.get("/all", reservationController.getAllReservations); // 현재 DB에 존재하는 모든 예약 조회
router.put("/put/:id", reservationController.putReservation); // 특정 예약 수정

module.exports = router;