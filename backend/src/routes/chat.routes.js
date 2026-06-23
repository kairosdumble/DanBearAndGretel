const express = require("express");
const router = express.Router();
const chatController = require("../controllers/chat.controller");
const { authenticate } = require("../middleware/auth.middleware");

router.use(authenticate);

router.get(
  "/reservations/:reservationId/messages",
  chatController.getReservationMessages,
);
router.get(
  "/reservations/:reservationId/messages/stream",
  chatController.streamReservationMessages,
);
router.post(
  "/reservations/:reservationId/messages",
  chatController.createReservationMessage,
);

module.exports = router;
