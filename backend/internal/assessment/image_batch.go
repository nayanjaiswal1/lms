package assessment

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	_ "image/png" // register PNG decoder
	"io"
	"net/http"
	"net/url"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

const (
	maxBatchImageBytes   = 5 << 20 // 5 MB
	batchImageOutputSize = 512
	batchImageKeyPrefix  = "batch-images"
)

// UploadBatchImage handles POST /api/batches/{batchID}/image — a square-cropped,
// resized cover image replacing the generated initials avatar on the frontend.
func (h *Handler) UploadBatchImage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

	r.Body = http.MaxBytesReader(w, r.Body, maxBatchImageBytes+1)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Failed to parse multipart form.")
		return
	}

	file, header, err := r.FormFile("image")
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "image file is required.")
		return
	}
	defer file.Close()

	if header.Size > maxBatchImageBytes {
		httputil.WriteError(w, http.StatusRequestEntityTooLarge, "Image must be under 5 MB.")
		return
	}

	data, err := io.ReadAll(io.LimitReader(file, maxBatchImageBytes+1))
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to read image.")
		return
	}
	if int64(len(data)) > maxBatchImageBytes {
		httputil.WriteError(w, http.StatusRequestEntityTooLarge, "Image must be under 5 MB.")
		return
	}

	detected := http.DetectContentType(data[:min(512, len(data))])
	if detected != "image/jpeg" && detected != "image/png" && detected != "image/webp" {
		httputil.WriteError(w, http.StatusUnsupportedMediaType, "Only JPEG, PNG, and WebP images are supported.")
		return
	}

	rndHex, err := randomHexBatch(16)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to process image.")
		return
	}

	var uploadData []byte
	var uploadMime, ext string
	if detected == "image/webp" {
		uploadData, uploadMime, ext = data, "image/webp", ".webp"
	} else {
		img, _, err := image.Decode(bytes.NewReader(data))
		if err != nil {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Could not decode image.")
			return
		}
		squared := cropToSquareBatch(img)
		resized := resizeNearestBatch(squared, batchImageOutputSize, batchImageOutputSize)
		var buf bytes.Buffer
		if err := jpeg.Encode(&buf, resized, &jpeg.Options{Quality: 85}); err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to encode image.")
			return
		}
		uploadData, uploadMime, ext = buf.Bytes(), "image/jpeg", ".jpg"
	}

	oldURL, err := h.repo.GetBatchImageURL(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	key := fmt.Sprintf("%s/%s/%s%s", batchImageKeyPrefix, batchID, rndHex, ext)
	publicURL, err := h.store.Upload(r.Context(), key, uploadMime, bytes.NewReader(uploadData), int64(len(uploadData)))
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to upload image.")
		return
	}

	if err := h.repo.UpdateBatchImage(r.Context(), claims.OrgID, batchID, &publicURL); err != nil {
		_ = h.store.Delete(r.Context(), key)
		writeDomainError(w, err)
		return
	}

	if oldURL != nil && *oldURL != "" {
		if oldKey := extractMinioKeyBatch(*oldURL); oldKey != "" {
			_ = h.store.Delete(r.Context(), oldKey)
		}
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"image_url": publicURL})
}

// DeleteBatchImage handles DELETE /api/batches/{batchID}/image — reverts the
// batch to its generated initials avatar.
func (h *Handler) DeleteBatchImage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")

	oldURL, err := h.repo.GetBatchImageURL(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	if err := h.repo.UpdateBatchImage(r.Context(), claims.OrgID, batchID, nil); err != nil {
		writeDomainError(w, err)
		return
	}

	if oldURL != nil && *oldURL != "" {
		if oldKey := extractMinioKeyBatch(*oldURL); oldKey != "" {
			_ = h.store.Delete(r.Context(), oldKey)
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

// extractMinioKeyBatch derives the object key from a public MinIO URL.
func extractMinioKeyBatch(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return ""
	}
	parts := strings.SplitN(strings.TrimPrefix(u.Path, "/"), "/", 2)
	if len(parts) < 2 {
		return ""
	}
	return parts[1]
}

// cropToSquareBatch returns the largest centered square crop of src.
func cropToSquareBatch(src image.Image) image.Image {
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	side := min(w, h)
	if w == h {
		return src
	}
	offsetX := b.Min.X + (w-side)/2
	offsetY := b.Min.Y + (h-side)/2
	cropRect := image.Rect(offsetX, offsetY, offsetX+side, offsetY+side)

	dst := image.NewRGBA(image.Rect(0, 0, side, side))
	draw.Draw(dst, dst.Bounds(), src, cropRect.Min, draw.Src)
	return dst
}

// resizeNearestBatch scales src to dstW×dstH using nearest-neighbor interpolation.
func resizeNearestBatch(src image.Image, dstW, dstH int) image.Image {
	srcBounds := src.Bounds()
	srcW := srcBounds.Max.X - srcBounds.Min.X
	srcH := srcBounds.Max.Y - srcBounds.Min.Y

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	if srcW == dstW && srcH == dstH {
		draw.Draw(dst, dst.Bounds(), src, srcBounds.Min, draw.Src)
		return dst
	}

	for y := 0; y < dstH; y++ {
		srcY := srcBounds.Min.Y + (y*srcH)/dstH
		for x := 0; x < dstW; x++ {
			srcX := srcBounds.Min.X + (x*srcW)/dstW
			r, g, b, a := src.At(srcX, srcY).RGBA()
			dst.SetRGBA(x, y, color.RGBA{
				R: uint8(r >> 8),
				G: uint8(g >> 8),
				B: uint8(b >> 8),
				A: uint8(a >> 8),
			})
		}
	}
	return dst
}

func randomHexBatch(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
