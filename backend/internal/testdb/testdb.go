// Package testdb provides a shared, disposable Postgres testcontainer for
// packages that need DB-backed tests. One postgres:16-alpine container is
// started per test binary (guarded by sync.Once), migrated once into a
// template database, and then each call to New clones that template into a
// brand-new database for the calling test — so tests never see each other's
// data — and registers a t.Cleanup to drop it again.
//
// Docker (or a live Postgres reachable via TESTDB_URL) is required. There is
// no silent skip path: if neither is available, New/RunMain fail the test
// binary hard rather than quietly no-op.
package testdb

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"

	migrate "github.com/mindforge/backend/db"
	dbconn "github.com/mindforge/backend/internal/db"
)

// postgresImage must track the version pinned in docker-compose.dev.yml,
// docker-compose.prod.yml, and k8s/base/postgres.yaml.
const postgresImage = "postgres:16-alpine"

// templateDBName is the database migrations are applied to once; every
// per-test database is a CREATE DATABASE ... TEMPLATE clone of it.
const templateDBName = "testdb_template"

// testdbURLEnv is the escape hatch: point at an already-running Postgres
// instead of starting a container. Migrations still run against it the same
// way, against the same template/clone scheme.
const testdbURLEnv = "TESTDB_URL"

func init() {
	// RunMain always deterministically terminates the shared container after
	// m.Run(), so we don't need (and don't want) testcontainers-go's Ryuk
	// reaper: it's a single container shared across every package's test
	// binary process on the host, and `go test ./...` starts several of
	// those binaries in parallel — each racing to create/attach the same
	// reaper, which is flaky under Docker Desktop's Windows named-pipe
	// transport. Must be set before the first testcontainers call, which is
	// why it lives in init() rather than inside setup().
	if _, set := os.LookupEnv("TESTCONTAINERS_RYUK_DISABLED"); !set {
		_ = os.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")
	}
}

var (
	setupOnce sync.Once
	setupErr  error

	// maintenanceDSN addresses the "postgres" maintenance database — the only
	// database CREATE DATABASE / DROP DATABASE can run against.
	maintenanceDSN string
	container      *tcpostgres.PostgresContainer

	dbSeq atomic.Int64
)

// New provisions a freshly migrated database for one test and returns a pool
// connected to it, built through the same internal/db.Connect helper
// production code uses so tests exercise the same pool configuration. The
// database is dropped automatically via t.Cleanup.
func New(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx := context.Background()

	setupOnce.Do(func() { setupErr = setup(ctx) })
	if setupErr != nil {
		t.Fatalf("testdb: setup: %v", setupErr)
	}

	dbName := fmt.Sprintf("test_%d", dbSeq.Add(1))

	maintConn, err := pgx.Connect(ctx, maintenanceDSN)
	if err != nil {
		t.Fatalf("testdb: connect to maintenance db: %v", err)
	}
	defer maintConn.Close(ctx)

	createSQL := fmt.Sprintf(`CREATE DATABASE %s TEMPLATE %s`,
		pgx.Identifier{dbName}.Sanitize(), pgx.Identifier{templateDBName}.Sanitize())
	if _, err := maintConn.Exec(ctx, createSQL); err != nil {
		t.Fatalf("testdb: create database %s: %v", dbName, err)
	}

	dsn, err := withDatabase(maintenanceDSN, dbName)
	if err != nil {
		t.Fatalf("testdb: build dsn for %s: %v", dbName, err)
	}

	pool, err := dbconn.Connect(ctx, dsn)
	if err != nil {
		t.Fatalf("testdb: connect to %s: %v", dbName, err)
	}

	t.Cleanup(func() {
		pool.Close()

		dropCtx := context.Background()
		conn, err := pgx.Connect(dropCtx, maintenanceDSN)
		if err != nil {
			t.Errorf("testdb: connect to maintenance db to drop %s: %v", dbName, err)
			return
		}
		defer conn.Close(dropCtx)

		dropSQL := fmt.Sprintf(`DROP DATABASE IF EXISTS %s WITH (FORCE)`, pgx.Identifier{dbName}.Sanitize())
		if _, err := conn.Exec(dropCtx, dropSQL); err != nil {
			t.Errorf("testdb: drop database %s: %v", dbName, err)
		}
	})

	return pool
}

// RunMain runs m, deterministically tears down the shared container
// afterwards (rather than relying on the Ryuk reaper), and then exits with
// m's result code. Wire it up as the package's TestMain:
//
//	func TestMain(m *testing.M) { testdb.RunMain(m) }
func RunMain(m *testing.M) {
	code := m.Run()
	teardown()
	os.Exit(code)
}

func teardown() {
	if container == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := container.Terminate(ctx); err != nil {
		log.Printf("testdb: terminate container: %v", err)
	}
}

// setup starts (or attaches to, via TESTDB_URL) Postgres, then runs the
// repo's migration runner against a fresh template database and closes that
// connection completely — CREATE DATABASE ... TEMPLATE fails if any session
// is still connected to the template it's cloning.
func setup(ctx context.Context) error {
	if testdbURL := os.Getenv(testdbURLEnv); testdbURL != "" {
		maintenanceDSN = testdbURL
	} else {
		c, err := tcpostgres.Run(ctx, postgresImage,
			tcpostgres.BasicWaitStrategies(),
			testcontainers.WithTmpfs(map[string]string{"/var/lib/postgresql/data": ""}),
			testcontainers.WithCmd("postgres",
				"-c", "fsync=off",
				"-c", "full_page_writes=off",
				"-c", "synchronous_commit=off",
				"-c", "max_connections=200",
			),
		)
		if err != nil {
			return fmt.Errorf("start postgres container: %w", err)
		}
		container = c

		dsn, err := c.ConnectionString(ctx, "sslmode=disable")
		if err != nil {
			return fmt.Errorf("get container connection string: %w", err)
		}
		maintenanceDSN = dsn
	}

	maintConn, err := pgx.Connect(ctx, maintenanceDSN)
	if err != nil {
		return fmt.Errorf("connect to maintenance db: %w", err)
	}
	defer maintConn.Close(ctx)

	dropSQL := fmt.Sprintf(`DROP DATABASE IF EXISTS %s WITH (FORCE)`, pgx.Identifier{templateDBName}.Sanitize())
	if _, err := maintConn.Exec(ctx, dropSQL); err != nil {
		return fmt.Errorf("drop stale template database: %w", err)
	}
	createSQL := fmt.Sprintf(`CREATE DATABASE %s`, pgx.Identifier{templateDBName}.Sanitize())
	if _, err := maintConn.Exec(ctx, createSQL); err != nil {
		return fmt.Errorf("create template database: %w", err)
	}

	templateDSN, err := withDatabase(maintenanceDSN, templateDBName)
	if err != nil {
		return fmt.Errorf("build template dsn: %w", err)
	}

	templatePool, err := dbconn.Connect(ctx, templateDSN)
	if err != nil {
		return fmt.Errorf("connect to template database: %w", err)
	}
	if err := migrate.RunMigrations(ctx, templatePool); err != nil {
		templatePool.Close()
		return fmt.Errorf("run migrations: %w", err)
	}
	// CREATE DATABASE ... TEMPLATE requires zero sessions connected to the
	// template, so the pool must be fully closed — not merely idle — before
	// New can clone it.
	templatePool.Close()

	return nil
}

// withDatabase returns dsn with its database path swapped to name.
func withDatabase(dsn, name string) (string, error) {
	u, err := url.Parse(dsn)
	if err != nil {
		return "", fmt.Errorf("parse dsn: %w", err)
	}
	u.Path = "/" + name
	return u.String(), nil
}
