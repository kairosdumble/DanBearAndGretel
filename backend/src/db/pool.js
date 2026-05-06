const { Pool } = require("pg");

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("DATABASE_URL 환경변수가 설정되지 않았습니다.");
}
const pool = new Pool({
  connectionString: databaseUrl,
  // Render DB 접속을 위해 SSL 설정 추가
  ssl: databaseUrl.includes("render.com") ? { rejectUnauthorized: false } : false,
});

module.exports = pool;