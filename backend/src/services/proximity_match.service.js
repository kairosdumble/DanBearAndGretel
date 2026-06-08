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
        WHERE id = $1 AND status = 'READY';
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
        message: "방장의 확정 요청이 도착했습니다. 승인해 주세요.",
    };
}

async function confirm(reservationId, userId) {
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

        if (approval.rows[0].approved_at) {
            return approval.rows[0];
        }

        return approvePendingRequest(
            pendingRequest.rows[0].id,
            userId,
            reservationId,
        );
    }

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
            INSERT INTO reservation_chat_participants (reservation_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT (reservation_id, user_id) DO NOTHING;
            `,
            values,
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
            /* ignore */
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
        SELECT * FROM reservation_bluetooth_participants
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
