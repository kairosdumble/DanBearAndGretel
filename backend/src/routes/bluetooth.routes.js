const express = require("express");
const bluetoothController = require("../controllers/bluetooth.controller");
const { authenticate } = require("../middleware/auth.middleware");
const router = express.Router();

router.use(authenticate);

// BLE 근접 매칭
router.post("/confirm", bluetoothController.confirmGroupMatch); // 방장: 선택 유저 모임 확정 요청
router.post("/proximity/:reservation_id/presence",bluetoothController.updateProximityPresence);// 
router.get("/proximity/:reservation_id/nearby",bluetoothController.getProximityNearbyUsers);
router.get("/proximity/:reservation_id/approval-status",bluetoothController.getProximityApprovalStatus);

//사용자별
router.post("/proximity/:reservation_id/confirm", bluetoothController.confirmProximityMatch);// 예약 확정자로 추가
router.post("/proximity/:reservation_id/cancel", bluetoothController.cancelProximityMatch); // 예약 확정자에서 삭제
router.get("/proximity/:reservation_id/get",bluetoothController.getProximityMatch);

module.exports = router;