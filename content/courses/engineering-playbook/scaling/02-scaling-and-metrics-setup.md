---
kind: lesson
id_key: engineering-playbook/scaling/scaling-and-metrics-setup
course: engineering-playbook
section: scaling
section_title: "Scaling"
section_position: 2
title: Scaling and metrics setup for FastAPI and Django
position: 1
estimated_minutes: 25
source:
  - interview-prep-notes.md
---

# Scaling and metrics setup for FastAPI and Django

**Flow:** make the app scale-ready, scale at process level (workers), pack it in a container, run replicas behind a load balancer (Compose, k3s or AWS), expose metrics, then verify with a load test. This builds on the previous lesson, Horizontal scaling on a single machine. Percentiles are explained in the next lesson.

## Step 1: Make the app scale-ready

- Expose a `/health` endpoint (for load balancer and Kubernetes probes).
- Read config (DB URL, Redis URL) from environment variables, never hardcode.
- Sessions and cache in Redis, uploads in object storage (S3).
- Logs to stdout, not files.

```python
# FastAPI
@app.get("/health")
def health():
    return {"status": "ok"}
```

In Django, write a simple view and add `path("health/", health)`.

## Step 2: Process-level scaling with gunicorn

In production you do not run bare `uvicorn main:app` or `runserver`; you run gunicorn as the process manager.

```bash
# FastAPI
gunicorn app.main:app -k uvicorn.workers.UvicornWorker -w 4 -b 0.0.0.0:8000

# Django (sync)
gunicorn config.wsgi:application -w 4 --threads 2 -b 0.0.0.0:8000
```

Keep `-w` around the CPU core count. On Kubernetes, prefer **1-2 workers per pod** and scale with pods.

## Step 3: Add metrics

**FastAPI:** `pip install prometheus-fastapi-instrumentator`

```python
from prometheus_fastapi_instrumentator import Instrumentator, metrics

instr = Instrumentator(excluded_handlers=["/health", "/metrics"])
instr.add(metrics.latency(buckets=(0.05, 0.1, 0.25, 0.5, 1, 2.5, 5)))
instr.instrument(app).expose(app)   # creates /metrics
```

**Django:** `pip install django-prometheus`

```python
# settings.py
INSTALLED_APPS += ["django_prometheus"]
MIDDLEWARE = (
    ["django_prometheus.middleware.PrometheusBeforeMiddleware"]
    + MIDDLEWARE
    + ["django_prometheus.middleware.PrometheusAfterMiddleware"]
)
PROMETHEUS_LATENCY_BUCKETS = (0.05, 0.1, 0.25, 0.5, 1, 2.5, 5)

# urls.py
path("", include("django_prometheus.urls")),   # /metrics
```

**Gotcha (important):** with several gunicorn workers, each worker keeps its own metrics in its own process. Turn on multiprocess mode, otherwise each scrape of `/metrics` shows a random worker's data and graphs jump around:

```bash
export PROMETHEUS_MULTIPROC_DIR=/tmp/prom
mkdir -p $PROMETHEUS_MULTIPROC_DIR   # must be fresh/clean on every container start
```

## Step 4: Dockerfile

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV PROMETHEUS_MULTIPROC_DIR=/tmp/prom
CMD ["sh", "-c", "rm -rf /tmp/prom && mkdir -p /tmp/prom && exec gunicorn app.main:app -k uvicorn.workers.UvicornWorker -w ${WORKERS:-2} -b 0.0.0.0:8000"]
```

## Step 5A: Docker Compose (single machine)

```yaml
services:
  api:
    build: .
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379/0
      - WORKERS=2
    deploy:
      resources:
        limits: { cpus: "1", memory: 512M }
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 10s
    # do NOT publish ports here, or scaling will cause port conflicts

  nginx:
    image: nginx
    ports: ["80:80"]
    volumes: ["./nginx.conf:/etc/nginx/nginx.conf:ro"]
    depends_on: [api]

  prometheus:
    image: prom/prometheus
    volumes: ["./prometheus.yml:/etc/prometheus/prometheus.yml:ro"]
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana
    ports: ["3000:3000"]

  redis:
    image: redis:7
  db:
    image: postgres:16
    environment: { POSTGRES_PASSWORD: pass }
```

The credentials above are demo values; in a real setup load them from env or secrets.

**nginx.conf.** The `resolver` is required; without it nginx resolves `api` once at startup and freezes the replica IPs.

```nginx
events {}
http {
  resolver 127.0.0.11 valid=10s;
  server {
    listen 80;
    location / {
      set $upstream http://api:8000;
      proxy_pass $upstream;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
    }
  }
}
```

**prometheus.yml.** All replicas are discovered automatically through DNS:

```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: api
    dns_sd_configs:
      - names: [api]
        type: A
        port: 8000
