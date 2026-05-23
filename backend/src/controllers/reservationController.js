const reservationService = require("../services/reservation.service");
const proximityMatchService = require("../services/proximityMatch.service");

// POST /api/reservations
async function createReservation(req, res) {
    try {
        const userId = req.user.id;
        const { departure_location, destination_location, departure_time } = req.body || {};
        if (
            departure_location == null || String(departure_location).trim() === "" ||
            destination_location == null || String(destination_location).trim() === "" ||
            departure_time == null || String(departure_time).trim() === ""
        ) {
            return res.status(400).json({ message: "출발지, 목적지, 출발 시간은 필수입니다." });
        }
        const newReservation = await reservationService.createReservation(userId, {
            departure_location: String(departure_location).trim(),
            destination_location: String(destination_location).trim(),
            departure_time: String(departure_time).trim(),
        });
        res.status(201).json(newReservation);
        console.log("newReservation", newReservation);
    } catch (error) {
        console.log("error", error);
        res.status(500).json({ message: "예약 등록 중 오류 발생", error: error.message });
    }
}

    // GET / API 예약 목록 조회 (기존 getReservation 보완)
async function getReservation(req, res) {
        try {
            const userId = req.user.id;
            const reservations = await reservationService.getReservationsByUserId(userId);
            res.status(200).json(reservations);
        } catch (error) {
            res.status(500).json({ message: "조회 중 오류 발생", error: error.message });
        }
}

/** GET — reservations 테이블 전체 행 (로그인 필요, 필터 없음) */
async function getAllReservations(req, res) {
    try {
        const reservations = await reservationService.getAllReservations();
        res.status(200).json(reservations);
    } catch (error) {
        res.status(500).json({ message: "전체 예약 조회 중 오류 발생", error: error.message });
    }
}

    // PUT /:id API 예약 수정 (기존 putReservation 보완)
async function putReservation(req, res) {
    try {
        const { id } = req.params; // 수정할 예약의 PK
        const userId = req.user.id;
        const updated = await reservationService.updateReservation(id, userId, req.body);
        
        if (!updated) {
            return res.status(404).json({ message: "해당 예약을 찾을 수 없거나 권한이 없습니다." });
        }
        res.status(200).json(updated);
    } catch (error) {
        res.status(500).json({ message: "수정 중 오류 발생", error: error.message });
    }
}

// 예약 확정
// - 블루투스 매칭 화면에서 클릭시 해당 사용자가 reservation_participants에 추가됨.
async function confirmProximityMatch(req, res) {
    try {
        const {reservation_id:reservationId} = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id; // 미들웨어가 해독해줌.
        const confirmed = await proximityMatchService.confirm(
            Number(reservationId),
            userId
        );
        res.status(200).json(confirmed);
    } catch (error) {
        res.status(500).json({ message: "예약 확정 중 오류 발생", error: error.message });
    }
}

// 예약 취소
// - 블루투스 매칭 화면에서 클릭시 해당 사용자가 reservation_participants에서 삭제됨.
async function cancelProximityMatch(req, res) {
    try {
        const {reservation_id:reservationId} = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id;
        const cancelled = await proximityMatchService.cancel(
            Number(reservationId),
            userId
        );
        if (!cancelled) {
            return res.status(404).json({ message: "참여 기록을 찾을 수 없습니다." });
        }
        res.status(200).json(cancelled);
    } catch (error) {
        res.status(500).json({ message: "예약 취소 중 오류 발생", error: error.message });
    }
}
async function getProximityMatch(req,res){
    try {
        const {reservation_id:reservationId} = req.params;
        if (reservationId == null) {
            return res.status(400).json({ message: "예약 ID가 필요합니다." });
        }
        const userId = req.user.id;
        const cancelled = await proximityMatchService.get(
            Number(reservationId),
            userId
        );
        if (!cancelled) {
            return res.status(404).json({ message: "참여 기록을 찾을 수 없습니다." });
        }
        res.status(200).json(cancelled);
    } catch (error) {
        res.status(500).json({ message: "예약 취소 중 오류 발생", error: error.message });
    }
}
module.exports = {
    createReservation,
    getReservation,
    getAllReservations,
    putReservation,
    confirmProximityMatch,
    cancelProximityMatch,
    getProximityMatch,
};