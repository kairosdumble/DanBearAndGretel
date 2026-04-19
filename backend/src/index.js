require("dotenv").config();

const express = require("express");
const cors = require("cors");

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "dangretel-api" });
});

app.get("/", (_req, res) => {
  res.json({ message: "Dangretel API" });
});

const server = app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server listening on http://localhost:${port}`);
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
