FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./
# npm ci requires package-lock.json; fall back to npm install if it doesn't exist yet
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi

FROM base AS final
COPY src/ ./src/
ARG APP_VERSION=1.0.0
ARG BUILD_TIME=unknown
ARG COMMIT_SHA=unknown
ENV APP_VERSION=$APP_VERSION
ENV BUILD_TIME=$BUILD_TIME
ENV COMMIT_SHA=$COMMIT_SHA
EXPOSE 3000
CMD ["node", "src/app.js"]