```

Run it:

```bash
docker compose up -d --scale api=4
```

In Grafana (`localhost:3000`) add a Prometheus data source (`http://prometheus:9090`) and use this panel query:

```
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

Use 0.5 or 0.95 for p50/p95. In Django the metric is `django_http_requests_latency_seconds_by_view_method_bucket`.

## Step 5B: k3s / Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: api }
spec:
  replicas: 2
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
      - name: api
        image: myregistry/myapp:1.0
        ports: [{ containerPort: 8000 }]
        env:
        - { name: WORKERS, value: "1" }
        resources:
          requests: { cpu: "250m", memory: "256Mi" }
          limits:   { cpu: "500m", memory: "512Mi" }
        readinessProbe:
          httpGet: { path: /health, port: 8000 }
        livenessProbe:
          httpGet: { path: /health, port: 8000 }
          initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata: { name: api, labels: { app: api } }
spec:
  selector: { app: api }
  ports: [{ name: http, port: 80, targetPort: 8000 }]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: { name: api }
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend: { service: { name: api, port: { number: 80 } } }
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: api }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: api }
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: { type: Utilization, averageUtilization: 70 }
```

k3s ships Traefik as the default ingress. For metrics:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install mon prometheus-community/kube-prometheus-stack
```

Then create a `ServiceMonitor` that selects the service labelled `app: api` (`port: http`, `path: /metrics`). Grafana comes bundled. To autoscale on latency or queue depth instead of CPU, use **KEDA**, which turns a Prometheus query into an HPA trigger.

## Step 5C: AWS (ECS Fargate, the most practical)

1. Push the image to **ECR**.
2. **Task definition:** container port 8000, CPU/memory (for example 0.5 vCPU / 1 GB), health check.
3. **ALB + target group:** health check path `/health`.
4. **ECS service:** desired count 2, subnets in different AZs.
5. **Service auto scaling:** min 2, max 10, target tracking on either `ECSServiceAverageCPUUtilization` = 60%, or `ALBRequestCountPerTarget` (often a better signal than CPU).
6. **Latency:** CloudWatch, ALB, `TargetResponseTime`, statistic **p99**. Add an alarm (for example p99 > 500 ms).
7. **Data services:** RDS (Postgres), ElastiCache (Redis), S3 for uploads; pass endpoints as env variables.

For Prometheus/Grafana use Amazon Managed Prometheus + Managed Grafana, or stay with CloudWatch for simplicity.

## Step 6: Verify with a load test

```javascript
// test.js
import http from "k6/http";
export const options = { vus: 50, duration: "2m" };
export default function () { http.get("http://localhost/api/items"); }
```

```bash
k6 run test.js
```

The report includes `p(90)` and `p(95)`. Run first with `--scale api=1`, then `--scale api=4`, and compare, while watching CPU, p99 and error rate in Grafana. This shows whether the bottleneck is the app or the DB.

## Checklist

- Keep `workers x replicas` within the CPU limit.
- Watch DB connections: 10 pods x 4 workers x pool 10 = **400 connections**, far above Postgres's default of 100. This is why you add **PgBouncer**.
- Exclude `/health` and `/metrics` from latency stats, otherwise p50 looks artificially low.
- Clean the multiprocess dir on every restart.

## Check question

You run 5 pods, each with `-w 4`, and Django uses `CONN_MAX_AGE` so each worker holds one DB connection. How many connections reach Postgres? What happens when the HPA grows to 10 pods? What is the fix?

**Answer:** 5 x 4 = **20** connections, which is fine. At 10 pods it is 40 persistent connections, still under the default limit of 100, but threads or pools per worker multiply this quickly, and other clients (migrations, admin, cron) also count. Autoscaling means the connection count grows with pods, so a scale-up burst can exhaust `max_connections` and new connections fail with "too many clients". Fix: put **PgBouncer** (transaction pooling) between the app and Postgres, and keep `maxReplicas x workers x pool` below the DB limit.

## Key takeaways

- Health endpoint, env config, stateless design and stdout logs come first.
- Multiprocess metrics mode is mandatory with several gunicorn workers.
- nginx needs a `resolver`; Compose services should not publish ports when scaled.
- Pods x workers x pool size is a DB connection budget: plan it and use PgBouncer.
- Always verify scaling with a before/after load test.
