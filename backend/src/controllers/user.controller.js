const pool = require('../db/pool');

exports.getUserProfile = async (req, res) => {
    try {
        const userId = req.user.id; 
        // 유저 정보 조회 쿼리
        const query = `
            SELECT student_id, name, email, nickname, balance, bank_name, account_number 
            FROM users 
            WHERE id = $1
        `;
        const result = await pool.query(query, [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
        }
        // { "name": "사용자이름" } 형태로 응답
        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error("getUserProfile 에러:", error);
        res.status(500).json({ message: '서버 오류가 발생했습니다.' });
    }
};

exports.updateUserProfile = async (req, res) => {
    try {
        const userId = req.user.id;
        const { nickname, bank_name, account_number } = req.body;

        const query = `
            UPDATE users 
            SET nickname = $1, bank_name = $2, account_number = $3
            WHERE id = $4
            RETURNING nickname, bank_name, account_number;
        `;
        
        const result = await pool.query(query, [nickname, bank_name, account_number, userId]);

        if (result.rows.length === 0) return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });

        res.status(200).json({ message: "수정 성공", user: result.rows[0] });
    } catch (error) {
        console.error("수정 에러:", error);
        res.status(500).json({ message: '서버 오류' });
    }
};