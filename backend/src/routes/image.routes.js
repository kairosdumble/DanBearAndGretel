const path = require("path");
const express = require("express");
//사진, 동영상, PDF 같은 파일은 용량이 크고 데이터가 아주 복잡한 덩어리 형태로 쪼개져서 넘어옵니다.->multer를 사용하여 파일을 업로드
const multer = require("multer");
const { authenticate } = require("../middleware/auth.middleware");
const imageUploadController = require("../controllers/image.controller");
const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    // 1. 허용할 확장자 정규식 (heic, heif 추가)
    const filetypes = /jpeg|jpg|png|gif|webp|heic|heif/;
    
    // 2. 파일 확장자 테스트
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    
    // 3. Mimetype 테스트 (mimetype이 없을 경우를 대비해 확장자와 교차 검증)
    const mimetype = filetypes.test(file.mimetype) || file.mimetype === 'application/octet-stream';

    if (extname && mimetype) {
      return cb(null, true);
    } else {
      cb(new Error("이미지 파일(jpg, png, gif, heic 등)만 업로드할 수 있습니다."));
    }
  }
});

router.post("/profile/upload",authenticate,(req, res, next) => {
    upload.single("image")(req, res, (err) => {
      if (err) {
        const message = err.code === "LIMIT_FILE_SIZE"
            ? "이미지 크기는 5MB 이하여야 합니다." : err.message || "이미지 업로드에 실패했습니다.";
        return res.status(400).json({ message });
      }
      next();//다음 미들웨어 실행
    });
  },
  imageUploadController.uploadProfileImage,
);

router.post("/taxi_meter/upload",authenticate,(req, res, next) => {
    upload.single("image")(req, res, (err) => {
      if (err) {
        const message = err.code === "LIMIT_FILE_SIZE"
            ? "이미지 크기는 5MB 이하여야 합니다." : err.message || "이미지 업로드에 실패했습니다.";
        return res.status(400).json({ message });
      }
      next();//다음 미들웨어 실행
    });
  },
  imageUploadController.uploadTaxiMeterImage,
);

router.post("/taxi_meter/extract",authenticate,(req, res, next) => {
    upload.single("image")(req, res, (err) => {
      if (err) {
        const message = err.code === "LIMIT_FILE_SIZE"
            ? "이미지 크기는 5MB 이하여야 합니다." : err.message || "이미지 업로드에 실패했습니다.";
        return res.status(400).json({ message });
      }
      next();//다음 미들웨어 실행
    });
  },
  imageUploadController.extractTaxiMeterImage
);

module.exports = router;
