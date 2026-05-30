const pool = require("../db/pool");

// 추가
async function confirm(reservationId, userId) {
    const values = [reservationId, userId];
    const client = await pool.connect();

    try {
        await client.query("BEGIN");

        const inserted = await client.query(
            `
            INSERT INTO reservation_bluetooth_participants (reservation_id, user_id)
            SELECT $1, $2
            WHERE EXISTS (SELECT 1 FROM reservations WHERE id = $1)
            ON CONFLICT (reservation_id, user_id) DO NOTHING
            RETURNING *;
            `,
            values,
        );

        const participant =
            inserted.rows[0] ??
            (
                await client.query(
                    `
                    SELECT *
                    FROM reservation_bluetooth_participants
                    WHERE reservation_id = $1 AND user_id = $2;
                    `,
                    values,
                )
            ).rows[0];

        if (!participant) {
            await client.query("ROLLBACK");
            return null;
        }

        await client.query(
            `
            UPDATE reservations
            SET status = 'RUNNING'
            WHERE id = $1
              AND status = 'READY'
              AND EXISTS (
                SELECT 1
                FROM reservation_bluetooth_participants
                WHERE reservation_id = $1
              );
            `,
            [reservationId],
        );

        await client.query("COMMIT");
        return participant;
    } catch (error) {
        try {
            await client.query("ROLLBACK");
        } catch {
            /* 연결 오류 시 무시 */
        }
        throw error;
    } finally {
        client.release();
    }
}

//삭제
async function cancel(reservationId, userId) {
    const query = `
        DELETE FROM reservation_bluetooth_participants
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
        SELECT * FROM reservation_bluetooth_participants
        WHERE reservation_id = $1 AND user_id = $2;
    `;
    const values = [reservationId, userId];
    const { rows } = await pool.query(query, values);
    
    // 검색된 결과가 있으면 해당 객체를, 없으면 undefined를 반환합니다.
    return rows[0];
}

module.exports = { confirm, cancel, get };
