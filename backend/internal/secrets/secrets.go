// Package secrets provides a shared AES-256-GCM encryption vault for any
// domain that must store a third-party credential it needs to replay later
// (unlike a password or refresh-token hash, which only ever needs to be
// compared, never decrypted). The GitLab integration is the first consumer:
// installation and per-user connection access/refresh tokens must be sent
// back to the GitLab API on every call, so hashing alone (as mcp_connections
// does for its own refresh tokens) will not work.
package secrets

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"io"

	"github.com/mindforge/backend/internal/config"
)

// Vault encrypts/decrypts values with AES-256-GCM under a key derived from
// cfg.EncryptionKey. The env var itself is not used as the raw AES key —
// sha256 always yields exactly 32 bytes regardless of the operator-chosen
// secret's length (config.go only enforces >= 32 bytes, not exactly 32).
type Vault struct {
	gcm cipher.AEAD
}

// New derives the AES-256 key from cfg.EncryptionKey and builds the GCM vault.
// cfg.EncryptionKey is already required and startup-validated by config.Load
// (non-empty, not a "change_me" placeholder, >= 32 bytes) — this constructor
// only ever fails on a cipher-construction error, which sha256's fixed 32-byte
// output makes effectively unreachable, but the error is still surfaced
// rather than assumed away.
func New(cfg *config.Config) (*Vault, error) {
	key := sha256.Sum256([]byte(cfg.EncryptionKey))

	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, fmt.Errorf("secrets: new aes cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("secrets: new gcm: %w", err)
	}
	return &Vault{gcm: gcm}, nil
}

// Encrypt returns nonce||ciphertext, a random 12-byte nonce generated fresh
// for every call and prepended to the AES-256-GCM sealed output. The nonce
// need not be secret — GCM's security only requires it never repeat for a
// given key, which crypto/rand guarantees in practice.
func (v *Vault) Encrypt(plaintext []byte) ([]byte, error) {
	nonce := make([]byte, v.gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("secrets: generate nonce: %w", err)
	}
	return v.gcm.Seal(nonce, nonce, plaintext, nil), nil
}

// Decrypt reverses Encrypt: splits the leading nonce off ciphertext and opens
// the remainder. Fails if the vault's key does not match the one Encrypt used
// (wrong ENCRYPTION_KEY) or if ciphertext was tampered with (GCM auth tag).
func (v *Vault) Decrypt(ciphertext []byte) ([]byte, error) {
	nonceSize := v.gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("secrets: ciphertext too short")
	}
	nonce, sealed := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := v.gcm.Open(nil, nonce, sealed, nil)
	if err != nil {
		return nil, fmt.Errorf("secrets: decrypt: %w", err)
	}
	return plaintext, nil
}
