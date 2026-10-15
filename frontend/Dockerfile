# syntax=docker/dockerfile:1
# ─── Stage 1: Install dependencies ──────────────────────────────────────────
FROM node:26-alpine AS deps

# Bun does the installs (much faster than pnpm); Node still runs next build
# and the runtime. Copy the musl bun binary from the official alpine image.
COPY --from=oven/bun:1.3.14-alpine /usr/local/bin/bun /usr/local/bin/bun

WORKDIR /app

COPY package.json bun.lock ./

# Cache mount keeps bun's package cache across builds/retries, so a flaky
# registry connection doesn't re-download every package from scratch.
RUN --mount=type=cache,id=bun-cache,target=/root/.bun/install/cache     bun install --frozen-lockfile

# ─── Stage 2: Build ──────────────────────────────────────────────────────────
FROM node:26-alpine AS builder

COPY --from=oven/bun:1.3.14-alpine /usr/local/bin/bun /usr/local/bin/bun

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
# Cache mount persists Next's compile cache (.next/cache) so unchanged modules
# aren't recompiled on every build; it stays out of the image layers.
RUN --mount=type=cache,id=next-cache,target=/app/.next/cache \
    bun run build

# ─── Stage 3: Production runtime ─────────────────────────────────────────────
FROM node:26-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy standalone server and static assets
# --chown on each COPY instead of a trailing `chown -R /app`, which would
# duplicate the whole tree into another layer. Next.js writes its runtime
# prerender cache under .next, so the non-root server user must own it.
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
