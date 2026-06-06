# --- build stage: install production deps (incl. native pg) ----------------------
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

# --- runtime stage ---------------------------------------------------------------
FROM node:22-slim
# curl is used by the compose healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json app.js ./
EXPOSE 8000

# Logs go to stdout (console). `--require @opentelemetry/auto-instrumentations-node/register`
# auto-instruments http/express + pg + redis and exports via the OTEL_* env vars
# (no-op when OTEL_SDK_DISABLED=true).
CMD ["node", "--require", "@opentelemetry/auto-instrumentations-node/register", "app.js"]
