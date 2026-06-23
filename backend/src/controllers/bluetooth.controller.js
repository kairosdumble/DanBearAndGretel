const proximityMatchService = require("../services/proximity_match.service");

function parseCoordinate(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

// 사용자 위치 갱신 컨트롤러 함수
async function updateProximityPresence(req, res) {
    try {
        const reservationId = Number(req.params.reservation_id);
        if (!Number.isInteger(reservationId) || reservationId <= 0) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const presence = await proximityMatchService.upsertPresence(
            reservationId,
            req.user.id,
        );
        if (!presence) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없습니다." });
        }
        return res.status(200).json(presence);
    } catch (error) {
        return res.status(500).json({
            message: "근접 상태 갱신 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 주변 동승자 조회 컨트롤러 함수
async function getProximityNearbyUsers(req, res) {
    try {
        const reservationId = Number(req.params.reservation_id);
        if (!Number.isInteger(reservationId) || reservationId <= 0) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const users = await proximityMatchService.getNearbyUsers(
            reservationId,
            req.user.id,
        );
        return res.status(200).json(users);
    } catch (error) {
        return res.status(500).json({
            message: "주변 동승자 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 근접 매칭 승인 상태 조회 컨트롤러 함수 
async function getProximityApprovalStatus(req, res) {
    try {
        const reservationId = Number(req.params.reservation_id);
        if (!Number.isInteger(reservationId) || reservationId <= 0) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const status = await proximityMatchService.getApprovalStatus(
            reservationId,
            req.user.id,
        );
        return res.status(200).json(status);
    } catch (error) {
        return res.status(500).json({
            message: "승인 상태 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 사용자별 근접 매칭 확정 컨트롤러 함수
async function confirmProximityMatch(req, res) {
    try {
        const { reservation_id: reservationId } = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id;
        const body = req.body || {};
        const confirmed = await proximityMatchService.confirm(
            Number(reservationId),
            userId,
            {
                destination_location: String(body.destination_location || "").trim(),
                destination_lat: parseCoordinate(body.destination_lat),
                destination_lng: parseCoordinate(body.destination_lng),
            },
        );
        if (confirmed?.error === "NOT_INVITED") {
            return res.status(403).json({
                message: "방장이 선택한 동승자만 승인할 수 있습니다.",
            });
        }
        if (!confirmed) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없습니다." });
        }
        res.status(200).json(confirmed);
    } catch (error) {
        res.status(500).json({
            message: "예약 확정 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 예약 확정 취소 컨트롤러 함수
async function cancelProximityMatch(req, res) {
    try {
        const { reservation_id: reservationId } = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id;
        const cancelled = await proximityMatchService.cancel(
            Number(reservationId),
            userId,
        );
        if (!cancelled) {
            return res.status(404).json({ message: "참여 기록을 찾을 수 없습니다." });
        }
        res.status(200).json(cancelled);
    } catch (error) {
        res.status(500).json({
            message: "예약 취소 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 참여 기록 조회 컨트롤러 함수
async function getProximityMatch(req, res) {
    try {
        const { reservation_id: reservationId } = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id;
        const match = await proximityMatchService.get(Number(reservationId), userId);
        if (!match) {
            return res.status(404).json({ message: "참여 기록을 찾을 수 없습니다." });
        }
        res.status(200).json(match);
    } catch (error) {
        res.status(500).json({
            message: "예약 참여 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 그룹 매칭 확정 컨트롤러 함수
async function confirmGroupMatch(req, res) {
    try {
        const reservationId = Number(req.body?.reservation_id);
        const leaderId = req.user.id;
        const participantIds = Array.isArray(req.body?.participant_ids)
            ? req.body.participant_ids
            : [];

        if (!Number.isInteger(reservationId) || reservationId <= 0) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        if (participantIds.length === 0) {
            return res.status(400).json({
                message: "선택된 동승자가 없습니다.",
            });
        }

        const result = await proximityMatchService.confirmGroupRequest(
            reservationId,
            leaderId,
            participantIds,
        );

        if (!result) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없습니다." });
        }
        if (result.error === "NOT_LEADER") {
            return res.status(403).json({
                message: "예약 생성자만 모임 확정 요청을 보낼 수 있습니다.",
            });
        }

        return res.status(201).json(result);
    } catch (error) {
        return res.status(500).json({
            message: "모임 확정 요청 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

module.exports = {
    updateProximityPresence,
    getProximityNearbyUsers,
    getProximityApprovalStatus,
    confirmProximityMatch,
    cancelProximityMatch,
    getProximityMatch,
    confirmGroupMatch,
}