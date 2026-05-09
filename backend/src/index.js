// 서버 진입점입니다. Express 서버를 설정하고 PostgreSQL 데이터베이스와 연결합니다.
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const pool = require("./db/pool");
const authRoutes = require("./routes/auth.routes");
const rateLimit = require("express-rate-limit");

const app = express();
const baseUrl = process.env.BASE_URL;
const port = Number(process.env.PORT) || 3000;
const tmapApiKey = process.env.TMAP_API_KEY || process.env.TMAP_APP_KEY || "";
const tmapPoiBaseUrl = "https://apis.openapi.sk.com/tmap/pois";
const searchTimeoutMs = Number(process.env.SEARCH_TIMEOUT_MS) || 5000;
const defaultSearchCount = Number(process.env.SEARCH_COUNT) || 20;
const databaseUrl = process.env.DATABASE_URL;

const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5분
  max: 10, // 5분에 10회
  message: { message: "요청이 너무 많습니다. 잠시 후 다시 시도하세요." },
});

if (!databaseUrl) {
  throw new Error("DATABASE_URL 환경변수가 설정되지 않았습니다.");
}

app.use(cors());
app.use(express.json());
app.use("/auth", authRoutes);
app.use("/auth/email", authLimiter);

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, service: "dangretel-api", database: "connected" });
  } catch (error) {
    res.status(503).json({
      ok: false,
      service: "dangretel-api",
      database: "disconnected",
      error: error.message,
    });
  }
});

app.get("/", (_req, res) => {
  res.json({ message: "Dangretel API" });
});

const server = app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server listening on ${baseUrl}:${port}`);
});

server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    // eslint-disable-next-line no-console
    console.error(
      `[EADDRINUSE] 포트 ${port}가 이미 사용 중입니다. 다른 터미널의 node 서버를 종료하거나, .env에 PORT=3001 처럼 다른 포트를 지정하세요.`
    );
    process.exit(1);
  }
  throw err;
});
