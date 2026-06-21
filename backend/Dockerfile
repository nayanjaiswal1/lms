# ─── Stage 1: Build ──────────────────────────────────────────────────────────
FROM golang:1.26-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /build

# Download dependencies first (layer caching — only re-runs when go.mod/go.sum change)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and compile
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /bin/server ./cmd/server

# ─── Stage 2: Minimal runtime ────────────────────────────────────────────────
FROM alpine:3.19

# CA certs for outbound HTTPS (OAuth, SMTP, MaxMind) and timezone data
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /bin/server /app/server

EXPOSE 8080

ENTRYPOINT ["/app/server"]
