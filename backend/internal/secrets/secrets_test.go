package secrets_test

import (
	"testing"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/secrets"
	"github.com/stretchr/testify/require"
)

func testConfig(key string) *config.Config {
	return &config.Config{EncryptionKey: key}
}

func TestEncryptDecrypt_RoundTrip(t *testing.T) {
	vault, err := secrets.New(testConfig("this-is-a-test-encryption-key-32b"))
	require.NoError(t, err)

	plaintext := []byte("glpat-super-secret-personal-access-token")
	ciphertext, err := vault.Encrypt(plaintext)
	require.NoError(t, err)
	require.NotEqual(t, plaintext, ciphertext)

	decrypted, err := vault.Decrypt(ciphertext)
	require.NoError(t, err)
	require.Equal(t, plaintext, decrypted)
}

func TestDecrypt_WrongKeyFails(t *testing.T) {
	vaultA, err := secrets.New(testConfig("key-a-0000000000000000000000000000"))
	require.NoError(t, err)
	vaultB, err := secrets.New(testConfig("key-b-0000000000000000000000000000"))
	require.NoError(t, err)

	ciphertext, err := vaultA.Encrypt([]byte("secret payload"))
	require.NoError(t, err)

	_, err = vaultB.Decrypt(ciphertext)
	require.Error(t, err)
}

func TestEncrypt_NonceUniquePerCall(t *testing.T) {
	vault, err := secrets.New(testConfig("nonce-uniqueness-test-key-32bytes!"))
	require.NoError(t, err)

	plaintext := []byte("same plaintext every time")
	first, err := vault.Encrypt(plaintext)
	require.NoError(t, err)
	second, err := vault.Encrypt(plaintext)
	require.NoError(t, err)

	require.NotEqual(t, first, second, "two encryptions of the same plaintext must differ (nonce uniqueness)")

	// Both must still decrypt to the same plaintext despite differing ciphertext.
	decFirst, err := vault.Decrypt(first)
	require.NoError(t, err)
	decSecond, err := vault.Decrypt(second)
	require.NoError(t, err)
	require.Equal(t, plaintext, decFirst)
	require.Equal(t, plaintext, decSecond)
}

func TestDecrypt_TooShortCiphertextFails(t *testing.T) {
	vault, err := secrets.New(testConfig("short-ciphertext-test-key-32bytes!!"))
	require.NoError(t, err)

	_, err = vault.Decrypt([]byte("short"))
	require.Error(t, err)
}
