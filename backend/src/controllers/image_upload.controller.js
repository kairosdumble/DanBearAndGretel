// 사용자에게 받은 프로필 이미지를 Supabase Storage에 안전하게 저장(업로드)한 뒤 
// 그 이미지에 접근할 수 있는 '주소(URL)'를 가져와서 우리 데이터베이스(DB)에 기록

const path = require("path");
const pool = require('../db/pool');
const supabase = require("../lib/supabase");
const BUCKET = process.env.SUPABASE_PROFILE_BUCKET;

async function uploadProfileImage(req, res) {
  try {
    // Supabase 클라이언트가 제대로 설정되어 있는지 확인
    if (!supabase) {
      return res.status(503).json({
        message: "Supabase 설정이 없어 이미지 업로드를 사용할 수 없습니다.",
      });
    }

    // 사용자가 진짜로 이미지 파일을 보냈는지 확인
    if (!req.file) {
      return res.status(400).json({ message: "이미지 파일이 필요합니다." });
    }

    const userId = req.user.id;
    const ext = path.extname(req.file.originalname); // 확장자 추출
    const filePath = `profiles/${userId}/${req.file.originalname}`;

    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(filePath, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: true,
      });

    if (uploadError) {
      console.error("Supabase upload error:", uploadError);
      const isRlsError =
        uploadError.message?.includes("row-level security") ||
        uploadError.statusCode === "403";
      return res.status(500).json({
        message: isRlsError
          ? "Supabase Storage 권한 오류입니다. service_role 키와 버킷 정책을 확인하세요."
          : "이미지 업로드에 실패했습니다.",
        detail: uploadError.message,
      });
    } 

    const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(filePath);
    const imageUrl = urlData.publicUrl;

    const result = await pool.query(
      `UPDATE users
       SET profile_image_url = $1
       WHERE id = $2
       RETURNING profile_image_url`,
      [imageUrl, userId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "사용자를 찾을 수 없습니다." });
    }

    return res.status(200).json({ imageUrl });
  } catch (error) {
    console.error("uploadTaxiMeterImage 에러:", error);
    const isMissingColumn = error.message?.includes("taxi_meter_image_url");
    return res.status(500).json({
      message: isMissingColumn
        ? "DB에 taxi_meter_image_url 컬럼이 없습니다. 서버를 재시작해 스키마를 동기화하세요."
        : "서버 오류가 발생했습니다.",
      detail: error.message,
    });
  }
};

async function uploadTaxiMeterImage(req, res) {
  try {
    // Supabase 클라이언트가 제대로 설정되어 있는지 확인
    if (!supabase) {
      return res.status(503).json({
        message: "Supabase 설정이 없어 이미지 업로드를 사용할 수 없습니다.",
      });
    }

    // 사용자가 진짜로 이미지 파일을 보냈는지 확인
    if (!req.file) {
      return res.status(400).json({ message: "이미지 파일이 필요합니다." });
    }

    const userId = req.user.id;
    const ext = path.extname(req.file.originalname); // 확장자 추출
    const filePath = `taxi_meters/${userId}/${req.file.originalname}`;

    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(filePath, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: true,
      });

    if (uploadError) {
      console.error("Supabase upload error:", uploadError);
      const isRlsError =
        uploadError.message?.includes("row-level security") ||
        uploadError.statusCode === "403";
      return res.status(500).json({
        message: isRlsError
          ? "Supabase Storage 권한 오류입니다. service_role 키와 버킷 정책을 확인하세요."
          : "이미지 업로드에 실패했습니다.",
        detail: uploadError.message,
      });
    } 

    const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(filePath);
    const imageUrl = urlData.publicUrl;

    const result = await pool.query(
      `INSERT INTO payments (reservation_id, final_user_id, taximeter_image_url)
       VALUES ($1, $2, $3)
       RETURNING taximeter_image_url`,
     [req.body.reservation_id, userId, imageUrl], // 미터기를 찍는 사람이 최종하차자임으로 userIdd

    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "사용자를 찾을 수 없습니다." });
    }

    return res.status(200).json({ imageUrl });
  } catch (error) {
    console.error("uploadTaxiMeterImage 에러:", error);
    const isMissingColumn = error.message?.includes("taxi_meter_image_url");
    return res.status(500).json({
      message: isMissingColumn
        ? "DB에 taxi_meter_image_url 컬럼이 없습니다. 서버를 재시작해 스키마를 동기화하세요."
        : "서버 오류가 발생했습니다.",
      detail: error.message,
    });
  }
};

module.exports = {
  uploadProfileImage,
  uploadTaxiMeterImage,
}