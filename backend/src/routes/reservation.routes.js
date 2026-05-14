const express = require("express");
const router = express.Router();
const reservationController = require("../controllers/reservationController");
const { authenticate } = require("../middleware/auth.middleware");

// app.use("/api/reservations", router) → POST/GET /api/reservations, PUT /api/reservations/:id
router.use(authenticate);

router.post("/create", reservationController.createReservation);
router.get("/get", reservationController.getReservation);
router.put("/put/:id", reservationController.putReservation);

module.exports = router;