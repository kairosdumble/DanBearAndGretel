const pool = require("../db/pool");
const { GoogleGenAI } = require('@google/genai');

// API 키는 환경변수에서 관리하세요.
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const extractTaxiFare = async (imageBuffer, mimeType) => {
  try {
    // 1. 이미지를 Gemini가 이해할 수 있는 멀티모달 데이터로 변환
    const promptPart = {
      type: 'text',
      text: `
        [역할 정의]
        너는 OCR(광학 문자 인식) 및 데이터 추출 전문가야. 
        제공된 택시 미터기 이미지(또는 텍스트)를 분석하여 다른 불필요한 문자나 설명 없이 오직 '숫자 데이터'만 정확하게 추출해야 해.

        [추출 규칙]
        1. 오직 숫자만 출력해. 숫자에 포함된 기호(콤마 ',', 마침표 '.','원', 'km', '분' 등의 단위나 텍스트)는 모두 제외한다.
        2. 만약 이미지에서 해당 항목이 보이지 않거나 판별할 수 없다면 '미검출'로 표시해라.

        [입력 데이터]
        택시 미터기 사진

        [출력 양식]
        1. 오직 지불금액 숫자만 출력한다 2. 앞뒤로 어떠한 추가 설명(예: "네, 추출한 결과입니다" 등)도 작성하지 마라.
      `,
    };

    const imagePart = {
      type: 'image',
      data: imageBuffer.toString("base64"),
      mime_type: mimeType,
    };

    // 2. Gemini API 호출
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [promptPart, imagePart],
    });

    // 3. 결과 공백 제거 및 반환
    const fareText = response.text?.trim();
    const fare = parseInt(fareText, 10);

    if (isNaN(fare)) {
      throw new Error("금액을 인식하지 못했습니다.");
    }

    return fare;
  } catch (error) {
    console.error("Gemini Service Error:", error);
    throw error;
  }
};
module.exports = { extractTaxiFare };