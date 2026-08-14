const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
const config = require('../config');

const client = new SQSClient({ region: config.resourceRegion });

async function enqueueReview(review) {
  if (!config.reviewModerationQueueUrl) {
    throw new Error('REVIEW_MODERATION_QUEUE_URL is not configured');
  }
  await client.send(new SendMessageCommand({
    QueueUrl: config.reviewModerationQueueUrl,
    MessageBody: JSON.stringify({
      userId: review.userId,
      productId: review.productId,
      rating: review.rating,
      text: review.text,
      authorNickname: review.authorNickname,
      photoKey: review.photoKey,
      imageMimeType: review.imageMimeType,
      requestType: 'CREATE',
    }),
  }));
}

module.exports = { enqueueReview };
