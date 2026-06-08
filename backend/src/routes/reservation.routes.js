const express = require("express");
const router = express.Router();
const reservationController = require("../controllers/reservation.controller");
const { authenticate } = require("../middleware/auth.middleware");

router.use(authenticate);

router.post("/create", reservationController.createReservation);
router.get("/get", reservationController.getReservation);
router.get("/all", reservationController.getAllReservations);
router.get("/active-match", reservationController.getActiveMatchedReservation);
router.get("/:id/settlement", reservationController.getSettlementDetails);
router.get("/:id", reservationController.getReservationById);
router.put("/put/:id", reservationController.putReservation);

router.post(
    "/proximity/:reservation_id/confirm",
    reservationController.confirmProximityMatch,
);
router.post(
    "/proximity/:reservation_id/cancel",
    reservationController.cancelProximityMatch,
);
router.get(
    "/proximity/:reservation_id/get",
    reservationController.getProximityMatch,
);

module.exports = router;
