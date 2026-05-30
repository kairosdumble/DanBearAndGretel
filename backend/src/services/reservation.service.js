const pool = require("../db/pool");

//
const reservationService = {
    // [CREATE] 새 예약 등록
    createReservation: async (userId, reservationData) => {
        const { departure_location, destination_location, departure_time } = reservationData;
        const query = `
            INSERT INTO reservations (
                user_id,
                departure_location,
                destination_location,
                departure_time,
                status
            )
            VALUES ($1, $2, $3, $4, 'READY')
            RETURNING *;
        `;
        const values = [userId, departure_location, destination_location, departure_time];
        const { rows } = await pool.query(query, values);
        return rows[0];
    },
    // 예약당 참여자 등록
    registerReservation: async (userId, reservationData) => {
        const { reservation_id, user_id} = reservationData;
        const query = `
            INSERT INTO reservation_bluetooth_participants (reservation_id, user_id)
            VALUES ($1, $2)
            RETURNING *;
        `;
        const values = [reservation_id, user_id];
        const { rows } = await pool.query(query, values);
        return rows[0];
    },

    // [READ] 사용자별 예약 목록 조회
    getReservationsByUserId: async (userId) => {
        const query = 'SELECT * FROM reservations WHERE user_id = $1 ORDER BY departure_time ASC';
        const { rows } = await pool.query(query, [userId]);
        return rows;
    },

    // DB에 있는 모든 예약 행 (필터 없음)
    getAllReservations: async () => {
        const query =
            'SELECT * FROM reservations ORDER BY departure_time ASC NULLS LAST, id ASC';
        const { rows } = await pool.query(query);
        return rows;
    },

    // [UPDATE] 기존 예약 수정 (기존 putReservation 대응)
    updateReservation: async (reservationId, userId, updateData) => {
        const { departure_location, destination_location, departure_time } = updateData;
        const query = `
            UPDATE reservations 
            SET departure_location = $1, destination_location = $2, departure_time = $3 
            WHERE id = $4 AND user_id = $5
            RETURNING *;
        `;
        const values = [departure_location, destination_location, departure_time, reservationId, userId];
        const { rows } = await pool.query(query, values);
        return rows[0];
    }
};

module.exports = reservationService;