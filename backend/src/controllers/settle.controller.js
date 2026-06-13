const settleService = require("../services/settle.service");
const reservationService = require("../services/reservation.service");

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

async function recordDropoff(req, res) {
    try {
        const reservationId = parseReservationId(req);
        if (!reservationId) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const body = req.body || {};
        const result = await reservationService.recordParticipantDropoff(
            reservationId,
            req.user.id,
            {
                destination_location: String(body.destination_location || "").trim(),
                destination_lat: body.destination_lat,
                destination_lng: body.destination_lng,
            },
        );

        if (!result) {
            return res.status(404).json({ message: "예약 정보를 찾을 수 없습니다." });
        }
        if (result.error === "NOT_FOUND") {
            return res.status(404).json({ message: "예약 정보를 찾을 수 없습니다." });
        }
        if (result.error === "CREATOR") {
            return res.status(403).json({
                message: "예약 생성자는 중도 하차 등록을 할 수 없습니다.",
            });
        }
        if (result.error === "NOT_RUNNING") {
            return res.status(409).json({
                message: "진행 중인 예약에서만 하차 정보를 등록할 수 있습니다.",
            });
        }
        if (result.error === "NOT_PARTICIPANT") {
            return res.status(403).json({
                message: "매칭된 동승자만 하차 정보를 등록할 수 있습니다.",
            });
        }
        if (result.error === "ALREADY_COMPLETED") {
            return res.status(409).json({
                message: "이미 하차 정보가 등록되어 있습니다.",
            });
        }
        if (result.error === "NO_DESTINATION") {
            return res.status(400).json({
                message: "하차 위치 정보가 없습니다. 목적지를 설정해 주세요.",
            });
        }

        return res.status(200).json({
            message: "하차 정보가 저장되었습니다.",
            distance_meters: result.distance_meters,
        });
    } catch (error) {
        return res.status(error.status || 500).json({
            message: error.message || "하차 정보 저장 중 오류가 발생했습니다.",
        });
    }
}

module.exports = {
    getSettlementStatus,
    getSettlementNotification,
    requestSettlement,
    transferSettlement,
    recordDropoff,
};
