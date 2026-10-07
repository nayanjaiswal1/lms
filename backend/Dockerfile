# ─── Stage 1: Build ──────────────────────────────────────────────────────────
FROM golang:1.26.8-alpine AS builder

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

# CA certs for outbound HTTPS (OAuth, SMTP, MaxMind), timezone data, the
# docker CLI (the server shells out to `docker` — internal/labs/container.go —
# to spawn/exec/stop lab sandbox containers via the mounted host socket), and
# poppler-utils' pdftotext (internal/captures/extract.go shells out to it to
# pull text from a captured PDF before AI structuring — a screenshot capture
# is instead sent to the vision-capable LLM directly, no OCR binary needed).
RUN apk add --no-cache ca-certificates tzdata docker-cli poppler-utils

WORKDIR /app

COPY --from=builder /bin/server /app/server

# Run unprivileged (audit H-10). The docker CLI reaches the daemon over TCP
# via DOCKER_HOST (socket proxy), so no docker group membership is needed.
RUN adduser -S -D -H -u 10001 app
USER 10001

EXPOSE 8080

ENTRYPOINT ["/app/server"]
