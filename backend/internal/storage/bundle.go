package storage

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

// BundleKeyPrefix is the private-store prefix every lab bundle (scenario
// workspace/grader bundles and authoring block payloads) lives under.
const BundleKeyPrefix = "lab-bundles/"

// BundleKey is the content-addressed private-store key for a bundle.
func BundleKey(sha string) string { return BundleKeyPrefix + sha + ".tar.gz" }

// PutBundle uploads data to store under its content-addressed key and returns
// (key, sha256). Immutable and idempotent: identical bytes always land on the
// same key. Callers must call this BEFORE committing the DB row that
// references the key. Shared by labs.Service.StoreBundle and the lab-authoring
// block sync so both write the exact same key scheme.
func PutBundle(ctx context.Context, store PrivateStore, data []byte) (key, sha string, err error) {
	sum := sha256.Sum256(data)
	sha = hex.EncodeToString(sum[:])
	key = BundleKey(sha)
	if err := store.Upload(ctx, key, "application/gzip", bytes.NewReader(data), int64(len(data))); err != nil {
		return "", "", fmt.Errorf("storage.PutBundle: %w", err)
	}
	return key, sha, nil
}
