const pool = require("../db/pool");
const reservationService = require("./reservation.service");

async function ensureSettlementSchema() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS reservation_settlements (
            reservation_id INTEGER PRIMARY KEY REFERENCES reservations(id) ON DELETE CASCADE,
            requested_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            total_fare BIGINT NOT NULL DEFAULT 0,
            requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    `);
    await pool.query(`
        ALTER TABLE reservation_bluetooth_participants
        ADD COLUMN IF NOT EXISTS settlement_paid BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS settlement_paid_at TIMESTAMPTZ NULL;
    `);
}

function calculateFares(participants, totalFare, creatorId) {
    const sanitized = participants
        .map((participant) => ({
            ...participant,
            id: String(participant.id),
            dropoffDistance: Math.max(0, Number(participant.dropoff_distance_meters) || 0),
        }))
        .filter((participant) => participant.id);

    const fareByPassenger = Object.fromEntries(
        sanitized.map((participant) => [participant.id, 0]),
    );
    if (sanitized.length === 0 || totalFare <= 0) {
        return { fareByPassenger, finalSettler: null };
    }

    const distances = Array.from(
        new Set(
            sanitized
                .map((participant) => participant.dropoffDistance)
                .filter((distance) => distance > 0),
        ),
    ).sort((a, b) => a - b);

    if (distances.length === 0) {
        return {
            fareByPassenger,
            finalSettler: resolveFinalSettler(sanitized, creatorId),
        };
    }

    const totalDistance = distances[distances.length - 1];
    let previousDistance = 0;

    for (const dropoffDistance of distances) {
        const sectionDistance = dropoffDistance - previousDistance;
        if (sectionDistance <= 0) {
            continue;
        }

        const activePassengers = sanitized.filter(
            (participant) => participant.dropoffDistance >= dropoffDistance - 0.000001,
        );
        if (activePassengers.length === 0) {
            previousDistance = dropoffDistance;
            continue;
        }

        const sectionFare = totalFare * (sectionDistance / totalDistance);
        const farePerPerson = sectionFare / activePassengers.length;
        for (const passenger of activePassengers) {
            fareByPassenger[passenger.id] += farePerPerson;
        }
        previousDistance = dropoffDistance;
    }

    return {
        fareByPassenger,
        finalSettler: resolveFinalSettler(sanitized, creatorId),
    };
}

function resolveFinalSettler(participants, creatorId) {
    if (participants.length === 0) {
        return null;
    }
    const maxDistance = Math.max(
        ...participants.map((participant) => participant.dropoffDistance),
    );
    const finalPassengers = participants.filter(
        (participant) => Math.abs(participant.dropoffDistance - maxDistance) < 0.000001,
    );
    return (
        finalPassengers.find((participant) => participant.id === String(creatorId)) ||
        finalPassengers[0]
    );
}

async function getStatus(reservationId, userId) {
    await ensureSettlementSchema();
    const details = await reservationService.getSettlementDetails(reservationId, userId);
    if (!details) {
        return null;
    }

    const settlementResult = await pool.query(
        `
        SELECT reservation_id, requested_by, total_fare, requested_at
        FROM reservation_settlements
        WHERE reservation_id = $1
        `,
        [reservationId],
    );
    const settlement = settlementResult.rows[0] || null;
    const totalFare = Number(settlement?.total_fare || 0);
    const { fareByPassenger, finalSettler } = calculateFares(
        details.participants,
        totalFare,
        details.reservation.creator_id,
    );
    const currentUserId = String(userId);
    const isFinalSettler = finalSettler?.id === currentUserId;

    const paidResult = await pool.query(
        `
        SELECT settlement_paid
        FROM reservation_bluetooth_participants
        WHERE reservation_id = $1 AND user_id = $2
        `,
        [reservationId, userId],
    );
    const paid = paidResult.rows[0]?.settlement_paid === true;
    const pendingPaymentCount = finalSettler == null
        ? 0
        : await getPendingPaymentCount(reservationId, finalSettler.id);

    return {
        requested: settlement != null,
        requested_by: settlement?.requested_by == null ? null : String(settlement.requested_by),
        requested_at: settlement?.requested_at || null,
        total_fare: totalFare,
        final_settler_id: finalSettler?.id || null,
        final_settler_name: finalSettler?.name || finalSettler?.email || null,
        my_fare: Math.round(fareByPassenger[currentUserId] || 0),
        paid,
        pending_payment_count: pendingPaymentCount,
        completed: settlement != null && pendingPaymentCount === 0,
        notification: settlement != null && !isFinalSettler && !paid,
    };
}

async function getPendingPaymentCount(reservationId, finalSettlerId) {
    const result = await pool.query(
        `
        SELECT COUNT(*)::integer AS count
        FROM reservation_bluetooth_participants
        WHERE reservation_id = $1
          AND user_id <> $2
          AND settlement_paid = FALSE
        `,
        [reservationId, finalSettlerId],
    );
    return Number(result.rows[0]?.count || 0);
}

async function getNotification(userId) {
    await ensureSettlementSchema();
    const result = await pool.query(
        `
        SELECT
            rs.reservation_id,
            rs.total_fare,
            rs.requested_at
        FROM reservation_settlements rs
        JOIN reservation_bluetooth_participants rbp
          ON rbp.reservation_id = rs.reservation_id
         AND rbp.user_id = $1
        WHERE rs.requested_by <> $1
          AND rbp.settlement_paid = FALSE
        ORDER BY rs.requested_at DESC
        LIMIT 1
        `,
        [userId],
    );

    const row = result.rows[0];
    return {
        notification: row != null,
        reservation_id: row?.reservation_id || null,
        total_fare: row == null ? 0 : Number(row.total_fare || 0),
        requested_at: row?.requested_at || null,
    };
}

async function requestSettlement(reservationId, userId, totalFare) {
    await ensureSettlementSchema();
    const details = await reservationService.getSettlementDetails(reservationId, userId);
    if (!details) {
        return null;
    }

    const { finalSettler } = calculateFares(
        details.participants,
        Number(totalFare),
        details.reservation.creator_id,
    );
    if (!finalSettler || finalSettler.id !== String(userId)) {
        const error = new Error("최종 정산자만 정산 요청을 보낼 수 있습니다.");
        error.status = 403;
        throw error;
    }

    const safeFare = Math.max(0, Math.round(Number(totalFare) || 0));
    const result = await pool.query(
        `
        INSERT INTO reservation_settlements (reservation_id, requested_by, total_fare)
        VALUES ($1, $2, $3)
        ON CONFLICT (reservation_id) DO UPDATE
        SET requested_by = EXCLUDED.requested_by,
            total_fare = EXCLUDED.total_fare,
            requested_at = NOW()
        RETURNING reservation_id, requested_by, total_fare, requested_at
        `,
        [reservationId, userId, safeFare],
    );
    return result.rows[0];
}

async function transferSettlement(reservationId, userId) {
    await ensureSettlementSchema();
    const details = await reservationService.getSettlementDetails(reservationId, userId);
    if (!details) {
        return null;
    }

    const status = await getStatus(reservationId, userId);
    if (!status?.requested) {
        const error = new Error("아직 정산 요청이 없습니다.");
        error.status = 400;
        throw error;
    }
    if (!status.final_settler_id) {
        const error = new Error("최종 정산자를 찾을 수 없습니다.");
        error.status = 400;
        throw error;
    }
    if (status.final_settler_id === String(userId)) {
        const error = new Error("최종 정산자는 송금할 필요가 없습니다.");
        error.status = 400;
        throw error;
    }

    const amount = Math.max(0, Math.round(Number(status.my_fare) || 0));
    const client = await pool.connect();
    try {
        await client.query("BEGIN");

        const senderResult = await client.query(
            "SELECT balance FROM users WHERE id = $1 FOR UPDATE",
            [userId],
        );
        const receiverResult = await client.query(
            "SELECT id FROM users WHERE id = $1 FOR UPDATE",
            [status.final_settler_id],
        );
        if (senderResult.rows.length === 0 || receiverResult.rows.length === 0) {
            const error = new Error("사용자를 찾을 수 없습니다.");
            error.status = 404;
            throw error;
        }

        const balance = Number(senderResult.rows[0].balance || 0);
        if (balance < amount) {
            const error = new Error("잔액을 충전해주세요");
            error.status = 402;
            throw error;
        }

        await client.query("UPDATE users SET balance = balance - $1 WHERE id = $2", [
            amount,
            userId,
        ]);
        await client.query("UPDATE users SET balance = balance + $1 WHERE id = $2", [
            amount,
            status.final_settler_id,
        ]);
        await client.query(
            `
            UPDATE reservation_bluetooth_participants
            SET settlement_paid = TRUE,
                settlement_paid_at = NOW(),
                dropoff_completed = TRUE,
                fare = $3
            WHERE reservation_id = $1 AND user_id = $2
            `,
            [reservationId, userId, amount],
        );

        const pendingResult = await client.query(
            `
            SELECT COUNT(*)::integer AS count
            FROM reservation_bluetooth_participants
            WHERE reservation_id = $1
              AND user_id <> $2
              AND settlement_paid = FALSE
            `,
            [reservationId, status.final_settler_id],
        );
        const pendingCount = Number(pendingResult.rows[0]?.count || 0);
        if (pendingCount === 0) {
            await client.query(
                "UPDATE reservations SET status = 'COMPLETED' WHERE id = $1",
                [reservationId],
            );
        }

        await client.query("COMMIT");
        return {
            amount,
            newBalance: balance - amount,
            finalSettlerId: status.final_settler_id,
            completed: pendingCount === 0,
        };
    } catch (error) {
        await client.query("ROLLBACK");
        throw error;
    } finally {
        client.release();
    }
}

module.exports = {
    getStatus,
    getNotification,
    requestSettlement,
    transferSettlement,
};
