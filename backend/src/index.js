require("dotenv").config();

const express = require("express");
const cors = require("cors");

const app = express();
const port = Number(process.env.PORT) || 3000;
const tmapApiKey = process.env.TMAP_API_KEY || process.env.TMAP_APP_KEY || "";
const tmapPoiBaseUrl = "https://apis.openapi.sk.com/tmap/pois";
const searchTimeoutMs = Number(process.env.SEARCH_TIMEOUT_MS) || 5000;
const defaultSearchCount = Number(process.env.SEARCH_COUNT) || 20;

app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "dangretel-api" });
});

app.get("/", (_req, res) => {
  res.json({ message: "Dangretel API" });
});

function buildTmapPoiUrl(query) {
  const url = new URL(tmapPoiBaseUrl);
  url.searchParams.set("version", "1");
  url.searchParams.set("format", "json");
  url.searchParams.set("count", String(defaultSearchCount));
  url.searchParams.set("searchKeyword", query);
  url.searchParams.set("reqCoordType", "WGS84GEO");
  url.searchParams.set("resCoordType", "WGS84GEO");
  return url;
}

function parseNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function firstItem(value) {
  if (Array.isArray(value)) {
    return value[0] || null;
  }
  return value && typeof value === "object" ? value : null;
}

function buildRoadAddress(poi) {
  const newAddress = firstItem(poi?.newAddressList?.newAddress);
  if (newAddress?.fullAddressRoad) {
    return String(newAddress.fullAddressRoad).trim();
  }

  const parts = [
    poi?.upperAddrName,
    poi?.middleAddrName,
    poi?.lowerAddrName,
    poi?.detailAddrName,
  ]
    .map((part) => String(part || "").trim())
    .filter(Boolean);

  const lotNo = [poi?.firstNo, poi?.secondNo]
    .map((part) => String(part || "").trim())
    .filter(Boolean)
    .join("-");

  if (lotNo) {
    parts.push(lotNo);
  }

  return parts.join(" ").trim();
}

function normalizePoi(poi, index) {
  const latitude =
    parseNumber(poi?.frontLat) ??
    parseNumber(poi?.noorLat) ??
    parseNumber(poi?.lat);
  const longitude =
    parseNumber(poi?.frontLon) ??
    parseNumber(poi?.noorLon) ??
    parseNumber(poi?.lon);

  if (latitude == null || longitude == null) {
    return null;
  }

  const name = String(poi?.name || "").trim();
  if (!name) {
    return null;
  }

  return {
    id: String(poi?.id || `poi_${index}`),
    name,
    roadAddress: buildRoadAddress(poi) || name,
    distanceMeters: 0,
    lat: latitude,
    lng: longitude,
  };
}

function extractPois(payload) {
  const pois = payload?.searchPoiInfo?.pois?.poi;
  if (Array.isArray(pois)) {
    return pois;
  }
  if (pois && typeof pois === "object") {
    return [pois];
  }
  return [];
}

async function searchTmapPois(query) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), searchTimeoutMs);
  const url = buildTmapPoiUrl(query);

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: {
        accept: "application/json",
        appKey: tmapApiKey,
      },
      signal: controller.signal,
    });

    const rawText = await response.text();
    let payload = null;

    try {
      payload = rawText ? JSON.parse(rawText) : null;
    } catch {
      payload = null;
    }

    if (!response.ok) {
      const upstreamMessage =
        payload?.error?.message ||
        payload?.error?.code ||
        rawText ||
        response.statusText;
      const error = new Error(
        `TMAP POI search failed (${response.status}): ${upstreamMessage}`,
      );
      error.statusCode = response.status;
      error.upstreamBody = rawText;
      error.upstreamUrl = url.toString();
      throw error;
    }

    return extractPois(payload)
      .map(normalizePoi)
      .filter(Boolean);
  } finally {
    clearTimeout(timeout);
  }
}

app.get("/places/search", async (req, res) => {
  const query = String(req.query.q || "").trim();

  if (query.length < 2) {
    return res.json({ items: [] });
  }

  if (!tmapApiKey) {
    return res.status(500).json({
      error: "TMAP_API_KEY is not configured.",
    });
  }

  try {
    const items = await searchTmapPois(query);
    return res.json({ items });
  } catch (error) {
    const isAbortError = error?.name === "AbortError";
    const statusCode = isAbortError ? 504 : 502;

    console.error("[places/search]", error);

    return res.status(statusCode).json({
      error: isAbortError
        ? "TMAP place search timed out."
        : "TMAP place search failed.",
      detail: error?.message || String(error),
      upstreamStatus: error?.statusCode ?? null,
    });
  }
});

const server = app.listen(port, () => {
  console.log(`Server listening on http://localhost:${port}`);
});

server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.error(
      `[EADDRINUSE] Port ${port} is already in use. Stop the other server or change PORT in .env.`,
    );
    process.exit(1);
  }
  throw err;
});
