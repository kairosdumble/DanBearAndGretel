const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  host: process.env.MAIL_HOST,
  port: Number(process.env.MAIL_PORT || 587),
  secure: false, // 465면 true
  auth: {
    user: process.env.MAIL_USER,
    pass: process.env.MAIL_PASS,
  },
});

async function sendVerificationEmail(to, code) {
  await transporter.sendMail({
    from: process.env.MAIL_FROM || process.env.MAIL_USER,
    to,
    subject: "[Dangretel] 이메일 인증번호",
    text: `인증번호는 ${code} 입니다. 5분 이내에 입력해주세요.`,
  });
}

module.exports = {
  sendVerificationEmail,
};