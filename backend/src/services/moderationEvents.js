const crypto = require('crypto');
const { PutCommand, GetCommand, ScanCommand, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const config = require('../config');
const client = require('./dynamoClient');

async function createEvent(input) {
  const now = new Date();
  const event = {
    eventId: crypto.randomUUID(),
    status: 'BLOCKED',
    createdAt: now.toISOString(),
    expiresAt: Math.floor(now.getTime() / 1000) + (30 * 24 * 60 * 60),
    ...input,
  };
  await client.send(new PutCommand({ TableName: config.moderationEventsTableName, Item: event }));
  return event;
}

async function getEvent(eventId) {
  const result = await client.send(new GetCommand({
    TableName: config.moderationEventsTableName,
    Key: { eventId },
  }));
  return result.Item;
}

async function listEvents() {
  const items = [];
  let ExclusiveStartKey;
  do {
    const result = await client.send(new ScanCommand({
      TableName: config.moderationEventsTableName,
      ExclusiveStartKey,
    }));
    items.push(...(result.Items || []));
    ExclusiveStartKey = result.LastEvaluatedKey;
  } while (ExclusiveStartKey);
  return items
    .filter((item) => item.status !== 'DELETED')
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
}

async function updateStatus(eventId, status) {
  const result = await client.send(new UpdateCommand({
    TableName: config.moderationEventsTableName,
    Key: { eventId },
    UpdateExpression: 'SET #status = :status, reviewedAt = :reviewedAt',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':status': status, ':reviewedAt': new Date().toISOString() },
    ReturnValues: 'ALL_NEW',
  }));
  return result.Attributes;
}

async function markDeleted(eventId) {
  const result = await client.send(new UpdateCommand({
    TableName: config.moderationEventsTableName,
    Key: { eventId },
    UpdateExpression: 'SET #status = :status, notificationMessage = :message, notificationRead = :unread, reviewedAt = :reviewedAt REMOVE quarantineKey',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':status': 'DELETED',
      ':message': '해당 게시물은 관리자에 의해 삭제되었습니다.',
      ':unread': false,
      ':reviewedAt': new Date().toISOString(),
    },
    ReturnValues: 'ALL_NEW',
  }));
  return result.Attributes;
}

async function createDeletionNotification(review) {
  return createEvent({
    userId: review.userId,
    productId: review.productId,
    text: review.text,
    requestType: 'ADMIN_REVIEW_DELETE',
    status: 'DELETED',
    notificationMessage: '해당 게시물은 관리자에 의해 삭제되었습니다.',
    notificationRead: false,
    reasons: ['admin_deleted'],
    findings: [],
  });
}

async function listUnreadNotifications(userId) {
  const result = await client.send(new QueryCommand({
    TableName: config.moderationEventsTableName,
    IndexName: 'moderation-events-by-user',
    KeyConditionExpression: 'userId = :userId',
    FilterExpression: '#status = :deleted AND notificationRead = :unread',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':userId': userId,
      ':deleted': 'DELETED',
      ':unread': false,
    },
    ScanIndexForward: false,
  }));
  return result.Items || [];
}

async function markNotificationRead(eventId, userId) {
  await client.send(new UpdateCommand({
    TableName: config.moderationEventsTableName,
    Key: { eventId },
    UpdateExpression: 'SET notificationRead = :read, notificationReadAt = :readAt',
    ConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':read': true,
      ':readAt': new Date().toISOString(),
      ':userId': userId,
    },
  }));
}

module.exports = {
  createEvent,
  getEvent,
  listEvents,
  updateStatus,
  markDeleted,
  createDeletionNotification,
  listUnreadNotifications,
  markNotificationRead,
};
