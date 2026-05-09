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
  try {
    const info = await transporter.sendMail({
      from: process.env.MAIL_FROM || process.env.MAIL_USER,
      to,
      subject: "[Dangretel] 이메일 인증번호",
      text: `인증번호는 ${code} 입니다. 5분 이내에 입력해주세요.`,
      });
      console.log("메일 전송 성공:", info.messageId); // 전송 성공 시 ID 출력
      console.log("받는 사람:", to);
  } catch (error) {
    console.error("메일 전송 실패 디테일:", error); // 에러 발생 시 상세 이유 출력    
    throw error;
  }
}

module.exports = {
  sendVerificationEmail,
};