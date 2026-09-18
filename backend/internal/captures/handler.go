package captures

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/journal"
	"github.com/mindforge/backend/internal/srs"
	"github.com/mindforge/backend/internal/storage"
)

const (
	maxUploadBytes   = 20 << 20 // 20 MB — covers both an image and a PDF, one limit
	maxHTMLChars     = 2_000_000
	captureKeyPrefix = "captures"

	// Job handler key — plain string literal, same reasoning as every other
	// job constant referenced from a domain package (internal/jobs/handlers
	// imports captures for CapturesProcessHandler, so captures cannot import
	// handlers back). MUST stay in sync with handlers.HandlerCapturesProcess
	// in internal/jobs/handlers/constants.go.
	jobCapturesProcess = "captures.process"
)

// Handler exposes the captures domain over HTTP.
type Handler struct {
	repo    *Repo
	journal *journal.Repo
	srs     *srs.Repo
	storage storage.StorageClient
	jobs    *jobs.Registry
	pool    *pgxpool.Pool
}

// NewHandler constructs the captures handler.
func NewHandler(pool *pgxpool.Pool, storageClient storage.StorageClient, jobsRegistry *jobs.Registry) *Handler {
	return &Handler{
		repo:    NewRepo(pool),
		journal: journal.NewRepo(pool),
		srs:     srs.NewRepo(pool),
		storage: storageClient,
		jobs:    jobsRegistry,
		pool:    pool,
	}
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound: {Status: http.StatusNotFound, Message: "Not found."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// enqueueProcessing queues the captures.process job for a newly created
// capture. On failure it marks the capture failed itself (rather than
// leaving it stuck "pending" forever with no worker ever picking it up) and
// returns the original enqueue error so the caller can log/respond.
func (h *Handler) enqueueProcessing(r *http.Request, userID, orgID, captureID string) error {
	var orgIDPtr *string
	if orgID != "" {
		orgIDPtr = &orgID
	}
	_, err := jobs.Enqueue(r.Context(), h.pool, h.jobs, jobs.EnqueueParams{
		Handler:   jobCapturesProcess,
		Priority:  jobs.PriorityNormal,
		Payload:   JobPayload{CaptureID: captureID, UserID: userID},
		OrgID:     orgIDPtr,
		CreatedBy: &userID,
	})
	if err != nil {
		_ = h.repo.MarkFailed(r.Context(), captureID, "Failed to queue processing.")
	}
	return err
}

// Create handles POST /api/captures — the single entry point for all four
// capture sources. A multipart request (Content-Type: multipart/form-data)
// is a file upload (image or PDF — auto-detected from magic bytes, no
// separate route per type needed); anything else is decoded as JSON
// (CreateJSONRequest), where exactly one of url/html selects a link fetch or
// a raw-HTML paste.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/form-data") {
		h.createUpload(w, r)
		return
	}
	h.createFromJSON(w, r)
}

// createUpload handles one or many files in a single request — the browser
// sends repeated "file" fields (<input type="file" multiple>), each becomes
// its own Capture row and its own job, so one bad file in the batch never
// blocks the rest.
func (h *Handler) createUpload(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, (maxUploadBytes+1)*int64(MaxItemsPerRequest))
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Failed to parse multipart form.")
		return
	}

	files := r.MultipartForm.File["file"]
	if len(files) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "At least one file is required.")
		return
	}
	if len(files) > MaxItemsPerRequest {
		httputil.WriteError(w, http.StatusUnprocessableEntity, fmt.Sprintf("At most %d files per upload.", MaxItemsPerRequest))
		return
	}

	// Read + validate every file up front — same "don't create a partial,
	// unreturned batch" reasoning as createFromJSON. Reading into memory
	// (bounded by maxUploadBytes each) IS the validation step here (mime
	// sniffing needs the bytes), so this pass costs nothing extra.
	type validatedFile struct {
		data        []byte
		mime        string
		captureType string
	}
	validated := make([]validatedFile, 0, len(files))
	for _, fh := range files {
		data, mime, captureType, err := readAndValidateUpload(fh)
		if err != nil {
			httputil.WriteError(w, http.StatusUnprocessableEntity, fmt.Sprintf("%s: %s", fh.Filename, err.Error()))
			return
		}
		validated = append(validated, validatedFile{data: data, mime: mime, captureType: captureType})
	}

	captures := make([]Capture, 0, len(validated))
	for _, v := range validated {
		rnd, err := randomHex(16)
		if err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to process upload.")
			return
		}
		key := fmt.Sprintf("%s/%s/%s%s", captureKeyPrefix, claims.UserID, rnd, extensionForMIME(v.mime))

		if _, err := h.storage.Upload(r.Context(), key, v.mime, bytes.NewReader(v.data), int64(len(v.data))); err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to store one or more uploads.")
			return
		}
		capture, err := h.repo.CreateUploadCapture(r.Context(), claims.UserID, v.captureType, key)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		if err := h.enqueueProcessing(r, claims.UserID, claims.OrgID, capture.ID); err != nil {
			capture.Status = StatusFailed
		}
		captures = append(captures, capture)
	}

	httputil.WriteJSON(w, http.StatusAccepted, captures)
}

