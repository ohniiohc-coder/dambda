const assert = require('node:assert/strict');
const test = require('node:test');
const { createTranslateService } = require('../src/services/translate');

test('review translation defaults to automatic source-language detection', async () => {
  let input;
  const service = createTranslateService({
    send: async (command) => {
      input = command.input;
      return { TranslatedText: 'hello', SourceLanguageCode: 'ko' };
    },
  });

  const result = await service.translateText('안녕', 'en');

  assert.deepEqual(input, {
    Text: '안녕',
    SourceLanguageCode: 'auto',
    TargetLanguageCode: 'en',
  });
  assert.deepEqual(result, { translatedText: 'hello', sourceLang: 'ko' });
});

test('product translation builds all supported languages from Korean fields', async () => {
  const calls = [];
  const service = createTranslateService({
    send: async (command) => {
      calls.push(command.input);
      return {
        TranslatedText: `${command.input.TargetLanguageCode}:${command.input.Text}`,
        SourceLanguageCode: 'ko',
      };
    },
  });

  const translations = await service.translateProduct({
    name: '상품',
    reason: '추천',
    store: '매장',
    discountInfo: '',
  });

  assert.equal(calls.length, 9);
  assert.ok(calls.every((call) => call.SourceLanguageCode === 'ko'));
  assert.deepEqual(translations.en, {
    name: 'en:상품',
    reason: 'en:추천',
    store: 'en:매장',
  });
  assert.equal(translations.ja.name, 'ja:상품');
  assert.equal(translations.zh.name, 'zh:상품');
});
