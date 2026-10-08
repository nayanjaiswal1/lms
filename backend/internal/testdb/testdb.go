// Package testdb provides a shared, disposable Postgres testcontainer for
// packages that need DB-backed tests. One named postgres:16-alpine container
// ("mindforge-testdb") is shared by every test binary and left running between
// runs. Migrations are applied once per migration set into a hash-named
// template database; each call to New clones that template into a brand-new
// database for the calling test — so tests never see each other's data — and
// registers a t.Cleanup to drop it again.
//
// Docker (or a live Postgres reachable via TESTDB_URL) is required. There is
// no silent skip path: if neither is available, New fails the test
// binary hard rather than quietly no-op.
package testdb

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"

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

// containerName is the shared, reused container all test binaries attach to.
const containerName = "mindforge-testdb"

// windowsDockerHost is Docker Desktop's default Windows engine pipe.
const windowsDockerHost = "npipe:////./pipe/docker_engine"

// buildDBName is where migrations run before being renamed to templateName;
// templateLockKey serializes template creation across test binaries.
const (
	buildDBName     = "testdb_template_build"
	templateLockKey = 7412903551
)

// testdbURLEnv is the escape hatch: point at an already-running Postgres
// instead of starting a container. Migrations still run against it the same
// way, against the same template/clone scheme.
const testdbURLEnv = "TESTDB_URL"

func init() {
	// The shared container is intentionally long-lived, so Ryuk (which would
	// reap it when the first binary exits) must stay disabled; it is also
	// flaky when parallel binaries race to attach under Docker Desktop's
	// Windows named-pipe transport. Must be set before the first testcontainers call, which is
	// why it lives in init() rather than inside setup().
	if _, set := os.LookupEnv("TESTCONTAINERS_RYUK_DISABLED"); !set {
		_ = os.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")
	}
	// With ~dozens of binaries starting at once, testcontainers' Docker host
	// discovery (config/context lookup) intermittently fails on Windows and
	// caches the failure for the whole process, surfacing as "rootless Docker
	// is not supported on Windows". Pinning the default Docker Desktop pipe
	// skips discovery entirely.
	if _, set := os.LookupEnv("DOCKER_HOST"); !set && runtime.GOOS == "windows" {
		_ = os.Setenv("DOCKER_HOST", windowsDockerHost)
	}
}

