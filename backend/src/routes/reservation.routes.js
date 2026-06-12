const express = require("express");
const router = express.Router();
const reservationController = require("../controllers/reservation.controller");
const { authenticate } = require("../middleware/auth.middleware");

router.use(authenticate);

router.post("/create", reservationController.createReservation); // 새 예약 생성
router.get("/all", reservationController.getAllReservations); // 모든 DB 예약들 정보 받아오기
router.get("/active-match", reservationController.getActiveMatchedReservation); 
router.get("/:id/settlement", reservationController.getSettlementDetails);
router.get("/:id", reservationController.getReservationById);
router.put("/put/:id", reservationController.putReservation); // 

module.exports = router;
