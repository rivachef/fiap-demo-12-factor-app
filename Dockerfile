# syntax=docker/dockerfile:1
FROM node:20-alpine AS base
WORKDIR /app
ENV NODE_ENV=production

# Install dependencies
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi

# Copy source
COPY src ./src

EXPOSE 3000
CMD ["node", "src/index.js"]
