const pool = require("../db/pool");

const PRESENCE_TTL_SECONDS = 30;

async function upsertPresence(reservationId, userId) {
    const reservationCheck = await pool.query(
        `SELECT id FROM reservations WHERE id = $1`,
        [reservationId],
    );
    if (!reservationCheck.rows[0]) {
        return null;
    }

    const query = `
        INSERT INTO reservation_proximity_presence (reservation_id, user_id, last_seen_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (reservation_id, user_id)
        DO UPDATE SET last_seen_at = NOW()
        RETURNING *;
    `;
    const { rows } = await pool.query(query, [reservationId, Number(userId)]);
    return rows[0];
}

async function getNearbyUsers(reservationId, excludeUserId = null) {
    const excludedId =
        excludeUserId == null ? null : Number(excludeUserId);

    const query = `
        SELECT p.user_id, u.name, u.nickname, p.last_seen_at
        FROM reservation_proximity_presence p
        JOIN users u ON u.id = p.user_id
        WHERE p.reservation_id = $1
          AND p.last_seen_at >= NOW() - ($2::text || ' seconds')::interval
          AND ($3::integer IS NULL OR p.user_id <> $3)
        ORDER BY p.last_seen_at DESC, p.user_id ASC;
    `;
    const { rows } = await pool.query(query, [
        reservationId,
        String(PRESENCE_TTL_SECONDS),
        excludedId,
    ]);
    return rows;
}

async function finalizeRequest(client, requestId, reservationId) {
    const requestResult = await client.query(
        `SELECT * FROM reservation_proximity_requests WHERE id = $1`,
        [requestId],
    );
    const request = requestResult.rows[0];
    if (!request) return null;

    const leaderId = Number(request.leader_id);
    const selectedIds = (request.selected_user_ids || []).map(Number);
    const allUserIds = [leaderId, ...selectedIds.filter((id) => id !== leaderId)];

    for (const uid of allUserIds) {
        await client.query(
            `
            INSERT INTO reservation_bluetooth_participants (reservation_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT (reservation_id, user_id) DO NOTHING;
            `,
            [reservationId, uid],
        );
        await client.query(
            `
            INSERT INTO reservation_chat_participants (reservation_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT (reservation_id, user_id) DO NOTHING;
            `,
            [reservationId, uid],
        );
    }

    await client.query(
        `
        UPDATE reservations
        SET status = 'RUNNING'
        WHERE id = $1 AND status IN ('READY', 'MATCHED');
        `,
        [reservationId],
    );

    await client.query(
        `
        UPDATE reservation_proximity_requests
        SET status = 'CONFIRMED'
        WHERE id = $1;
        `,
        [requestId],
    );

    return request;
}

async function approvePendingRequest(requestId, userId, reservationId) {
    const client = await pool.connect();
    try {
        await client.query("BEGIN");

        const approvalResult = await client.query(
            `
            UPDATE reservation_proximity_approvals
            SET approved_at = NOW()
            WHERE request_id = $1
              AND user_id = $2
              AND approved_at IS NULL
            RETURNING *;
            `,
            [requestId, userId],
        );

        if (!approvalResult.rows[0]) {
            const existing = await client.query(
                `
                SELECT *
                FROM reservation_proximity_approvals
                WHERE request_id = $1 AND user_id = $2;
                `,
                [requestId, userId],
            );
            if (!existing.rows[0]) {
                await client.query("ROLLBACK");
                return null;
            }
        }

        const pendingCount = await client.query(
            `
            SELECT COUNT(*)::integer AS count
            FROM reservation_proximity_approvals
            WHERE request_id = $1 AND approved_at IS NULL;
            `,
            [requestId],
        );

        if (pendingCount.rows[0].count === 0) {
            await finalizeRequest(client, requestId, reservationId);
        }

        await client.query("COMMIT");
        return approvalResult.rows[0] || { request_id: requestId, user_id: userId };
    } catch (error) {
        try {
            await client.query("ROLLBACK");
        } catch {
            /* ignore */
        }
        throw error;
    } finally {
        client.release();
    }
}

