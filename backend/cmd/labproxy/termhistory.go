package main

import (
	"context"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// Terminal history ring buffer (docs/labs.md "Terminal history source"): the
// terminal relay records recent PTY output per session so the AI hint and
// diagnosis prompts can see what the student actually ran and got back.
// Stored as a bounded Redis list of chunks (newest first), keyed by session
// id, expiring on its own. Must match labs.TerminalHistoryKeyPrefix.
const (
	termHistoryKeyPrefix = "lab:term:"
	// termHistoryMaxChunks × termChunkBytes bounds one session's history
	// (~200 KB worst case; hint prompts only ever read the last ~4 KB).
	termHistoryMaxChunks = 100
	termChunkBytes       = 2048
	termHistoryTTL       = 2 * time.Hour
	termFlushInterval    = 2 * time.Second
	// ttydOutputPrefix is the first byte of a ttyd server->client OUTPUT frame.
	ttydOutputPrefix = '0'
)

// termRecorder buffers a session's terminal output and flushes it to Redis
// in bounded chunks. Used by exactly one relay goroutine — not thread-safe.
type termRecorder struct {
	rdb       *redis.Client
	key       string
	buf       []byte
	lastFlush time.Time
}

func newTermRecorder(rdb *redis.Client, sessionID string) *termRecorder {
	return &termRecorder{rdb: rdb, key: termHistoryKeyPrefix + sessionID, lastFlush: time.Now()}
}

// record takes one raw ttyd frame; only output frames are kept.
func (t *termRecorder) record(frame []byte) {
	if len(frame) < 2 || frame[0] != ttydOutputPrefix {
		return
	}
	t.buf = append(t.buf, frame[1:]...)
	if len(t.buf) >= termChunkBytes || time.Since(t.lastFlush) >= termFlushInterval {
		t.flush()
	}
}

// flush pushes the buffered output (split into <= termChunkBytes chunks),
// trims the list, and refreshes its TTL. Best-effort: history is a hint aid,
// never worth failing or slowing the terminal.
func (t *termRecorder) flush() {
	if len(t.buf) == 0 {
		return
	}
	data := t.buf
	t.buf = nil
	t.lastFlush = time.Now()

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	pipe := t.rdb.Pipeline()
	for len(data) > 0 {
		n := min(len(data), termChunkBytes)
		pipe.LPush(ctx, t.key, string(data[:n]))
		data = data[n:]
	}
	pipe.LTrim(ctx, t.key, 0, termHistoryMaxChunks-1)
	pipe.Expire(ctx, t.key, termHistoryTTL)
	if _, err := pipe.Exec(ctx); err != nil {
		slog.Warn("labproxy: terminal history flush", "key", t.key, "error", err)
	}
}
