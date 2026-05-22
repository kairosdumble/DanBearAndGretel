const pool = require('../db/pool');

exports.getUserProfile = async (req, res) => {
    try {
        const userId = req.user.id; 

        // name 컬럼만 조회
        const query = `SELECT name FROM users WHERE id = $1`;
        const result = await pool.query(query, [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
        }

        // { "name": "사용자이름" } 형태로 응답
        res.status(200).json({ name: result.rows[0].name });
    } catch (error) {
        console.error("getUserProfile 에러:", error);
        res.status(500).json({ message: '서버 오류가 발생했습니다.' });
    }
};