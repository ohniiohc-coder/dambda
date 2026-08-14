const { TranslateClient, TranslateTextCommand } = require('@aws-sdk/client-translate');
const { ComprehendClient, DetectToxicContentCommand } = require('@aws-sdk/client-comprehend');
const { RekognitionClient, DetectModerationLabelsCommand } = require('@aws-sdk/client-rekognition');
const { S3Client, CopyObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { DynamoDBClient, UpdateItemCommand, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const crypto = require('crypto');

const translate = new TranslateClient({});
const comprehend = new ComprehendClient({ region: 'us-east-1' });
const rekognition = new RekognitionClient({});
const s3 = new S3Client({});
const dynamodb = new DynamoDBClient({});

// EventBridge Pipe(batch_size=1)가 Step Functions에 넘기는 입력은 SQS 레코드 "배열"이고
// (레코드가 1개여도 배열임), Step Functions는 그걸 Payload.$: "$"로 그대로 Lambda에 넘김 -
// 그래서 여기서 받는 input은 레코드 객체가 아니라 [record] 형태임. 배열을 안 풀면
// record.body가 undefined라 아래 JSON.parse 분기를 타지 않고 배열 자체가 review로 취급돼서
// userId/productId/text가 전부 없는 것처럼 보여 "Invalid review moderation message"로 실패함
function message(input) {
  const record = Array.isArray(input) ? input[0] : input;
  return typeof record.body === 'string' ? JSON.parse(record.body) : record;
}

// DetectToxicContent는 영어만 지원하고, SourceLanguageCode: 'auto'는 내부적으로
// comprehend:DetectDominantLanguage를 호출함 - 짧거나 애매한 텍스트("hi", 자모 하나 등)는
// 신뢰도가 낮아 DetectedLanguageLowConfidenceException을 던지므로, 예외에 실려오는 감지
// 언어로 한 번 더 시도함(review_moderation Lambda와 동일 이슈/동일 해법)
async function translateToEnglish(text) {
  try {
    const result = await translate.send(new TranslateTextCommand({
      Text: text,
      SourceLanguageCode: 'auto',
      TargetLanguageCode: 'en',
    }));
    return result.TranslatedText;
  } catch (err) {
    if (err.name === 'DetectedLanguageLowConfidenceException' && err.DetectedLanguageCode) {
      if (err.DetectedLanguageCode === 'en') return text;
      const retry = await translate.send(new TranslateTextCommand({
        Text: text,
        SourceLanguageCode: err.DetectedLanguageCode,
        TargetLanguageCode: 'en',
      }));
      return retry.TranslatedText;
    }
    throw err;
  }
}

async function textResult(text) {
  const translatedText = await translateToEnglish(text);
  const result = await comprehend.send(new DetectToxicContentCommand({
    LanguageCode: 'en',
    TextSegments: [{ Text: translatedText }],
  }));
  const labels = (result.ResultList || []).flatMap((segment) => segment.Labels || []);
  const threshold = Number(process.env.TOXICITY_THRESHOLD);
  return { translatedText, labels, blocked: labels.some((label) => label.Score >= threshold) };
}

async function imageResult(photoKey) {
  if (!photoKey) return { labels: [], blocked: false };
  const result = await rekognition.send(new DetectModerationLabelsCommand({
    Image: { S3Object: { Bucket: process.env.QUARANTINE_BUCKET, Name: photoKey } },
    MinConfidence: Number(process.env.IMAGE_CONFIDENCE_THRESHOLD),
  }));
  return { labels: result.ModerationLabels || [], blocked: (result.ModerationLabels || []).length > 0 };
}

function av(value) { return { S: value }; }

// backend/src/services/moderationEvents.js, admin_screen.dart와 필드명을 맞춤 -
// review_moderation Lambda(동기 경로)가 만드는 이벤트와 스키마가 같아야 관리자 화면이
// 생성 경로(POST 비동기)와 수정 경로(PUT 동기) 이벤트를 구분 없이 렌더링할 수 있음
function finding(source, name, confidence) {
  return { M: { source: av(source), name: av(name), confidence: { N: String(confidence) } } };
}

exports.handler = async (input) => {
  const review = message(input);
  if (!review.userId || !review.productId || !review.text) throw new Error('Invalid review moderation message');

  const [text, image] = await Promise.all([textResult(review.text), imageResult(review.photoKey)]);
  const detectedAt = new Date().toISOString();
  const blocked = text.blocked || image.blocked;

  if (!blocked && review.photoKey) {
    await s3.send(new CopyObjectCommand({
      Bucket: process.env.PUBLIC_REVIEW_BUCKET,
      Key: review.photoKey,
      CopySource: `${process.env.QUARANTINE_BUCKET}/${encodeURIComponent(review.photoKey)}`,
    }));
    await s3.send(new DeleteObjectCommand({ Bucket: process.env.QUARANTINE_BUCKET, Key: review.photoKey }));
  }

  if (blocked) {
    const eventId = crypto.randomUUID();
    const expiresAt = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60);
    await dynamodb.send(new PutItemCommand({
      TableName: process.env.MODERATION_EVENTS_TABLE,
      Item: {
        eventId: av(eventId),
        userId: av(review.userId),
        productId: av(review.productId),
        authorNickname: av(review.authorNickname || ''),
        rating: { N: String(review.rating || 0) },
        text: av(review.text),
        status: av('BLOCKED'),
        createdAt: av(detectedAt),
        requestType: av(review.requestType || 'CREATE'),
        reasons: { L: [
          ...text.labels.filter((label) => label.Score >= Number(process.env.TOXICITY_THRESHOLD)).map((label) => av(`text:${label.Name}`)),
          ...image.labels.map((label) => av(`image:${label.Name}`)),
        ] },
        findings: { L: [
          ...text.labels.map((label) => finding('TEXT', label.Name, label.Score)),
          ...image.labels.map((label) => finding('IMAGE', label.Name, label.Confidence)),
        ] },
        // 사진이 없으면 속성 자체를 안 넣음 - admin_screen.dart의 hasImage 판별이
        // "event['quarantineKey'] != null"이라, 빈 문자열을 넣으면 사진 없는 리뷰도
        // 이미지가 있는 것처럼 오판됨
        ...(review.photoKey ? { quarantineKey: av(review.photoKey) } : {}),
        ...(review.imageMimeType ? { imageMimeType: av(review.imageMimeType) } : {}),
        expiresAt: { N: String(expiresAt) },
      },
    }));
  }

  const status = blocked ? 'REVIEW_REQUIRED' : 'APPROVED';
  const values = { ':status': av(status), ':visible': { BOOL: !blocked }, ':at': av(detectedAt) };
  let expression = 'SET moderationStatus = :status, isVisible = :visible, moderationUpdatedAt = :at';
  if (!blocked && review.photoKey) {
    values[':photoUrl'] = av(`https://${process.env.PUBLIC_REVIEW_BUCKET_DOMAIN}/${review.photoKey}`);
    expression += ', photoUrl = :photoUrl';
  }
  await dynamodb.send(new UpdateItemCommand({
    TableName: process.env.REVIEW_TABLE_NAME,
    Key: { userId: av(review.userId), productId: av(review.productId) },
    UpdateExpression: expression,
    ExpressionAttributeValues: values,
  }));

  return { reviewId: `${review.userId}#${review.productId}`, status, detectedAt };
};
