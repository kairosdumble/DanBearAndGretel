const jwt = require("jsonwebtoken");

function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ message: "인증이 필요합니다." });
  }
  const token = header.slice("Bearer ".length).trim();
  const secret = process.env.JWT_SECRET_KEY;
  if (!secret) {
    return res.status(500).json({ message: "서버 인증 설정이 없습니다." });
  }
  try {
    const payload = jwt.verify(token, secret);
    const id = payload.sub ?? payload.userId ?? payload.id;
    if (id == null || id === "") {
      return res.status(401).json({ message: "유효하지 않은 토큰입니다." });
    }
    req.user = { id };
    next();
  } catch {
    return res.status(401).json({ message: "유효하지 않거나 만료된 토큰입니다." });
  }
}

module.exports = { authenticate };
