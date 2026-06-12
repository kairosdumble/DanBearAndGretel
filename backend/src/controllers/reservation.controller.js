const reservationService = require("../services/reservation.service");
const proximityMatchService = require("../services/proximity_match.service");


function parseCoordinate(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

// 입력값 정규화 및 유효성 검사
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
// 필수 입력값이 모두 존재하는지 확인
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

// 1. 새 예약 생성 컨트롤러 함수
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

// 2. 예약 ID로 조회 컨트롤러 함수
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

// 3. 예약 정산 정보 조회 컨트롤러 함수
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

// 4. 진행 중인 매칭된 예약 조회 컨트롤러 함수
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

// 5. 전체 예약 조회 컨트롤러 함수 (선택적 좌표 필터링 지원)
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
            userId: req.user.id,
        });
        res.status(200).json(reservations);
    } catch (error) {
        res.status(500).json({
            message: "전체 예약 조회 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}

// 6. 예약 수정 컨트롤러 함수
async function putReservation(req, res) {
    try {
        const { id } = req.params;
        const userId = req.user.id;
        const reservationData = normalizeReservationInput(req.body || {});

        if (!isReservationInputValid(reservationData)) {
            return res.status(400).json({message: "출발지, 목적지, 출발 시간, 좌표 정보가 모두 필요합니다."});
        }

        const updated = await reservationService.updateReservation(
            id,
            userId,
            reservationData,
        );

        if (!updated) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없거나 권한이 없습니다." });
        }
        res.status(200).json(updated);
    } catch (error) {
        res.status(500).json({
            message: "예약 수정 중 오류가 발생했습니다.",
            error: error.message,
        });
    }
}


module.exports = {
    createReservation,
    getReservationById,
    getSettlementDetails,
    getActiveMatchedReservation,
    getAllReservations,
    putReservation,
};
