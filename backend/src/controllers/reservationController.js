
const verificationService = require("../services/emailVerification.service");
const pool = require("../db/pool");

const reservationService = require('../services/reservation.service');

    // POST / API 예약 등록
async function createReservation(req, res) {
    try {
        const userId = req.user.id; // 인증 미들웨어에서 추출한 ID
        const newReservation = await reservationService.createReservation(userId, req.body);
        res.status(201).json(newReservation);
        } catch (error) {
            res.status(500).json({ message: "예약 등록 중 오류 발생", error: error.message });
        }
}

    // GET / API 예약 목록 조회 (기존 getReservation 보완)
async function getReservation(req, res) {
        try {
            const userId = req.user.id;
            const reservations = await reservationService.getReservationsByUserId(userId);
            res.status(200).json(reservations);
        } catch (error) {
            res.status(500).json({ message: "조회 중 오류 발생", error: error.message });
        }
}

    // PUT /:id API 예약 수정 (기존 putReservation 보완)
async function putReservation(req, res) {
    try {
        const { id } = req.params; // 수정할 예약의 PK
        const userId = req.user.id;
        const updated = await reservationService.updateReservation(id, userId, req.body);
        
        if (!updated) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없거나 권한이 없습니다." });
        }
        res.status(200).json(updated);
    } catch (error) {
        res.status(500).json({ message: "수정 중 오류 발생", error: error.message });
    }
}

module.exports = { createReservation, getReservation, putReservation };