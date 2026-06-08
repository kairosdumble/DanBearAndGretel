const pool = require("./pool");

async function ensureProximitySchema() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS reservation_proximity_presence (
            reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            PRIMARY KEY (reservation_id, user_id)
        );
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS reservation_proximity_requests (
            id SERIAL PRIMARY KEY,
            reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
            leader_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            selected_user_ids INTEGER[] NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING'
                CHECK (status IN ('PENDING', 'CONFIRMED', 'CANCELLED')),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS reservation_proximity_approvals (
            request_id INTEGER NOT NULL
                REFERENCES reservation_proximity_requests(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            approved_at TIMESTAMPTZ,
            PRIMARY KEY (request_id, user_id)
        );
    `);

    await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_proximity_requests_reservation_status
            ON reservation_proximity_requests (reservation_id, status);
    `);
}

module.exports = ensureProximitySchema;
