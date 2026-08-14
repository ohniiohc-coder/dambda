const crypto = require('crypto');
const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  CopyObjectCommand,
  DeleteObjectCommand,
} = require('@aws-sdk/client-s3');
const config = require('../config');

const client = new S3Client({ region: config.resourceRegion });

function extensionFor(mimeType) {
  if (mimeType === 'image/png') return 'png';
  if (mimeType === 'image/webp') return 'webp';
  return 'jpg';
}

async function uploadReviewPhoto(buffer, mimeType) {
  const key = `reviews/${crypto.randomUUID()}.${extensionFor(mimeType)}`;
  await client.send(
    new PutObjectCommand({
      Bucket: config.reviewPhotosBucket,
      Key: key,
      Body: buffer,
      ContentType: mimeType,
    })
  );
  return {
    bucket: config.reviewPhotosBucket,
    key,
    url: `https://${config.reviewPhotosDomain}/${key}`,
  };
}

async function deleteReviewPhoto(key) {
  await client.send(
    new DeleteObjectCommand({
      Bucket: config.reviewPhotosBucket,
      Key: key,
    })
  );
}

async function uploadQuarantinePhoto(buffer, mimeType) {
  const key = `reviews/${crypto.randomUUID()}.${extensionFor(mimeType)}`;
  await client.send(new PutObjectCommand({
    Bucket: config.moderationQuarantineBucket,
    Key: key,
    Body: buffer,
    ContentType: mimeType,
  }));
  return { bucket: config.moderationQuarantineBucket, key, mimeType };
}

async function promoteQuarantinePhoto(photo) {
  await client.send(new CopyObjectCommand({
    Bucket: config.reviewPhotosBucket,
    Key: photo.key,
    CopySource: `${photo.bucket}/${photo.key}`,
    ContentType: photo.mimeType,
    MetadataDirective: 'REPLACE',
  }));
  await deleteQuarantinePhoto(photo.key);
  return {
    bucket: config.reviewPhotosBucket,
    key: photo.key,
    url: `https://${config.reviewPhotosDomain}/${photo.key}`,
  };
}

async function getQuarantinePhoto(key) {
  return client.send(new GetObjectCommand({
    Bucket: config.moderationQuarantineBucket,
    Key: key,
  }));
}

async function deleteQuarantinePhoto(key) {
  if (!key) return;
  await client.send(new DeleteObjectCommand({
    Bucket: config.moderationQuarantineBucket,
    Key: key,
  }));
}

async function uploadProductImage(buffer, mimeType) {
  const key = `products/${crypto.randomUUID()}.${extensionFor(mimeType)}`;
  await client.send(new PutObjectCommand({
    Bucket: config.productImagesBucket,
    Key: key,
    Body: buffer,
    ContentType: mimeType,
  }));
  return {
    key,
    url: `https://${config.productImagesDomain}/${key}`,
  };
}

async function deleteProductImage(key) {
  if (!key) return;
  await client.send(new DeleteObjectCommand({
    Bucket: config.productImagesBucket,
    Key: key,
  }));
}

module.exports = {
  uploadReviewPhoto,
  uploadQuarantinePhoto,
  promoteQuarantinePhoto,
  getQuarantinePhoto,
  deleteQuarantinePhoto,
  deleteReviewPhoto,
  uploadProductImage,
  deleteProductImage,
};
