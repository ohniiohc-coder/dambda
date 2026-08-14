FROM node:20-alpine

WORKDIR /app

# Keep dependency installation cached until the lockfile changes, and do not
# retain npm's download cache in the runtime image.
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund \
  && npm cache clean --force

COPY src ./src

EXPOSE 80
ENV PORT=80
CMD ["node", "src/server.js"]
