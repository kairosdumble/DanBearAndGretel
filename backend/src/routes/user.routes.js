const express = require('express');
const router = express.Router();

const { authenticate } = require('../middleware/auth.middleware'); 
const userController = require('../controllers/user.controller');

// 조회 경로
router.get('/profile', authenticate, userController.getUserProfile);
// 수정 경로
router.put('/profile', authenticate, userController.updateUserProfile);
// 충전 경로
router.post('/charge', authenticate, userController.chargeBalance);
// 개인정보 수정 경로
module.exports = router;