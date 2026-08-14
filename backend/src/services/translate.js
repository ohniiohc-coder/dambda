const { TranslateClient, TranslateTextCommand } = require('@aws-sdk/client-translate');
const config = require('../config');

const PRODUCT_LANGUAGES = ['en', 'ja', 'zh'];
const PRODUCT_FIELDS = ['name', 'reason', 'store', 'discountInfo'];

function createTranslateService(client) {
  // 리뷰처럼 원문 언어를 모를 때는 auto, 한국어 상품처럼 알 때는 ko를 명시한다.
  // auto일 때: 짧거나 애매한 텍스트는 언어 자동판별 신뢰도가 낮아
  // DetectedLanguageLowConfidenceException이 남 - 예외에 실려오는 감지 언어로 한 번 더 시도함
  // (review_moderation Lambda와 동일 이슈/해법)
  async function translateText(text, targetLang, sourceLang = 'auto') {
    try {
      const result = await client.send(
        new TranslateTextCommand({
          Text: text,
          SourceLanguageCode: sourceLang,
          TargetLanguageCode: targetLang,
        })
      );
      return { translatedText: result.TranslatedText, sourceLang: result.SourceLanguageCode };
    } catch (err) {
      if (sourceLang === 'auto' && err.name === 'DetectedLanguageLowConfidenceException' && err.DetectedLanguageCode) {
        if (err.DetectedLanguageCode === targetLang) {
          return { translatedText: text, sourceLang: targetLang };
        }
        const retry = await client.send(
          new TranslateTextCommand({
            Text: text,
            SourceLanguageCode: err.DetectedLanguageCode,
            TargetLanguageCode: targetLang,
          })
        );
        return { translatedText: retry.TranslatedText, sourceLang: err.DetectedLanguageCode };
      }
      throw err;
    }
  }

  async function translateProduct(fields) {
    const languageEntries = await Promise.all(
      PRODUCT_LANGUAGES.map(async (language) => {
        const fieldEntries = await Promise.all(
          PRODUCT_FIELDS.map(async (field) => {
            const value = fields[field];
            if (!value || !String(value).trim()) return null;
            const { translatedText } = await translateText(String(value), language, 'ko');
            return [field, translatedText];
          })
        );
        return [language, Object.fromEntries(fieldEntries.filter(Boolean))];
      })
    );
    return Object.fromEntries(languageEntries);
  }

  return { translateText, translateProduct };
}

const service = createTranslateService(new TranslateClient({ region: config.awsRegion }));

module.exports = { ...service, createTranslateService };