func readAndValidateUpload(fh *multipart.FileHeader) (data []byte, mime, captureType string, err error) {
	file, err := fh.Open()
	if err != nil {
		return nil, "", "", fmt.Errorf("failed to open upload")
	}
	defer file.Close()

	data, err = io.ReadAll(io.LimitReader(file, maxUploadBytes+1))
	if err != nil {
		return nil, "", "", fmt.Errorf("failed to read upload")
	}
	if int64(len(data)) > maxUploadBytes {
		return nil, "", "", fmt.Errorf("file must be under %d MB", maxUploadBytes>>20)
	}

	mime = http.DetectContentType(data[:min(512, len(data))])
	switch mime {
	case "image/jpeg", "image/png", "image/webp":
		captureType = TypeImage
	case "application/pdf":
		captureType = TypePDF
	default:
		return nil, "", "", fmt.Errorf("unsupported file type: %s", mime)
	}
	return data, mime, captureType, nil
}

// createFromJSON handles one or many urls/html items in a single request —
// each becomes its own Capture row and its own job, same "one bad item never
// blocks the rest" reasoning as createUpload.
func (h *Handler) createFromJSON(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateJSONRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	total := len(req.URLs) + len(req.HTML)
	if total == 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"urls": "Provide at least one url or html item (or a multipart file upload).",
		})
		return
	}
	if total > MaxItemsPerRequest {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"urls": fmt.Sprintf("At most %d items per request.", MaxItemsPerRequest),
		})
		return
	}

	// Validate every item up front, before creating anything — one malformed
	// item in the batch must not leave a partial mix of created-but-
	// unreported rows behind (see extractedHTML below, computed here too so
	// the "no extractable text" check is also a pre-creation validation, not
	// a mid-batch failure).
	urls := make([]string, 0, len(req.URLs))
	for _, rawURL := range req.URLs {
		u := strings.TrimSpace(rawURL)
		if u == "" {
			continue
		}
		if len(u) > 2000 || (!strings.HasPrefix(u, "http://") && !strings.HasPrefix(u, "https://")) {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"urls": fmt.Sprintf("%q is not a valid http(s) URL.", u),
			})
			return
		}
		urls = append(urls, u)
	}

	extractedHTML := make([]string, 0, len(req.HTML))
	for _, rawHTML := range req.HTML {
		htmlStr := strings.TrimSpace(rawHTML)
		if htmlStr == "" {
			continue
		}
		if len(htmlStr) > maxHTMLChars {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"html": fmt.Sprintf("html must be under %d characters.", maxHTMLChars),
			})
			return
		}
		_, text := extractHTML(strings.NewReader(htmlStr))
		if strings.TrimSpace(text) == "" {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"html": "No extractable text found in one of the pasted HTML items.",
			})
			return
		}
		extractedHTML = append(extractedHTML, text)
	}

	if len(urls) == 0 && len(extractedHTML) == 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"urls": "Provide at least one non-empty url or html item.",
		})
		return
	}

	// All validated — now actually create + enqueue. A failure past this
	// point (DB error, enqueue error) is a genuine runtime fault, not
	// something the caller could have avoided by fixing their input.
	captures := make([]Capture, 0, len(urls)+len(extractedHTML))
	for _, u := range urls {
		capture, err := h.repo.CreateLinkCapture(r.Context(), claims.UserID, u)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		if err := h.enqueueProcessing(r, claims.UserID, claims.OrgID, capture.ID); err != nil {
			capture.Status = StatusFailed
		}
		captures = append(captures, capture)
	}
	for _, text := range extractedHTML {
		capture, err := h.repo.CreateHTMLCapture(r.Context(), claims.UserID, text)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		if err := h.enqueueProcessing(r, claims.UserID, claims.OrgID, capture.ID); err != nil {
			capture.Status = StatusFailed
		}
		captures = append(captures, capture)
	}

	httputil.WriteJSON(w, http.StatusAccepted, captures)
}

// ListCaptures handles GET /api/captures — the inbox, optionally filtered by ?status=.
func (h *Handler) ListCaptures(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	captures, err := h.repo.ListCaptures(r.Context(), claims.UserID, ListFilter{Status: r.URL.Query().Get("status")})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, captures)
}

// GetCapture handles GET /api/captures/:id — a ready capture's detail plus
// its live-computed similar matches (see CaptureDetail).
func (h *Handler) GetCapture(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	capture, err := h.repo.GetCapture(r.Context(), claims.UserID, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}

	similar, err := h.similarMatches(r, claims.UserID, capture)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, CaptureDetail{Capture: capture, SimilarEntries: similar})
}

