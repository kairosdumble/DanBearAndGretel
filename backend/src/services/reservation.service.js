const pool = require("../db/pool");

function hasCoordinate(value) {
    const number = Number(value);
    return Number.isFinite(number);
}

// 출발지로부터 도착지까지의 거리표현
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

const departureTimeSelect = "to_char(departure_time, 'YYYY-MM-DD\"T\"HH24:MI:SS') AS departure_time";

const participantCountSelect = `
    COALESCE(
        (SELECT COUNT(*)::integer
         FROM reservation_chat_participants rcp
         WHERE rcp.reservation_id = reservations.id),
        0
    ) AS participant_count`;

function myActiveMatchSelect(userIdPlaceholder) {
    return `
        (
            COALESCE(reservations.status, 'READY') = 'RUNNING'
            AND (
                reservations.user_id = ${userIdPlaceholder}
                OR EXISTS (
                    SELECT 1
                    FROM reservation_bluetooth_participants rbp_me
                    WHERE rbp_me.reservation_id = reservations.id
                      AND rbp_me.user_id = ${userIdPlaceholder}
                      AND rbp_me.confirmed_at IS NOT NULL
                )
            )
        ) AS is_my_active_match`;
}

function haversineMeters(fromLat, fromLng, toLat, toLng) {
    const values = [fromLat, fromLng, toLat, toLng].map(Number);
    if (!values.every(Number.isFinite)) {
        return 0;
    }
    const [lat1, lng1, lat2, lng2] = values.map((value) => value * Math.PI / 180);
    const dLat = lat2 - lat1;
    const dLng = lng2 - lng1;
    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
    return Math.round(6371000 * 2 * Math.asin(Math.min(1, Math.sqrt(a))));
}

function normalizeKoreanCoordinate(lat, lng) {
    const parsedLat = Number(lat);
    const parsedLng = Number(lng);
    if (!Number.isFinite(parsedLat) || !Number.isFinite(parsedLng)) {
        return { lat: null, lng: null };
    }

    const looksValid = parsedLat >= 30 && parsedLat <= 45 && parsedLng >= 120 && parsedLng <= 140;
    if (looksValid) {
        return { lat: parsedLat, lng: parsedLng };
    }

    const looksSwapped = parsedLng >= 30 && parsedLng <= 45 && parsedLat >= 120 && parsedLat <= 140;
    if (looksSwapped) {
        return { lat: parsedLng, lng: parsedLat };
    }

    return { lat: parsedLat, lng: parsedLng };
}

function isPlausibleDropoffDistance(distanceMeters, routeDistanceMeters) {
    if (!Number.isFinite(distanceMeters) || distanceMeters <= 0) {
        return false;
    }
    if (!Number.isFinite(routeDistanceMeters) || routeDistanceMeters <= 0) {
        return distanceMeters < 100000;
    }
    return distanceMeters <= Math.max(routeDistanceMeters + 1000, routeDistanceMeters * 1.5);
}

