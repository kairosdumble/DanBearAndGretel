const pool = require('../db/pool');
const settleService = require('../services/settle.service');

async function createSettle(req, res) {
  try {
    const { userId } = req.user;
    const { fare } = req.body;
    const { reservationId } = req.params;
    const updated = await settleService.updateTotal(reservationId, { fare });

    if (!updated) {
        return res.status(404).json({ message: "해당 예약을 찾을 수 없거나 권한이 없습니다." });
    }
    res.status(200).json(updated);
  } catch (error) {
      res.status(500).json({ message: "수정 중 오류 발생", error: error.message });
  }
}

module.exports = { createSettle };