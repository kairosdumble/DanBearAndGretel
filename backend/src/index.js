require("dotenv").config();

const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const authRoutes = require("./routes/auth.routes");

const app = express();
const port = Number(process.env.PORT) || 3000;
const databaseUrl = process.env.DATABASE_URL;



if (!databaseUrl) {
  throw new Error("DATABASE_URL 환경변수가 설정되지 않았습니다.");
}

const pool = new Pool({
  connectionString: databaseUrl,
});

app.use(cors());
app.use(express.json());
app.use("/auth", authRoutes);

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

async function startServer() {
  try {
    await pool.query("SELECT NOW()");
    // eslint-disable-next-line no-console
    console.log("PostgreSQL connected successfully.");
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("PostgreSQL connection failed.");
    // eslint-disable-next-line no-console
    console.error(error.message);
    process.exit(1);
  }

  const server = app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(`Server listening on http://localhost:${port}`);
  });

  server.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      // eslint-disable-next-line no-console
      console.error(
        `[EADDRINUSE] 포트 ${port}가 이미 사용 중입니다. 다른 터미널의 node 서버를 종료해주세요.`
      );
      process.exit(1);
    }
    throw err;
  });
}

startServer();
process.on("SIGINT", async () => {
  await pool.end();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await pool.end();
  process.exit(0);
});
