const { Pool } = require("pg");

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error("DATABASE_URL 환경변수가 설정되지 않았습니다.");
}

const pool = new Pool({
  connectionString: databaseUrl,
  ssl: databaseUrl.includes("render.com") ? { rejectUnauthorized: false } : false,
  connectionTimeoutMillis: 10000,
  idleTimeoutMillis: 30000,
  keepAlive: true,
});

pool.on("error", (error) => {
  console.error(
    "[postgres] idle client connection error:",
    error.code || error.message,
  );
});

module.exports = pool;
