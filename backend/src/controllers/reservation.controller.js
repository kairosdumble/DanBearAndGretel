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

async function getSettlementDetails(req, res) {
    try {
        const reservationId = Number(req.params.id);
        if (!Number.isInteger(reservationId) || reservationId <= 0) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }

        const details = await reservationService.getSettlementDetails(
            reservationId,
            req.user.id,
        );
        if (!details) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없습니다." });
        }
        res.status(200).json(details);
    } catch (error) {
        res.status(500).json({
            message: "정산 정보 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

async function getActiveMatchedReservation(req, res) {
    try {
        const reservation = await reservationService.getActiveMatchedReservation(
            req.user.id,
        );
        if (!reservation) {
            return res.status(404).json({ message: "진행 중인 예약이 없습니다." });
        }
        res.status(200).json(reservation);
    } catch (error) {
        res.status(500).json({
            message: "진행 중인 예약 조회 중 오류가 발생했습니다.",
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
    getSettlementDetails,
    getActiveMatchedReservation,
    getAllReservations,
    putReservation,
    confirmProximityMatch,
    cancelProximityMatch,
    getProximityMatch,
};
