# ---- Build stage ----
FROM node:20-alpine AS builder
WORKDIR /app

RUN apk add --no-cache openssl libc6-compat python3 make g++
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi

COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- Runtime stage ----
FROM node:20-alpine
WORKDIR /app

RUN apk add --no-cache openssl libc6-compat tini
ENV NODE_ENV=production

COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev --no-audit --no-fund; else npm install --omit=dev --no-audit --no-fund; fi

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=builder /app/src/admin/admin.graphql ./dist/admin/admin.graphql
COPY prisma ./prisma

# Run as the unprivileged `node` user shipped with the official image.
# Hand ownership of the app dir to `node` (the COPY layers above ran as root),
# then drop privileges for the rest of the runtime.
RUN chown -R node:node /app
USER node

EXPOSE 4000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -q --spider http://localhost:4000/health || exit 1

ENTRYPOINT ["/sbin/tini","--"]
CMD ["node", "dist/main.js"]
