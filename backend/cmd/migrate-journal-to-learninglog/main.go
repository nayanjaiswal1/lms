// Command migrate-journal-to-learninglog backfills existing
// learning_journal_entries rows into each user's "Learning Log" self-course
// (internal/courses.Repo.FileLearningLogNote) — the same destination
// internal/diary's "learned" AI highlights file new notes into going
// forward. Read-only by default; pass -apply to actually write.
//
// internal/journal itself is never modified — this only reads it and writes
// into internal/courses. Safe to re-run: FileLearningLogNote dedups by
// title (FindSimilarModuleInCourse) the same way the diary AI path does, so
// a second run appends into the modules the first run already created
// rather than duplicating them.
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/courses"
	idb "github.com/mindforge/backend/internal/db"
)

type journalRow struct {
	UserID      string
	Category    string
	Subcategory string
	Title       string
	Content     string
}

func main() {
	apply := flag.Bool("apply", false, "actually write (default is a dry-run report only)")
	flag.Parse()

	_ = godotenv.Load()
	cfg := config.Load()

	ctx := context.Background()
	pool, err := idb.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("connect", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	rows, err := pool.Query(ctx,
		`SELECT user_id, category, subcategory, title, content FROM learning_journal_entries
		 ORDER BY user_id, entry_date, created_at`,
	)
	if err != nil {
		slog.Error("query journal entries", "error", err)
		os.Exit(1)
	}
	var entries []journalRow
	for rows.Next() {
		var e journalRow
		if err := rows.Scan(&e.UserID, &e.Category, &e.Subcategory, &e.Title, &e.Content); err != nil {
			slog.Error("scan journal entry", "error", err)
			os.Exit(1)
		}
		entries = append(entries, e)
	}
	if err := rows.Err(); err != nil {
		slog.Error("read journal entries", "error", err)
		os.Exit(1)
	}

	byUser := map[string][]journalRow{}
	for _, e := range entries {
		byUser[e.UserID] = append(byUser[e.UserID], e)
	}
	userIDs := make([]string, 0, len(byUser))
	for id := range byUser {
		userIDs = append(userIDs, id)
	}
	sort.Strings(userIDs)

	fmt.Printf("%d journal entries across %d users\n", len(entries), len(userIDs))

	courseRepo := courses.NewRepo(pool)
	var skippedNoOrg, migrated, failed int

	for _, userID := range userIDs {
		userEntries := byUser[userID]

		var orgID string
		err := pool.QueryRow(ctx,
			`SELECT org_id FROM org_members WHERE user_id = $1 AND status = 'active' ORDER BY created_at LIMIT 1`,
			userID,
		).Scan(&orgID)
		if err != nil {
			if err == pgx.ErrNoRows {
				fmt.Printf("  [skip] user %s: no active org membership, %d entries not migrated\n", userID, len(userEntries))
				skippedNoOrg += len(userEntries)
				continue
			}
			slog.Error("resolve org for user", "user_id", userID, "error", err)
			failed += len(userEntries)
			continue
		}

		fmt.Printf("  user %s (org %s): %d entries -> Learning Log\n", userID, orgID, len(userEntries))
		if !*apply {
			continue
		}
		for _, e := range userEntries {
			// Subcategory has no equivalent field on a self-course module —
			// fold it into the title (same "Category / Subcategory" shape
			// the journal UI already renders) so it isn't silently dropped.
			title := e.Title
			if e.Subcategory != "" {
				title = e.Subcategory + " — " + e.Title
			}
			if _, err := courseRepo.FileLearningLogNote(ctx, orgID, userID, e.Category, title, e.Content); err != nil {
				slog.Error("file note", "user_id", userID, "title", title, "error", err)
				failed++
				continue
			}
			migrated++
		}
	}

	fmt.Printf("\nmigrated=%d skipped_no_org=%d failed=%d apply=%v\n", migrated, skippedNoOrg, failed, *apply)
	if !*apply {
		fmt.Println("dry run only — re-run with -apply to write")
	}
}
