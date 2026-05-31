const pool = require("../db/pool");

function hasCoordinate(value) {
    const number = Number(value);
    return Number.isFinite(number);
}

const distanceExpression = `
    6371000 * 2 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(departure_lat - $1) / 2), 2) +
            COS(RADIANS($1)) *
            COS(RADIANS(departure_lat)) *
            POWER(SIN(RADIANS(departure_lng - $2) / 2), 2)
        )
    )
`;

const reservationService = {
    createReservation: async (userId, reservationData) => {
        const {
            departure_location,
            destination_location,
            departure_time,
            departure_lat,
            departure_lng,
            destination_lat,
            destination_lng,
        } = reservationData;

        const query = `
            INSERT INTO reservations (
                user_id,
                departure_location,
                destination_location,
                departure_lat,
                departure_lng,
                destination_lat,
                destination_lng,
                departure_time,
                status
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'READY')
            RETURNING *;
        `;
        const values = [
            userId,
            departure_location,
            destination_location,
            departure_lat,
            departure_lng,
            destination_lat,
            destination_lng,
            departure_time,
        ];
        const { rows } = await pool.query(query, values);
        return rows[0];
    },

    registerReservation: async (_userId, reservationData) => {
        const { reservation_id, user_id } = reservationData;
        const query = `
            INSERT INTO reservation_bluetooth_participants (reservation_id, user_id)
            VALUES ($1, $2)
            RETURNING *;
        `;
        const values = [reservation_id, user_id];
        const { rows } = await pool.query(query, values);
        return rows[0];
    },

    getReservationsByUserId: async (userId) => {
        const query = "SELECT * FROM reservations WHERE user_id = $1 ORDER BY departure_time ASC";
        const { rows } = await pool.query(query, [userId]);
        return rows;
    },

    getAllReservations: async ({ lat, lng } = {}) => {
        if (hasCoordinate(lat) && hasCoordinate(lng)) {
            const query = `
                SELECT
                    *,
                    ROUND((${distanceExpression})::numeric)::integer AS distance_meters
                FROM reservations
                WHERE departure_lat IS NOT NULL
                  AND departure_lng IS NOT NULL
                ORDER BY distance_meters ASC, departure_time ASC NULLS LAST, id ASC;
            `;
            const { rows } = await pool.query(query, [Number(lat), Number(lng)]);
            return rows;
        }

        const query =
            "SELECT *, NULL::integer AS distance_meters FROM reservations ORDER BY departure_time ASC NULLS LAST, id ASC";
        const { rows } = await pool.query(query);
        return rows;
    },

    updateReservation: async (reservationId, userId, updateData) => {
        const {
            departure_location,
            destination_location,
            departure_time,
            departure_lat,
            departure_lng,
            destination_lat,
            destination_lng,
        } = updateData;
        const query = `
            UPDATE reservations
            SET
                departure_location = $1,
                destination_location = $2,
                departure_time = $3,
                departure_lat = $4,
                departure_lng = $5,
                destination_lat = $6,
                destination_lng = $7
            WHERE id = $8 AND user_id = $9
            RETURNING *;
        `;
        const values = [
            departure_location,
            destination_location,
            departure_time,
            departure_lat,
            departure_lng,
            destination_lat,
            destination_lng,
            reservationId,
            userId,
        ];
        const { rows } = await pool.query(query, values);
        return rows[0];
    },
};

module.exports = reservationService;
