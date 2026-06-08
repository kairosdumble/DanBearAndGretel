const pool = require("../db/pool");

async function ensureProximitySchema() {
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
        ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION NULL;
    `);
    await pool.query(`
        CREATE UNIQUE INDEX IF NOT EXISTS idx_reservation_bluetooth_participants_unique
        ON reservation_bluetooth_participants (reservation_id, user_id);
    `);
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

async function confirm(reservationId, userId, participantDestination = {}) {
    await ensureProximitySchema();

    const destinationLocation =
        typeof participantDestination.destination_location === "string"
            ? participantDestination.destination_location.trim()
            : null;
    const destination = normalizeKoreanCoordinate(
        participantDestination.destination_lat,
        participantDestination.destination_lng,
    );
    const values = [
        reservationId,
        userId,
        destinationLocation || null,
        destination.lat,
        destination.lng,
    ];
    const client = await pool.connect();

    try {
        await client.query("BEGIN");

        const inserted = await client.query(
            `
            INSERT INTO reservation_bluetooth_participants (
                reservation_id,
                user_id,
                destination_location,
                destination_lat,
                destination_lng
            )
            SELECT $1, $2, $3, $4, $5
            WHERE EXISTS (SELECT 1 FROM reservations WHERE id = $1)
            ON CONFLICT (reservation_id, user_id) DO UPDATE
            SET
                destination_location = COALESCE(EXCLUDED.destination_location, reservation_bluetooth_participants.destination_location),
                destination_lat = COALESCE(EXCLUDED.destination_lat, reservation_bluetooth_participants.destination_lat),
                destination_lng = COALESCE(EXCLUDED.destination_lng, reservation_bluetooth_participants.destination_lng)
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
                    [reservationId, userId],
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
            // Ignore rollback errors.
        }
        throw error;
    } finally {
        client.release();
    }
}

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

async function get(reservationId, userId) {
    const query = `
        SELECT *
        FROM reservation_bluetooth_participants
        WHERE reservation_id = $1 AND user_id = $2;
    `;
    const values = [reservationId, userId];
    const { rows } = await pool.query(query, values);
    return rows[0];
}

module.exports = { confirm, cancel, get };
