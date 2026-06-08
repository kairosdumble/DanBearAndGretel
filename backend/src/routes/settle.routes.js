const express = require("express");
const router = express.Router();
const settleController = require("../controllers/settle.controller");
const { authenticate } = require("../middleware/auth.middleware");

router.use(authenticate);

router.get("/notification", settleController.getSettlementNotification);
router.get("/:reservationId/status", settleController.getSettlementStatus);
router.post("/:reservationId/request", settleController.requestSettlement);
router.post("/:reservationId/transfer", settleController.transferSettlement);

module.exports = router;
