require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// .env에 저장된 DATABASE_URL 사용 (Render 전용)
const client = new Client({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' 
  ? { rejectUnauthorized: false } 
  : false // Render DB 접속 필수 설정
});

async function run() {
  try {
    await client.connect();
    console.log("DB 연결 성공 (마이그레이션 시작)");

    // schema.sql 읽어오기
    const sqlPath = path.join(__dirname, 'schema.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    // SQL 실행
    await client.query(sql);
    console.log("DB 테이블 동기화 완료!");
  } catch (err) {
    console.error("마이그레이션 에러:", err);
  } finally {
    await client.end();
  }
}

run();