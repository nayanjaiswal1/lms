// Package metrics exposes Prometheus counters/histograms for HTTP requests
// and background jobs. Scraped over the docker-compose network only — see
// docker-compose.prod.yml's prometheus service and Caddyfile, which never
// proxies anything but /api/* to the backend, so /metrics is unreachable
// from outside the network without extra config.
package metrics

import (
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "mindforge_http_requests_total",
		Help: "Total HTTP requests, by method, route pattern, and status code.",
	}, []string{"method", "route", "status"})

	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "mindforge_http_request_duration_seconds",
		Help:    "HTTP request duration in seconds, by method and route pattern.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "route"})

	jobRunsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "mindforge_job_runs_total",
		Help: "Total background job runs, by handler and final status.",
	}, []string{"handler", "status"})

	jobDurationSeconds = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "mindforge_job_duration_seconds",
		Help:    "Background job execution duration in seconds, by handler.",
		Buckets: []float64{.1, .5, 1, 2, 5, 10, 30, 60, 120, 300},
	}, []string{"handler"})
)

// Middleware records request count and latency for every request, labeled
// by chi's matched route pattern (e.g. "/api/courses/{courseID}") rather
// than the raw path, so per-user IDs in the URL don't blow up cardinality.
func Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(ww, r)

		route := chi.RouteContext(r.Context()).RoutePattern()
		if route == "" {
			route = "unmatched"
		}
		httpRequestDuration.WithLabelValues(r.Method, route).Observe(time.Since(start).Seconds())
		httpRequestsTotal.WithLabelValues(r.Method, route, strconv.Itoa(ww.status)).Inc()
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

// Handler serves the Prometheus exposition format for scraping.
func Handler() http.Handler {
	return promhttp.Handler()
}

// RecordJobRun records one finished job's outcome and duration — called from
// internal/jobs' worker pool alongside its existing structured completion log.
func RecordJobRun(handler, status string, duration time.Duration) {
	jobRunsTotal.WithLabelValues(handler, status).Inc()
	jobDurationSeconds.WithLabelValues(handler).Observe(duration.Seconds())
}
