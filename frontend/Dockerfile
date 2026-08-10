# syntax=docker/dockerfile:1
# ─── Stage 1: Install dependencies ──────────────────────────────────────────
FROM node:26-alpine AS deps

# This project is pnpm-managed (pnpm-lock.yaml, pnpm-workspace.yaml). Node
# stopped bundling corepack as of 25.0.0 (nodejs/node TSC vote, March 2025) —
# install it explicitly, then let it auto-resolve to the pnpm version pinned
# in package.json's "packageManager" field (see COPY below) — no version
# duplicated here.
RUN npm install -g corepack@latest && corepack enable

WORKDIR /app

# Copy lockfile + package.json first for layer caching — corepack reads
# package.json's "packageManager" field to activate the exact pnpm version
# the lockfile/pnpm-workspace.yaml (allowBuilds) were generated with.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Cache mount keeps pnpm's content-addressable store across builds/retries —
# without it, a flaky/slow registry connection means every retry re-downloads
# all ~700 packages from scratch instead of resuming from what's already local.
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# ─── Stage 2: Build ──────────────────────────────────────────────────────────
FROM node:26-alpine AS builder

RUN npm install -g corepack@latest && corepack enable

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* vars are inlined into the client bundle at build time — they
# must be passed as build args (see docker-compose.prod.yml `build.args`),
# not just as container-runtime env vars.
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_APP_URL
ARG NEXT_PUBLIC_MEDIA_URL
ARG NEXT_PUBLIC_LAB_PROXY_URL
ARG NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED
ARG NEXT_PUBLIC_GITHUB_OAUTH_ENABLED
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL \
    NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL \
    NEXT_PUBLIC_MEDIA_URL=$NEXT_PUBLIC_MEDIA_URL \
    NEXT_PUBLIC_LAB_PROXY_URL=$NEXT_PUBLIC_LAB_PROXY_URL \
    NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED=$NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED \
    NEXT_PUBLIC_GITHUB_OAUTH_ENABLED=$NEXT_PUBLIC_GITHUB_OAUTH_ENABLED

# Next.js standalone output bundles only the files needed to run the server.
# Set in next.config.ts: output: 'standalone'
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# ─── Stage 3: Production runtime ─────────────────────────────────────────────
FROM node:26-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy standalone server and static assets
COPY --from=builder /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Next.js stores its runtime prerender cache under .next; the non-root server
# user must own that directory.
RUN chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
