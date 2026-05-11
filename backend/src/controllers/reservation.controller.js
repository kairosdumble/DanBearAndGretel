const pool = require('../db/pool');
const Reservation = require('../models/reservation.model');

exports.createReservation = async (req, res) => {
    try {
        // 1. 유효성 검사
        const validation = Reservation.validate(req.body);
        
        if (!validation.isValid) {
            // 검사 실패 시, DB 작업을 하지 않고 바로 클라이언트에게 에러 메시지
            return res.status(400).json({ message: validation.message });
        }

        // 2. 검사 통과 시 DB 저장
        const { departure, destination, departure_time, price, user_id } = req.body;
        
        const query = `
            INSERT INTO reservations (departure, destination, departure_time, price, user_id)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING *;
        `;
        const values = [departure, destination, departure_time, price, user_id];
        
        const result = await pool.query(query, values);
        
        res.status(201).json({
            message: "예약이 성공적으로 완료되었습니다!",
            reservation: result.rows[0]
        });
        
    } catch (error) {
        console.error("예약 생성 중 오류:", error);
        res.status(500).json({ message: "서버 오류로 예약을 처리할 수 없습니다." });
    }
};