const pool = require("../db/pool");

const chatService = {
  getUserById: async (userId) => {
    const query = `
      SELECT id, name, email
      FROM users
      WHERE id = $1;
    `;
    const { rows } = await pool.query(query, [userId]);
    return rows[0] || null;
  },

  getMessagesByReservationId: async (reservationId, userId) => {
    const query = `
      SELECT
        id,
        reservation_id,
        sender_id,
        message,
        created_at,
        sender_id::text = $2::text AS is_mine
      FROM chat_messages
      WHERE reservation_id = $1
      ORDER BY created_at ASC, id ASC;
    `;
    const { rows } = await pool.query(query, [reservationId, userId]);
    return rows;
  },

  createMessage: async (reservationId, userId, message) => {
    const query = `
      INSERT INTO chat_messages (reservation_id, sender_id, message)
      SELECT $1, $2, $3
      WHERE EXISTS (SELECT 1 FROM reservations WHERE id = $1)
      RETURNING
        id,
        reservation_id,
        sender_id,
        message,
        created_at,
        true AS is_mine;
    `;
    const { rows } = await pool.query(query, [reservationId, userId, message]);
    return rows[0] || null;
  },
};

module.exports = chatService;
