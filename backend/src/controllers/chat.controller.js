const chatService = require("../services/chat.service");

const streamClientsByReservation = new Map();

function parseReservationId(value) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function formatMessageForUser(message, userId) {
  return {
    ...message,
    is_mine: String(message.sender_id) === String(userId),
  };
}

function writeSse(res, event, data) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

function addStreamClient(reservationId, client) {
  const key = String(reservationId);
  const clients = streamClientsByReservation.get(key) || new Set();
  const pingInterval = setInterval(() => {
    client.res.write(": ping\n\n");
  }, 25000);

  client.pingInterval = pingInterval;
  clients.add(client);
  streamClientsByReservation.set(key, clients);

  client.req.on("close", () => {
    clearInterval(client.pingInterval);
    clients.delete(client);
    if (clients.size === 0) {
      streamClientsByReservation.delete(key);
    }
  });
}

function broadcastReservationMessage(reservationId, message) {
  const clients = streamClientsByReservation.get(String(reservationId));
  if (!clients) return;

  for (const client of clients) {
    writeSse(
      client.res,
      "message",
      formatMessageForUser(message, client.userId),
    );
  }
}

async function getReservationMessages(req, res) {
  try {
    const reservationId = parseReservationId(req.params.reservationId);
    if (reservationId == null) {
      return res.status(400).json({ message: "Invalid reservation id." });
    }

    const messages = await chatService.getMessagesByReservationId(
      reservationId,
      req.user.id,
    );
    return res.status(200).json(messages);
  } catch (error) {
    return res.status(500).json({
      message: "Failed to load chat messages.",
      error: error.message,
    });
  }
}

async function createReservationMessage(req, res) {
  try {
    const reservationId = parseReservationId(req.params.reservationId);
    const message = String(req.body?.message || "").trim();

    if (reservationId == null) {
      return res.status(400).json({ message: "Invalid reservation id." });
    }
    if (!message) {
      return res.status(400).json({ message: "Message is required." });
    }

    const created = await chatService.createMessage(
      reservationId,
      req.user.id,
      message,
    );
    if (!created) {
      return res.status(404).json({ message: "Reservation not found." });
    }

    broadcastReservationMessage(reservationId, created);
    return res.status(201).json(created);
  } catch (error) {
    return res.status(500).json({
      message: "Failed to save chat message.",
      error: error.message,
    });
  }
}

async function streamReservationMessages(req, res) {
  const reservationId = parseReservationId(req.params.reservationId);
  if (reservationId == null) {
    return res.status(400).json({ message: "Invalid reservation id." });
  }

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders?.();

  writeSse(res, "ready", { ok: true });
  addStreamClient(reservationId, {
    req,
    res,
    userId: req.user.id,
  });
}

module.exports = {
  getReservationMessages,
  createReservationMessage,
  streamReservationMessages,
};
