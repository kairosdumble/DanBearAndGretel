const { GoogleGenAI } = require('@google/genai');

const PROMPT = `
[역할 정의]
너는 OCR(광학 문자 인식) 및 데이터 추출 전문가야.
제공된 택시 미터기 이미지를 분석하여 다른 불필요한 문자나 설명 없이 오직 '숫자 데이터'만 정확하게 추출해야 해.

[추출 규칙]
1. 오직 숫자만 출력해. 숫자에 포함된 기호(콤마 ',', 마침표 '.','원', 'km', '분' 등의 단위나 텍스트)는 모두 제외한다.
2. 만약 이미지에서 해당 항목이 보이지 않거나 판별할 수 없다면 '미검출'로 표시해라.

[출력 양식]
1. 오직 지불금액 숫자만 출력한다.
2. 앞뒤로 어떠한 추가 설명(예: "네, 추출한 결과입니다" 등)도 작성하지 마라.
`.trim();

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

function createGeminiClient() {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY가 설정되지 않았습니다.');
  }
  return new GoogleGenAI({ apiKey });
}

function parseGeminiApiError(error) {
  const raw = error?.message || String(error);
  let apiError = null;

  try {
    const jsonStart = raw.indexOf('{');
    if (jsonStart >= 0) {
      apiError = JSON.parse(raw.slice(jsonStart))?.error;
    }
  } catch (_) {}

  const code = apiError?.code ?? error?.status;
  const message = apiError?.message || raw;

  if (message.includes('API key expired') || message.includes('API_KEY_INVALID')) {
    return 'Gemini API 키가 만료되었거나 유효하지 않습니다. Google AI Studio에서 새 키를 발급해 GEMINI_API_KEY를 교체하세요.';
  }
  if (code === 429) {
    return 'Gemini API 요청 한도를 초과했습니다. 잠시 후 다시 시도하거나 Google AI Studio 사용량을 확인하세요.';
  }
  if (code === 403 && message.includes('denied access')) {
    return `현재 Google 프로젝트에서 ${GEMINI_MODEL} 모델 사용이 거부되었습니다. GEMINI_MODEL을 gemini-2.0-flash로 설정하거나 Google AI Studio에서 프로젝트 상태를 확인하세요.`;
  }
  if (code === 403) {
    return 'Gemini API 권한이 없습니다. Google AI Studio에서 API 키와 프로젝트 상태를 확인하세요.';
  }

  return message;
}

const extractTaxiFare = async (imageBuffer, mimeType) => {
  try {
    const ai = createGeminiClient();
    const normalizedMimeType =
      mimeType && mimeType.startsWith('image/')
        ? mimeType
        : 'image/jpeg';

    const response = await ai.models.generateContent({
      model: GEMINI_MODEL,
      contents: [
        { text: PROMPT },
        {
          inlineData: {
            mimeType: normalizedMimeType,
            data: imageBuffer.toString('base64'),
          },
        },
      ],
    });

    const fareText = response.text?.trim();
    const fare = parseInt(fareText, 10);

    if (isNaN(fare)) {
      throw new Error('금액을 인식하지 못했습니다.');
    }

    return fare;
  } catch (error) {
    console.error('Gemini Service Error:', error);
    throw new Error(parseGeminiApiError(error));
  }
};

module.exports = { extractTaxiFare, GEMINI_MODEL };
