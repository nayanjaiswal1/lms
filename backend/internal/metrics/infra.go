package metrics

import (
	"context"
	"net"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/redis/go-redis/v9"
)

// Sub-millisecond floor up to multi-second: the point of these histograms is
// telling "each round trip costs 3ms" apart from "each costs 300ms".
var ioBuckets = []float64{.001, .0025, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5}

var (
	dbQueryDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "mindforge_db_query_duration_seconds",
		Help:    "Postgres query round-trip time as seen by pgx (excludes waiting for a pool connection).",
		Buckets: ioBuckets,
	})
	dbConnectDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "mindforge_db_connect_duration_seconds",
		Help:    "Time to open one new Postgres connection (TCP + TLS + auth).",
		Buckets: ioBuckets,
	})
	redisCmdDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "mindforge_redis_cmd_duration_seconds",
		Help:    "Redis command or pipeline round-trip time.",
		Buckets: ioBuckets,
	})
	redisDialDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "mindforge_redis_dial_duration_seconds",
		Help:    "Time to open one new Redis connection (TCP + TLS).",
		Buckets: ioBuckets,
	})
)

type startKey struct{}

// DBTracer records per-query and per-connect latency. Install it on
// pgxpool.Config.ConnConfig.Tracer before the pool is created.
type DBTracer struct{}

func (DBTracer) TraceQueryStart(ctx context.Context, _ *pgx.Conn, _ pgx.TraceQueryStartData) context.Context {
	return context.WithValue(ctx, startKey{}, time.Now())
}

func (DBTracer) TraceQueryEnd(ctx context.Context, _ *pgx.Conn, _ pgx.TraceQueryEndData) {
	if start, ok := ctx.Value(startKey{}).(time.Time); ok {
		dbQueryDuration.Observe(time.Since(start).Seconds())
	}
}

func (DBTracer) TraceConnectStart(ctx context.Context, _ pgx.TraceConnectStartData) context.Context {
	return context.WithValue(ctx, startKey{}, time.Now())
}

func (DBTracer) TraceConnectEnd(ctx context.Context, _ pgx.TraceConnectEndData) {
	if start, ok := ctx.Value(startKey{}).(time.Time); ok {
		dbConnectDuration.Observe(time.Since(start).Seconds())
	}
}

// RegisterPool exposes pgxpool's own counters. A climbing new_conns or
// acquire_duration total means requests are paying to reconnect or queue for
// a connection rather than for the query itself.
func RegisterPool(pool *pgxpool.Pool) {
	counter := func(name, help string, f func(*pgxpool.Stat) float64) {
		promauto.NewCounterFunc(prometheus.CounterOpts{Name: name, Help: help}, func() float64 { return f(pool.Stat()) })
	}
	gauge := func(name, help string, f func(*pgxpool.Stat) float64) {
		promauto.NewGaugeFunc(prometheus.GaugeOpts{Name: name, Help: help}, func() float64 { return f(pool.Stat()) })
	}
	counter("mindforge_db_pool_acquire_total", "Pool connection acquires.", func(s *pgxpool.Stat) float64 { return float64(s.AcquireCount()) })
	counter("mindforge_db_pool_acquire_seconds_total", "Total time spent waiting to acquire a pool connection.", func(s *pgxpool.Stat) float64 { return s.AcquireDuration().Seconds() })
	counter("mindforge_db_pool_empty_acquire_total", "Acquires that had to wait because no idle connection existed.", func(s *pgxpool.Stat) float64 { return float64(s.EmptyAcquireCount()) })
	counter("mindforge_db_pool_new_conns_total", "Connections opened over the pool's lifetime.", func(s *pgxpool.Stat) float64 { return float64(s.NewConnsCount()) })
	gauge("mindforge_db_pool_idle_conns", "Idle pool connections.", func(s *pgxpool.Stat) float64 { return float64(s.IdleConns()) })
	gauge("mindforge_db_pool_acquired_conns", "Pool connections currently in use.", func(s *pgxpool.Stat) float64 { return float64(s.AcquiredConns()) })
}

// RedisHook records per-command, per-pipeline, and per-dial latency.
type RedisHook struct{}

func (RedisHook) DialHook(next redis.DialHook) redis.DialHook {
	return func(ctx context.Context, network, addr string) (net.Conn, error) {
		start := time.Now()
		conn, err := next(ctx, network, addr)
		redisDialDuration.Observe(time.Since(start).Seconds())
		return conn, err
	}
}

func (RedisHook) ProcessHook(next redis.ProcessHook) redis.ProcessHook {
	return func(ctx context.Context, cmd redis.Cmder) error {
		start := time.Now()
		err := next(ctx, cmd)
		redisCmdDuration.Observe(time.Since(start).Seconds())
		return err
	}
}

func (RedisHook) ProcessPipelineHook(next redis.ProcessPipelineHook) redis.ProcessPipelineHook {
	return func(ctx context.Context, cmds []redis.Cmder) error {
		start := time.Now()
		err := next(ctx, cmds)
		redisCmdDuration.Observe(time.Since(start).Seconds())
		return err
	}
}