var (
	setupOnce sync.Once
	setupErr  error

	// maintenanceDSN addresses the "postgres" maintenance database — the only
	// database CREATE DATABASE / DROP DATABASE can run against.
	maintenanceDSN string

	// templateName is the migrated database every per-test database clones,
	// keyed on a hash of the embedded migration set.
	templateName = "testdb_template_" + migrate.MigrationsHash()[:12]

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

	// The pid keeps names unique across test binaries sharing the container.
	dbName := fmt.Sprintf("test_%d_%d", os.Getpid(), dbSeq.Add(1))

	maintConn, err := pgx.Connect(ctx, maintenanceDSN)
	if err != nil {
		t.Fatalf("testdb: connect to maintenance db: %v", err)
	}
	defer maintConn.Close(ctx)

	createSQL := fmt.Sprintf(`CREATE DATABASE %s TEMPLATE %s`,
		pgx.Identifier{dbName}.Sanitize(), pgx.Identifier{templateName}.Sanitize())
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

// setup attaches to (or starts) the shared Postgres, then ensures a fully
// migrated template database for the current migration set exists.
func setup(ctx context.Context) error {
	if testdbURL := os.Getenv(testdbURLEnv); testdbURL != "" {
		if err := checkTestDBURL(testdbURL); err != nil {
			return err
		}
		maintenanceDSN = testdbURL
	} else {
		// One named container shared by every test binary: testcontainers
		// reuses it when it exists and resolves create-name races between
		// parallel binaries. It is never terminated here; it is tmpfs-backed
		// and disposable (`docker rm -f mindforge-testdb` resets it).
		c, err := tcpostgres.Run(ctx, postgresImage,
			testcontainers.WithReuseByName(containerName),
			tcpostgres.BasicWaitStrategies(),
			testcontainers.WithTmpfs(map[string]string{"/var/lib/postgresql/data": ""}),
			testcontainers.WithCmd("postgres",
				"-c", "fsync=off",
				"-c", "full_page_writes=off",
				"-c", "synchronous_commit=off",
				"-c", "max_connections=500",
			),
		)
		if err != nil {
			return fmt.Errorf("start postgres container: %w", err)
		}
		dsn, err := c.ConnectionString(ctx, "sslmode=disable")
		if err != nil {
			return fmt.Errorf("get container connection string: %w", err)
		}
		maintenanceDSN = dsn
	}

	return ensureTemplate(ctx)
}

// ensureTemplate creates templateName (keyed on the migration set) if it is
// missing. It serializes concurrent test binaries with an advisory lock, and
// migrates into a build database that is renamed into place only after
// success, so a crashed run can never leave a half-migrated template behind.
func ensureTemplate(ctx context.Context) error {
	maintConn, err := pgx.Connect(ctx, maintenanceDSN)
	if err != nil {
		return fmt.Errorf("connect to maintenance db: %w", err)
	}
	defer maintConn.Close(ctx)

	if _, err := maintConn.Exec(ctx, `SELECT pg_advisory_lock($1)`, templateLockKey); err != nil {
		return fmt.Errorf("acquire template lock: %w", err)
	}
	// Closing maintConn also releases the lock if the unlock itself fails.
	defer func() { _, _ = maintConn.Exec(context.Background(), `SELECT pg_advisory_unlock($1)`, templateLockKey) }()

	var exists bool
	if err := maintConn.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1)`, templateName,
	).Scan(&exists); err != nil {
		return fmt.Errorf("check template database: %w", err)
	}
	if exists {
		return nil
	}

	build := pgx.Identifier{buildDBName}.Sanitize()
	if _, err := maintConn.Exec(ctx, `DROP DATABASE IF EXISTS `+build+` WITH (FORCE)`); err != nil {
		return fmt.Errorf("drop stale build database: %w", err)
	}
	if _, err := maintConn.Exec(ctx, `CREATE DATABASE `+build); err != nil {
		return fmt.Errorf("create build database: %w", err)
	}

	buildDSN, err := withDatabase(maintenanceDSN, buildDBName)
	if err != nil {
		return fmt.Errorf("build template dsn: %w", err)
	}
	pool, err := dbconn.Connect(ctx, buildDSN)
	if err != nil {
		return fmt.Errorf("connect to build database: %w", err)
	}
	err = migrate.RunMigrations(ctx, pool)
	// Renaming and cloning require zero sessions connected to the database,
	// so the pool must be fully closed, not merely idle.
	pool.Close()
	if err != nil {
		return fmt.Errorf("run migrations: %w", err)
	}

	if _, err := maintConn.Exec(ctx, `ALTER DATABASE `+build+` RENAME TO `+pgx.Identifier{templateName}.Sanitize()); err != nil {
		return fmt.Errorf("publish template database: %w", err)
	}
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

// localTestHosts are the only hosts TESTDB_URL may point at. Tests create and
// drop databases, so a TESTDB_URL aimed at a shared or production server (the
// local backend/.env points DATABASE_URL at the production Neon database)
// must be refused rather than trusted.
var localTestHosts = map[string]bool{
	"localhost": true, "127.0.0.1": true, "::1": true, "host.docker.internal": true,
}

// checkTestDBURL rejects a TESTDB_URL that is not a local server or that
// shares a host with DATABASE_URL.
func checkTestDBURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("%s is not a valid URL: %w", testdbURLEnv, err)
	}
	if !localTestHosts[u.Hostname()] {
		return fmt.Errorf("%s host %q is not local; refusing to run destructive tests against it", testdbURLEnv, u.Hostname())
	}
	if app, err := url.Parse(os.Getenv("DATABASE_URL")); err == nil && app.Hostname() == u.Hostname() && u.Port() == app.Port() && u.Path == app.Path {
		return fmt.Errorf("%s points at the same database as DATABASE_URL", testdbURLEnv)
	}
	return nil
}
