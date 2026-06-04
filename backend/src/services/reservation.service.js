const pool = require("../db/pool");

function hasCoordinate(value) {
    const number = Number(value);
    return Number.isFinite(number);
}

function distanceExpression(fromLat, fromLng, toLat, toLng) {
    return `
    6371000 * 2 * ASIN(
        LEAST(
            1,
            SQRT(
                POWER(SIN(RADIANS(${toLat} - ${fromLat}) / 2), 2) +
                COS(RADIANS(${fromLat})) *
                COS(RADIANS(${toLat})) *
                POWER(SIN(RADIANS(${toLng} - ${fromLng}) / 2), 2)
            )
        )
    )
`;
}

const departureTimeSelect =
    "to_char(departure_time, 'YYYY-MM-DD\"T\"HH24:MI:SS') AS departure_time";

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
                departure_time
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
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
        const query = `
            SELECT *, ${departureTimeSelect}
            FROM reservations
            WHERE user_id = $1
            ORDER BY reservations.departure_time ASC
        `;
        const { rows } = await pool.query(query, [userId]);
        return rows;
    },

    getAllReservations: async ({ lat, lng, destinationLat, destinationLng } = {}) => {
        if (hasCoordinate(lat) && hasCoordinate(lng)) {
            const distanceFromOrigin = distanceExpression(
                "$1",
                "$2",
                "departure_lat",
                "departure_lng",
            );

            if (hasCoordinate(destinationLat) && hasCoordinate(destinationLng)) {
                const candidateToDestination = distanceExpression(
                    "departure_lat",
                    "departure_lng",
                    "$3",
                    "$4",
                );
                const originToDestination = distanceExpression("$1", "$2", "$3", "$4");
                const query = `
                    SELECT
                        *,
                        ${departureTimeSelect},
                        ROUND((${distanceFromOrigin})::numeric)::integer AS distance_meters,
                        GREATEST(
                            0,
                            ROUND((
                                (${distanceFromOrigin}) +
                                (${candidateToDestination}) -
                                (${originToDestination})
                            )::numeric)::integer
                        ) AS detour_meters
                    FROM reservations
                    WHERE departure_lat IS NOT NULL
                      AND departure_lng IS NOT NULL
                    ORDER BY detour_meters ASC, distance_meters ASC, reservations.departure_time ASC NULLS LAST, id ASC;
                `;
                const { rows } = await pool.query(query, [
                    Number(lat),
                    Number(lng),
                    Number(destinationLat),
                    Number(destinationLng),
                ]);
                return rows;
            }

            const query = `
                SELECT
                    *,
                    ${departureTimeSelect},
                    ROUND((${distanceFromOrigin})::numeric)::integer AS distance_meters,
                    NULL::integer AS detour_meters
                FROM reservations
                WHERE departure_lat IS NOT NULL
                  AND departure_lng IS NOT NULL
                ORDER BY distance_meters ASC, reservations.departure_time ASC NULLS LAST, id ASC;
            `;
            const { rows } = await pool.query(query, [Number(lat), Number(lng)]);
            return rows;
        }

        const query =
            `SELECT *, ${departureTimeSelect}, NULL::integer AS distance_meters, NULL::integer AS detour_meters FROM reservations ORDER BY reservations.departure_time ASC NULLS LAST, id ASC`;
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
