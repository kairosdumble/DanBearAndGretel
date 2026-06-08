const settleService = require("../services/settle.service");

function parseReservationId(req) {
    const reservationId = Number(req.params.reservationId);
    return Number.isInteger(reservationId) && reservationId > 0
        ? reservationId
        : null;
}

async function getSettlementStatus(req, res) {
    try {
        const reservationId = parseReservationId(req);
        if (!reservationId) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const status = await settleService.getStatus(reservationId, req.user.id);
        if (!status) {
            return res.status(404).json({ message: "예약 정보를 찾을 수 없습니다." });
        }
        return res.status(200).json(status);
    } catch (error) {
        return res.status(error.status || 500).json({
            message: error.message || "정산 상태 조회 중 오류가 발생했습니다.",
        });
    }
}

async function getSettlementNotification(req, res) {
    try {
        const notification = await settleService.getNotification(req.user.id);
        return res.status(200).json(notification);
    } catch (error) {
        return res.status(error.status || 500).json({
            message: error.message || "정산 알림 조회 중 오류가 발생했습니다.",
        });
    }
}

async function requestSettlement(req, res) {
    try {
        const reservationId = parseReservationId(req);
        if (!reservationId) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const totalFare = Number(req.body?.total_fare);
        if (!Number.isFinite(totalFare) || totalFare <= 0) {
            return res.status(400).json({ message: "총 결제금액이 필요합니다." });
        }

        const requested = await settleService.requestSettlement(
            reservationId,
            req.user.id,
            totalFare,
        );
        if (!requested) {
            return res.status(404).json({ message: "예약 정보를 찾을 수 없습니다." });
        }
        return res.status(200).json(requested);
    } catch (error) {
        return res.status(error.status || 500).json({
            message: error.message || "정산 요청 중 오류가 발생했습니다.",
        });
    }
}

async function transferSettlement(req, res) {
    try {
        const reservationId = parseReservationId(req);
        if (!reservationId) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const transferred = await settleService.transferSettlement(
            reservationId,
            req.user.id,
        );
        if (!transferred) {
            return res.status(404).json({ message: "예약 정보를 찾을 수 없습니다." });
        }
        return res.status(200).json(transferred);
    } catch (error) {
        return res.status(error.status || 500).json({
            message: error.message || "송금 중 오류가 발생했습니다.",
        });
    }
}

module.exports = {
    getSettlementStatus,
    getSettlementNotification,
    requestSettlement,
    transferSettlement,
};