async function ensureSettlementColumns() {
    await pool.query(`
        ALTER TABLE reservations
        ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'READY';
    `);
    await pool.query(`
        ALTER TABLE reservation_bluetooth_participants
        ADD COLUMN IF NOT EXISTS dropoff_completed BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS distance BIGINT NULL,
        ADD COLUMN IF NOT EXISTS fare BIGINT NULL,
        ADD COLUMN IF NOT EXISTS destination_location TEXT NULL,
        ADD COLUMN IF NOT EXISTS destination_lat DOUBLE PRECISION NULL,
        ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION NULL,
        ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ NULL;
    `);
    await pool.query(`
        CREATE UNIQUE INDEX IF NOT EXISTS idx_reservation_bluetooth_participants_unique
        ON reservation_bluetooth_participants (reservation_id, user_id);
    `);
}

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

    getAllReservations: async ({ lat, lng, destinationLat, destinationLng, userId } = {}) => {
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
                        ) AS detour_meters,
                        ${participantCountSelect},
                        ${myActiveMatchSelect("$5")}
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
                    userId,
                ]);
                return rows;
            }

            const query = `
                SELECT
                    *,
                    ${departureTimeSelect},
                    ROUND((${distanceFromOrigin})::numeric)::integer AS distance_meters,
                    NULL::integer AS detour_meters,
                    ${participantCountSelect},
                    ${myActiveMatchSelect("$3")}
                FROM reservations
                WHERE departure_lat IS NOT NULL
                  AND departure_lng IS NOT NULL
                ORDER BY distance_meters ASC, reservations.departure_time ASC NULLS LAST, id ASC;
            `;
            const { rows } = await pool.query(query, [Number(lat), Number(lng), userId]);
            return rows;
        }

        const query =
            `SELECT *, ${departureTimeSelect}, NULL::integer AS distance_meters, NULL::integer AS detour_meters, ${participantCountSelect}, ${myActiveMatchSelect("$1")} FROM reservations ORDER BY reservations.departure_time ASC NULLS LAST, id ASC`;
        const { rows } = await pool.query(query, [userId]);
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

    deleteReservation: async (reservationId, userId) => {
        await ensureSettlementColumns();

        const reservationResult = await pool.query(
            `SELECT id, user_id, status FROM reservations WHERE id = $1`,
            [reservationId],
        );
        const reservation = reservationResult.rows[0];
        if (!reservation) {
            return { error: "NOT_FOUND" };
        }
        if (String(reservation.user_id) !== String(userId)) {
            return { error: "NOT_OWNER" };
        }

        const status = String(reservation.status || "READY").toUpperCase();
        if (status !== "READY" && status !== "MATCHED") {
            return { error: "NOT_DELETABLE" };
        }

        await pool.query(
            `
            UPDATE reservation_proximity_requests
            SET status = 'CANCELLED'
            WHERE reservation_id = $1 AND status = 'PENDING';
            `,
            [reservationId],
        );

        const deleteResult = await pool.query(
            `
            DELETE FROM reservations
            WHERE id = $1 AND user_id = $2
            RETURNING id;
            `,
            [reservationId, userId],
        );

        if (!deleteResult.rows[0]) {
            return { error: "NOT_FOUND" };
        }

        return { deleted: true, id: deleteResult.rows[0].id };
    },

    getReservationById: async (reservationId) => {
        const query = `
            SELECT *, ${departureTimeSelect}, ${participantCountSelect}
            FROM reservations
            WHERE id = $1
        `;
        const { rows } = await pool.query(query, [reservationId]);
        return rows[0];
    },

    getActiveMatchedReservation: async (userId) => {
        await ensureSettlementColumns();

        const query = `
            SELECT
                r.*,
                to_char(r.departure_time, 'YYYY-MM-DD"T"HH24:MI:SS') AS departure_time,
                (r.user_id = $1) AS is_creator,
                rbp_me.destination_location AS my_destination_location,
                rbp_me.destination_lat AS my_destination_lat,
                rbp_me.destination_lng AS my_destination_lng,
                rbp_me.settlement_paid AS my_settlement_paid,
                rbp_me.confirmed_at AS my_confirmed_at,
                COALESCE(rbp_me.dropoff_completed, FALSE) AS my_dropoff_completed,
                match_meta.latest_confirmed_at
            FROM reservations r
            LEFT JOIN reservation_bluetooth_participants rbp_me
              ON rbp_me.reservation_id = r.id
             AND rbp_me.user_id = $1
            LEFT JOIN LATERAL (
                SELECT MAX(rbp_any.confirmed_at) AS latest_confirmed_at
                FROM reservation_bluetooth_participants rbp_any
                WHERE rbp_any.reservation_id = r.id
            ) match_meta ON TRUE
            WHERE (
                r.user_id = $1
                OR rbp_me.user_id IS NOT NULL
            )
              AND COALESCE(r.status, 'READY') = 'RUNNING'
              AND (
                (
                    r.user_id = $1
                    AND match_meta.latest_confirmed_at IS NOT NULL
                )
                OR (
                    rbp_me.user_id IS NOT NULL
                    AND rbp_me.confirmed_at IS NOT NULL
                    AND COALESCE(rbp_me.settlement_paid, FALSE) = FALSE
                )
              )
            ORDER BY
                COALESCE(
                    rbp_me.confirmed_at,
                    match_meta.latest_confirmed_at
                ) DESC NULLS LAST,
                r.id DESC,
                r.departure_time DESC NULLS LAST
            LIMIT 1
        `;
        const { rows } = await pool.query(query, [userId]);
        return rows[0] || null;
    },

    getSettlementDetails: async (reservationId, currentUserId) => {
        await ensureSettlementColumns();

        const reservationQuery = `
            SELECT
                r.*,
                ${departureTimeSelect},
                u.id AS creator_id,
                u.name AS creator_name,
                u.email AS creator_email
            FROM reservations r
            JOIN users u ON u.id = r.user_id
            WHERE r.id = $1
        `;
        const reservationResult = await pool.query(reservationQuery, [reservationId]);
        const reservation = reservationResult.rows[0];
        if (!reservation) {
            return null;
        }

        const reservationDeparture = normalizeKoreanCoordinate(
            reservation.departure_lat,
            reservation.departure_lng,
        );
        const reservationDestination = normalizeKoreanCoordinate(
            reservation.destination_lat,
            reservation.destination_lng,
        );
        const routeDistanceMeters = haversineMeters(
            reservationDeparture.lat,
            reservationDeparture.lng,
            reservationDestination.lat,
            reservationDestination.lng,
        );

        const participantQuery = `
            SELECT
                u.id,
                u.name,
                u.email,
                rbp.distance,
                rbp.fare,
                rbp.dropoff_completed,
                rbp.destination_location,
                rbp.destination_lat,
                rbp.destination_lng
            FROM reservation_bluetooth_participants rbp
            JOIN users u ON u.id = rbp.user_id
            WHERE rbp.reservation_id = $1
            ORDER BY u.id ASC
        `;
        const participantResult = await pool.query(participantQuery, [reservationId]);

        const participantsById = new Map();
        participantsById.set(String(reservation.creator_id), {
            id: String(reservation.creator_id),
            name: reservation.creator_name,
            email: reservation.creator_email,
            is_creator: true,
            destination_location: reservation.destination_location,
            dropoff_distance_meters: routeDistanceMeters,
            fare: null,
            dropoff_completed: false,
        });

        for (const row of participantResult.rows) {
            const savedDistance =
                row.distance == null ? null : Number(row.distance);
            const participantDestination = normalizeKoreanCoordinate(
                row.destination_lat,
                row.destination_lng,
            );
            const destinationDistance = haversineMeters(
                reservationDeparture.lat,
                reservationDeparture.lng,
                participantDestination.lat,
                participantDestination.lng,
            );
            const computedDistance = isPlausibleDropoffDistance(
                destinationDistance,
                routeDistanceMeters,
            )
                ? destinationDistance
                : null;
            const savedPlausibleDistance = isPlausibleDropoffDistance(
                savedDistance,
                routeDistanceMeters,
            )
                ? savedDistance
                : null;
            const hasCompletedDropoff = row.dropoff_completed === true;
            const dropoffDistance = hasCompletedDropoff
                ? (savedPlausibleDistance ?? computedDistance ?? routeDistanceMeters)
                : routeDistanceMeters;
            participantsById.set(String(row.id), {
                id: String(row.id),
                name: row.name,
                email: row.email,
                is_creator: String(row.id) === String(reservation.creator_id),
                destination_location: row.destination_location || reservation.destination_location,
                dropoff_distance_meters: dropoffDistance,
                fare: row.fare == null ? null : Number(row.fare),
                dropoff_completed: row.dropoff_completed === true,
            });
        }

        return {
            current_user_id: String(currentUserId),
            reservation: {
                id: reservation.id,
                creator_id: String(reservation.creator_id),
                departure_location: reservation.departure_location,
                destination_location: reservation.destination_location,
                departure_lat: reservation.departure_lat,
                departure_lng: reservation.departure_lng,
                destination_lat: reservation.destination_lat,
                destination_lng: reservation.destination_lng,
                departure_time: reservation.departure_time,
                route_distance_meters: routeDistanceMeters,
            },
            participants: Array.from(participantsById.values()),
        };
    },

    recordParticipantDropoff: async (reservationId, userId, destinationOverride = {}) => {
        await ensureSettlementColumns();

        const reservationResult = await pool.query(
            `
            SELECT *
            FROM reservations
            WHERE id = $1
            `,
            [reservationId],
        );
        const reservation = reservationResult.rows[0];
        if (!reservation) {
            return { error: "NOT_FOUND" };
        }
        if (String(reservation.user_id) === String(userId)) {
            return { error: "CREATOR" };
        }
        if (String(reservation.status || "READY").toUpperCase() !== "RUNNING") {
            return { error: "NOT_RUNNING" };
        }

        const participantResult = await pool.query(
            `
            SELECT *
            FROM reservation_bluetooth_participants
            WHERE reservation_id = $1 AND user_id = $2
            `,
            [reservationId, userId],
        );
        const participant = participantResult.rows[0];
        if (!participant || participant.confirmed_at == null) {
            return { error: "NOT_PARTICIPANT" };
        }
        if (participant.dropoff_completed === true) {
            return { error: "ALREADY_COMPLETED" };
        }

        const destinationLocation =
            typeof destinationOverride.destination_location === "string"
                ? destinationOverride.destination_location.trim()
                : participant.destination_location;
        const destinationLat =
            destinationOverride.destination_lat ?? participant.destination_lat;
        const destinationLng =
            destinationOverride.destination_lng ?? participant.destination_lng;

        const reservationDeparture = normalizeKoreanCoordinate(
            reservation.departure_lat,
            reservation.departure_lng,
        );
        const participantDestination = normalizeKoreanCoordinate(
            destinationLat,
            destinationLng,
        );
        const routeDistanceMeters = haversineMeters(
            reservationDeparture.lat,
            reservationDeparture.lng,
            normalizeKoreanCoordinate(
                reservation.destination_lat,
                reservation.destination_lng,
            ).lat,
            normalizeKoreanCoordinate(
                reservation.destination_lat,
                reservation.destination_lng,
            ).lng,
        );
        const dropoffDistance = haversineMeters(
            reservationDeparture.lat,
            reservationDeparture.lng,
            participantDestination.lat,
            participantDestination.lng,
        );

        if (
            !Number.isFinite(participantDestination.lat) ||
            !Number.isFinite(participantDestination.lng)
        ) {
            return { error: "NO_DESTINATION" };
        }

        const safeDistance = isPlausibleDropoffDistance(
            dropoffDistance,
            routeDistanceMeters,
        )
            ? Math.round(dropoffDistance)
            : Math.round(routeDistanceMeters);

        const updateResult = await pool.query(
            `
            UPDATE reservation_bluetooth_participants
            SET
                dropoff_completed = TRUE,
                distance = $3,
                destination_location = COALESCE($4, destination_location),
                destination_lat = COALESCE($5, destination_lat),
                destination_lng = COALESCE($6, destination_lng)
            WHERE reservation_id = $1 AND user_id = $2
            RETURNING *;
            `,
            [
                reservationId,
                userId,
                safeDistance,
                destinationLocation || null,
                participantDestination.lat,
                participantDestination.lng,
            ],
        );

        return { participant: updateResult.rows[0], distance_meters: safeDistance };
    },
};

module.exports = reservationService;
