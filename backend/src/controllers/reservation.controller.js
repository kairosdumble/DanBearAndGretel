const reservationService = require("../services/reservation.service");
const proximityMatchService = require("../services/proximity_match.service");

function parseCoordinate(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

function normalizeReservationInput(body) {
    return {
        departure_location: String(body.departure_location || "").trim(),
        destination_location: String(body.destination_location || "").trim(),
        departure_time: String(body.departure_time || "").trim(),
        departure_lat: parseCoordinate(body.departure_lat),
        departure_lng: parseCoordinate(body.departure_lng),
        destination_lat: parseCoordinate(body.destination_lat),
        destination_lng: parseCoordinate(body.destination_lng),
    };
}

function isReservationInputValid(data) {
    return (
        data.departure_location !== "" &&
        data.destination_location !== "" &&
        data.departure_time !== "" &&
        data.departure_lat !== null &&
        data.departure_lng !== null &&
        data.destination_lat !== null &&
        data.destination_lng !== null
    );
}

async function createReservation(req, res) {
    try {
        const userId = req.user.id;
        const reservationData = normalizeReservationInput(req.body || {});

        if (!isReservationInputValid(reservationData)) {
            return res.status(400).json({
                message: "출발지, 목적지, 출발 시간, 좌표 정보가 모두 필요합니다.",
            });
        }

        const newReservation = await reservationService.createReservation(
            userId,
            reservationData,
        );
        res.status(201).json(newReservation);
    } catch (error) {
        console.log("error", error);
        res.status(500).json({
            message: "예약 등록 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

async function getReservation(req, res) {
    try {
        const userId = req.user.id;
        const reservations = await reservationService.getReservationsByUserId(userId);
        res.status(200).json(reservations);
    } catch (error) {
        res.status(500).json({
            message: "예약 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

async function getReservationById(req, res) {
    try {
        const reservationId = Number(req.params.id);
        if (!Number.isInteger(reservationId) || reservationId <= 0) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const reservation = await reservationService.getReservationById(reservationId);
        if (!reservation) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없습니다." });
        }
        res.status(200).json(reservation);
    } catch (error) {
        res.status(500).json({
            message: "예약 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

async function getAllReservations(req, res) {
    try {
        const lat = parseCoordinate(req.query.lat);
        const lng = parseCoordinate(req.query.lng);
        const destinationLat = parseCoordinate(req.query.destinationLat);
        const destinationLng = parseCoordinate(req.query.destinationLng);
        const reservations = await reservationService.getAllReservations({
            lat,
            lng,
            destinationLat,
            destinationLng,
        });
        res.status(200).json(reservations);
    } catch (error) {
        res.status(500).json({
            message: "전체 예약 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

async function putReservation(req, res) {
    try {
        const { id } = req.params;
        const userId = req.user.id;
        const reservationData = normalizeReservationInput(req.body || {});

        if (!isReservationInputValid(reservationData)) {
            return res.status(400).json({
                message: "출발지, 목적지, 출발 시간, 좌표 정보가 모두 필요합니다.",
            });
        }

        const updated = await reservationService.updateReservation(
            id,
            userId,
            reservationData,
        );

        if (!updated) {
            return res.status(404).json({
                message: "해당 예약을 찾을 수 없거나 권한이 없습니다.",
            });
        }
        res.status(200).json(updated);
    } catch (error) {
        res.status(500).json({
            message: "예약 수정 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

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

async function confirmProximityMatch(req, res) {
    try {
        const { reservation_id: reservationId } = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id;
        const confirmed = await proximityMatchService.confirm(
            Number(reservationId),
            userId,
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

module.exports = {
    createReservation,
    getReservation,
    getReservationById,
    getAllReservations,
    putReservation,
    confirmGroupMatch,
    updateProximityPresence,
    getProximityNearbyUsers,
    getProximityApprovalStatus,
    confirmProximityMatch,
    cancelProximityMatch,
    getProximityMatch,
};
