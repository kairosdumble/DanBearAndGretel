const express = require("express");
const router = express.Router();
const SettleController = require("../controllers/settle.controller");
const { authenticate } = require("../middleware/auth.middleware");

router.use(authenticate);

router.post("/:reservationId/total_upload", SettleController.createSettle); // 정산 생성

module.exports = router;