async function confirmGroupRequest(reservationId, leaderId, participantIds) {
    const client = await pool.connect();
    try {
        await client.query("BEGIN");

        const reservationResult = await client.query(
            `SELECT * FROM reservations WHERE id = $1`,
            [reservationId],
        );
        const reservation = reservationResult.rows[0];
        if (!reservation) {
            await client.query("ROLLBACK");
            return null;
        }
        if (String(reservation.user_id) !== String(leaderId)) {
            await client.query("ROLLBACK");
            return { error: "NOT_LEADER" };
        }

        await client.query(
            `
            UPDATE reservation_proximity_requests
            SET status = 'CANCELLED'
            WHERE reservation_id = $1 AND status = 'PENDING';
            `,
            [reservationId],
        );

        const uniqueIds = [
            ...new Set(
                (participantIds || [])
                    .map((id) => Number(id))
                    .filter((id) => Number.isInteger(id) && id > 0 && id !== leaderId),
            ),
        ];

        const requestResult = await client.query(
            `
            INSERT INTO reservation_proximity_requests (
                reservation_id,
                leader_id,
                selected_user_ids
            )
            VALUES ($1, $2, $3)
            RETURNING *;
            `,
            [reservationId, leaderId, uniqueIds],
        );
        const request = requestResult.rows[0];

        await client.query(
            `
            INSERT INTO reservation_proximity_approvals (request_id, user_id, approved_at)
            VALUES ($1, $2, NOW());
            `,
            [request.id, leaderId],
        );

        for (const uid of uniqueIds) {
            await client.query(
                `
                INSERT INTO reservation_proximity_approvals (request_id, user_id, approved_at)
                VALUES ($1, $2, NULL);
                `,
                [request.id, uid],
            );
        }

        await client.query("COMMIT");
        return request;
    } catch (error) {
        try {
            await client.query("ROLLBACK");
        } catch {
            /* ignore */
        }
        throw error;
    } finally {
        client.release();
    }
}

async function getApprovalStatus(reservationId, userId) {
    const participant = await get(reservationId, userId);
    if (participant) {
        return {
            mode: "matched",
            canApprove: false,
            message: "이미 매칭이 완료되었습니다.",
        };
    }

    const pendingRequest = await pool.query(
        `
        SELECT *
        FROM reservation_proximity_requests
        WHERE reservation_id = $1 AND status = 'PENDING'
        ORDER BY created_at DESC
        LIMIT 1;
        `,
        [reservationId],
    );

    if (!pendingRequest.rows[0]) {
        return {
            mode: "waiting_leader",
            canApprove: false,
            message: "방장의 확정 요청을 기다리는 중입니다.",
        };
    }

    const approval = await pool.query(
        `
        SELECT *
        FROM reservation_proximity_approvals
        WHERE request_id = $1 AND user_id = $2;
        `,
        [pendingRequest.rows[0].id, userId],
    );

    if (!approval.rows[0]) {
        return {
            mode: "not_invited",
            canApprove: false,
            message: "방장이 선택한 동승자만 승인할 수 있습니다.",
        };
    }

    if (approval.rows[0].approved_at) {
        return {
            mode: "already_approved",
            canApprove: false,
            message: "이미 승인을 완료했습니다. 다른 동승자를 기다리는 중입니다.",
        };
    }

    return {
        mode: "can_approve",
        canApprove: true,
        message: "방장에게 확정 요청을 전송했습니다. \n승인이 될 때까지 조금만 기다려주세요",
    };
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

    const pendingRequest = await pool.query(
        `
        SELECT *
        FROM reservation_proximity_requests
        WHERE reservation_id = $1 AND status = 'PENDING'
        ORDER BY created_at DESC
        LIMIT 1;
        `,
        [reservationId],
    );

    if (pendingRequest.rows[0]) {
        const approval = await pool.query(
            `
            SELECT *
            FROM reservation_proximity_approvals
            WHERE request_id = $1 AND user_id = $2;
            `,
            [pendingRequest.rows[0].id, userId],
        );

        if (!approval.rows[0]) {
            return { error: "NOT_INVITED" };
        }

        if (!approval.rows[0].approved_at) {
            await approvePendingRequest(
                pendingRequest.rows[0].id,
                userId,
                reservationId,
            );
        }
    }

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
                destination_lng,
                confirmed_at
            )
            SELECT $1, $2, $3, $4, $5, NOW()
            WHERE EXISTS (SELECT 1 FROM reservations WHERE id = $1)
            ON CONFLICT (reservation_id, user_id) DO UPDATE
            SET
                destination_location = COALESCE(EXCLUDED.destination_location, reservation_bluetooth_participants.destination_location),
                destination_lat = COALESCE(EXCLUDED.destination_lat, reservation_bluetooth_participants.destination_lat),
                destination_lng = COALESCE(EXCLUDED.destination_lng, reservation_bluetooth_participants.destination_lng),
                confirmed_at = COALESCE(reservation_bluetooth_participants.confirmed_at, NOW())
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
            INSERT INTO reservation_chat_participants (reservation_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT (reservation_id, user_id) DO NOTHING;
            `,
            [reservationId, userId],
        );

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
        ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION NULL,
        ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ NULL;
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

module.exports = {
    confirm,
    cancel,
    get,
    confirmGroupRequest,
    upsertPresence,
    getNearbyUsers,
    getApprovalStatus,
};
