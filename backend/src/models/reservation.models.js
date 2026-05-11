// 사용자가 동승자 찾기를 위해 입력하는 데이터 구조

class Reservation {
  constructor({
    id = null,
    user_id,
    departure,
    destination,
    departure_time,
    price = 0,
    created_at = new Date()
  }) {
    this.id = id;                     // 예약 고유 번호 (PK)
    this.user_id = user_id;           // 작성자 ID (users 테이블 참조)
    this.departure = departure;       // 출발지
    this.destination = destination;   // 목적지
    this.departure_time = departure_time; // 출발 시간
    this.price = price;               // 예상 비용
    this.created_at = created_at;     // 생성 시간
  }

  static validate(data) {
    const { user_id, departure, destination, departure_time, price } = data;

    // 1. 필수 값 체크 (비어있는지 확인)
    if (!user_id) return { isValid: false, message: "사용자 ID가 없습니다." };
    if (!departure || departure.trim() === "") return { isValid: false, message: "출발지를 입력해주세요." };
    if (!destination || destination.trim() === "") return { isValid: false, message: "목적지를 입력해주세요." };
    if (!departure_time) return { isValid: false, message: "출발 시간을 선택해주세요." };

    // 2. 날짜 형식 및 과거 시간 체크
    const selectedDate = new Date(departure_time);
    if (isNaN(selectedDate.getTime())) {
      return { isValid: false, message: "올바른 날짜 형식이 아닙니다." };
    }
    if (selectedDate < new Date()) {
      return { isValid: false, message: "이미 지난 시간은 예약할 수 없습니다." };
    }

    // 3. 가격 체크 (숫자인지, 0원 이상인지)
    if (isNaN(price) || price < 0) {
      return { isValid: false, message: "금액은 0원 이상이어야 합니다." };
    }

    // 모든 검사를 통과하면 true 반환
    return { isValid: true };
  }
}

module.exports = Reservation;