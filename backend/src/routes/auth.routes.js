const express = require("express");
const authController = require("../controllers/auth.controller");

const router = express.Router();

router.post("/email/send-code", authController.sendCode);
router.post("/email/verify-code", authController.verifyCode);

module.exports = router;