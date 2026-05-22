const express = require('express');
const router = express.Router();

const { authenticate } = require('../middleware/auth.middleware'); 
const userController = require('../controllers/user.controller');

// 프론트엔드에서 GET 요청 -> authenticate 미들웨어 통과 -> 정보 전송
router.get('/profile', authenticate, userController.getUserProfile);

module.exports = router;