func (h *Handler) similarMatches(r *http.Request, userID string, capture Capture) ([]SimilarMatch, error) {
	if capture.Status != StatusReady || capture.Kind == nil || capture.Title == nil {
		return []SimilarMatch{}, nil
	}
	if *capture.Kind == KindQuestion {
		return h.repo.FindSimilarQuestionCards(r.Context(), userID, *capture.Title)
	}
	entries, err := h.journal.FindSimilarEntries(r.Context(), userID, *capture.Title, "")
	if err != nil {
		return nil, err
	}
	out := make([]SimilarMatch, len(entries))
	for i, e := range entries {
		out[i] = SimilarMatch{Type: "journal_entry", ID: e.ID, Title: e.Title}
	}
	return out, nil
}

// Retry handles POST /api/captures/:id/retry — re-queues a failed capture.
func (h *Handler) Retry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	capture, err := h.repo.GetCapture(r.Context(), claims.UserID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if capture.Status != StatusFailed {
		httputil.WriteError(w, http.StatusConflict, "Only a failed capture can be retried.")
		return
	}
	if err := h.enqueueProcessing(r, claims.UserID, claims.OrgID, id); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to queue processing.")
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]string{"status": StatusPending})
}

// Dismiss handles POST /api/captures/:id/dismiss.
func (h *Handler) Dismiss(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.Dismiss(r.Context(), claims.UserID, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Promote handles POST /api/captures/:id/promote — turns a "ready" capture
// into a real journal entry (kind=note) or SRS card (kind=question). If
// req.MergeIntoID names an existing journal entry, it's merged via
// journal.Repo.MergeEntries instead of creating a new one (an existing SRS
// card is only ever linked, never merged — the point of a question-kind
// duplicate is "you already have this card," not two answers combined).
func (h *Handler) Promote(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")

	capture, err := h.repo.GetCapture(r.Context(), claims.UserID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if capture.Status != StatusReady {
		httputil.WriteError(w, http.StatusConflict, "Only a ready capture can be promoted.")
		return
	}

	var req PromoteRequest
	if r.ContentLength != 0 {
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
			return
		}
	}

	title := stringOrDefault(req.Title, capture.Title)
	content := stringOrDefault(req.Content, capture.Content)
	category := stringOrDefault(req.Category, capture.Category)
	subcategory := stringOrDefault(req.Subcategory, capture.Subcategory)
	if title == "" || content == "" {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "title and content are required.")
		return
	}

	kind := KindNote
	if capture.Kind != nil {
		kind = *capture.Kind
	}

	switch kind {
	case KindQuestion:
		if req.MergeIntoID != "" {
			if err := h.repo.LinkPromoted(r.Context(), claims.UserID, id, "", req.MergeIntoID); err != nil {
				writeDomainError(w, err)
				return
			}
			httputil.WriteJSON(w, http.StatusOK, map[string]string{"srs_card_id": req.MergeIntoID})
			return
		}
		card, err := h.srs.CreateCard(r.Context(), claims.UserID, srs.CreateCardRequest{
			Front:      title,
			Back:       content,
			SourceType: "capture",
		})
		if err != nil {
			writeDomainError(w, err)
			return
		}
		if err := h.repo.LinkPromoted(r.Context(), claims.UserID, id, "", card.ID); err != nil {
			writeDomainError(w, err)
			return
		}
		httputil.WriteJSON(w, http.StatusCreated, card)

	default: // KindNote
		if req.MergeIntoID != "" {
			// A capture isn't itself a journal row, so there's nothing for
			// journal.Repo.MergeEntries (which folds two existing entries
			// together) to operate on here — "merge into" just means
			// appending the capture's content onto the existing entry.
			existing, err := h.journal.GetEntry(r.Context(), claims.UserID, req.MergeIntoID)
			if err != nil {
				writeDomainError(w, err)
				return
			}
			updated, err := h.journal.UpdateEntry(r.Context(), claims.UserID, existing.ID, journal.UpdateEntryRequest{
				Content: strPtr(existing.Content + "\n\n---\n\n" + content),
			})
			if err != nil {
				writeDomainError(w, err)
				return
			}
			if err := h.repo.LinkPromoted(r.Context(), claims.UserID, id, updated.ID, ""); err != nil {
				writeDomainError(w, err)
				return
			}
			httputil.WriteJSON(w, http.StatusOK, updated)
			return
		}

		entry, err := h.journal.CreateEntry(r.Context(), claims.UserID, journal.CreateEntryRequest{
			Category:    category,
			Subcategory: subcategory,
			Title:       title,
			Content:     content,
		})
		if err != nil {
			writeDomainError(w, err)
			return
		}
		if err := h.repo.LinkPromoted(r.Context(), claims.UserID, id, entry.ID, ""); err != nil {
			writeDomainError(w, err)
			return
		}
		httputil.WriteJSON(w, http.StatusCreated, entry)
	}
}

func stringOrDefault(override *string, fallback *string) string {
	if override != nil {
		return strings.TrimSpace(*override)
	}
	if fallback != nil {
		return *fallback
	}
	return ""
}

func strPtr(s string) *string { return &s }

func extensionForMIME(mime string) string {
	switch mime {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "application/pdf":
		return ".pdf"
	default:
		return ""
	}
}

func randomHex(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
