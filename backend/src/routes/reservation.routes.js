const express = require('express');
const router = express.Router();
const reservationController = require('../controllers/reservationController');

// 사용자가 POST 방식으로 /api/reservations 주소에 접근하면 실행됨
router.post('/', reservationController.createReservation);

router.get('/', reservationController.getReservation);

module.exports = router;