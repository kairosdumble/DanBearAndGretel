const pool = require("../db/pool");

// 추가
async function confirm(reservationId, userId) {
    const query = `
        INSERT INTO reservation_participants (reservation_id, user_id)
        VALUES ($1, $2)
        ON CONFLICT (reservation_id, user_id) DO NOTHING
        RETURNING *;
    `;
    const values = [reservationId, userId];
    const { rows } = await pool.query(query, values);
    return rows[0] ?? { reservation_id: reservationId, user_id: userId };
}

//삭제
async function cancel(reservationId, userId) {
    const query = `
        DELETE FROM reservation_participants
        WHERE reservation_id = $1 AND user_id = $2
        RETURNING *;
    `;
    const values = [reservationId, userId];
    const { rows } = await pool.query(query, values);
    return rows[0];
}

//검색
async function get(reservationId,userId){
    const query = `
        SELECT * FROM reservation_participants 
        WHERE reservation_id = $1 AND user_id = $2;
    `;
    const values = [reservationId, userId];
    const { rows } = await pool.query(query, values);
    
    // 검색된 결과가 있으면 해당 객체를, 없으면 undefined를 반환합니다.
    return rows[0];
}

module.exports = { confirm, cancel, get };
