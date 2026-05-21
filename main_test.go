package main

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGivenDefaultBackupRoot_WhenResolved_ThenItExpandsToHomePhotos(t *testing.T) {
	t.Helper()

	// Given
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatalf("failed to get user home: %v", err)
	}

	// When
	resolved, err := resolveBackupDir()
	if err != nil {
		t.Fatalf("failed to resolve backup dir: %v", err)
	}

	// Then
	want := filepath.Join(home, "Photos")
	if resolved != want {
		t.Fatalf("expected backup dir %q, got %q", want, resolved)
	}
}

func TestGivenHealthyServer_WhenHealthRequested_ThenReturnsOK(t *testing.T) {
	t.Helper()
	app := newTestApp(t)

	// Given
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rr := httptest.NewRecorder()

	// When
	app.handleHealth(rr, req)

	// Then
	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}
	if strings.TrimSpace(rr.Body.String()) != "ok" {
		t.Fatalf("expected body ok, got %q", rr.Body.String())
	}
}

func TestGivenFreshUpload_WhenUploadedAndChecked_ThenSavedUnderMonthFolderAndCheckReturnsExists(t *testing.T) {
	t.Helper()
	app := newTestApp(t)

	// Given
	payload := []byte("photo-bytes-001")
	createdAt := "2026-05-19T12:00:00+09:00"
	uploadReq := newMultipartUploadRequest(t, payload, "IMG_1234.HEIC", "IMG_1234.HEIC", createdAt, "15")
	uploadRR := httptest.NewRecorder()

	// When
	app.handleUpload(uploadRR, uploadReq)

	// Then
	if uploadRR.Code != http.StatusOK {
		t.Fatalf("expected upload status 200, got %d body=%s", uploadRR.Code, uploadRR.Body.String())
	}

	var uploadResp uploadResult
	if err := json.Unmarshal(uploadRR.Body.Bytes(), &uploadResp); err != nil {
		t.Fatalf("failed to decode upload response: %v", err)
	}
	if !uploadResp.OK || !uploadResp.Saved || uploadResp.Duplicate {
		t.Fatalf("unexpected upload response: %+v", uploadResp)
	}
	if !strings.Contains(uploadResp.SavedPath, filepath.Join(app.backupDir, "2026-05")+string(os.PathSeparator)) {
		t.Fatalf("expected saved path under month folder, got %q", uploadResp.SavedPath)
	}
	if _, err := os.Stat(uploadResp.SavedPath); err != nil {
		t.Fatalf("expected saved file to exist: %v", err)
	}

	checkReqBody := map[string]any{
		"original_name": "IMG_1234.HEIC",
		"created_at":    createdAt,
		"file_size":     int64(len(payload)),
	}
	checkReq := newJSONRequest(t, "/check", checkReqBody)
	checkRR := httptest.NewRecorder()
	app.handleCheck(checkRR, checkReq)

	if checkRR.Code != http.StatusOK {
		t.Fatalf("expected check status 200, got %d body=%s", checkRR.Code, checkRR.Body.String())
	}

	var checkResp map[string]any
	if err := json.Unmarshal(checkRR.Body.Bytes(), &checkResp); err != nil {
		t.Fatalf("failed to decode check response: %v", err)
	}
	if exists, _ := checkResp["exists"].(bool); !exists {
		t.Fatalf("expected exists=true, got response %v", checkResp)
	}
	if gotPath, _ := checkResp["saved_path"].(string); gotPath != uploadResp.SavedPath {
		t.Fatalf("expected saved_path %q, got %q", uploadResp.SavedPath, gotPath)
	}
}

func TestGivenDuplicateContent_WhenUploadedTwice_ThenSecondUploadReturnsDuplicateWithoutSavingNewFile(t *testing.T) {
	t.Helper()
	app := newTestApp(t)

	// Given
	payload := []byte("same-content-same-sha")
	createdAt := "2026-05-20T08:30:00+09:00"

	firstReq := newMultipartUploadRequest(t, payload, "IMG_7777.HEIC", "IMG_7777.HEIC", createdAt, "21")
	firstRR := httptest.NewRecorder()
	app.handleUpload(firstRR, firstReq)

	if firstRR.Code != http.StatusOK {
		t.Fatalf("expected first upload status 200, got %d body=%s", firstRR.Code, firstRR.Body.String())
	}

	var firstResp uploadResult
	if err := json.Unmarshal(firstRR.Body.Bytes(), &firstResp); err != nil {
		t.Fatalf("failed to decode first upload response: %v", err)
	}
	if !firstResp.Saved || firstResp.Duplicate {
		t.Fatalf("unexpected first upload response: %+v", firstResp)
	}

	secondReq := newMultipartUploadRequest(t, payload, "IMG_7777_COPY.HEIC", "IMG_7777_COPY.HEIC", createdAt, "21")
	secondRR := httptest.NewRecorder()

	// When
	app.handleUpload(secondRR, secondReq)

	// Then
	if secondRR.Code != http.StatusOK {
		t.Fatalf("expected second upload status 200, got %d body=%s", secondRR.Code, secondRR.Body.String())
	}

	var secondResp uploadResult
	if err := json.Unmarshal(secondRR.Body.Bytes(), &secondResp); err != nil {
		t.Fatalf("failed to decode second upload response: %v", err)
	}
	if !secondResp.OK || !secondResp.Duplicate || secondResp.Saved {
		t.Fatalf("unexpected second upload response: %+v", secondResp)
	}
	if secondResp.ExistingPath != firstResp.SavedPath {
		t.Fatalf("expected duplicate to point to %q, got %q", firstResp.SavedPath, secondResp.ExistingPath)
	}

	files, err := os.ReadDir(filepath.Join(app.backupDir, "2026-05"))
	if err != nil {
		t.Fatalf("failed to read month dir: %v", err)
	}
	if len(files) != 1 {
		t.Fatalf("expected exactly one saved file in month dir, got %d", len(files))
	}
}

func TestGivenBatchCheck_WhenSomeFilesExist_ThenReturnsCorrectStatusMap(t *testing.T) {
	t.Helper()
	app := newTestApp(t)

	// Given - upload one file to make it exist
	payload := []byte("batch-check-content")
	createdAt := "2026-05-21T10:00:00+09:00"
	uploadReq := newMultipartUploadRequest(t, payload, "IMG_5555.HEIC", "IMG_5555.HEIC", createdAt, "19")
	uploadRR := httptest.NewRecorder()
	app.handleUpload(uploadRR, uploadReq)

	if uploadRR.Code != http.StatusOK {
		t.Fatalf("expected upload status 200, got %d", uploadRR.Code)
	}

	// Prepare batch check request
	batchReqBody := map[string]any{
		"files": []map[string]string{
			{
				"original_name": "IMG_5555.HEIC",
				"created_at":    createdAt,
			},
			{
				"original_name": "IMG_9999.HEIC", // does not exist
				"created_at":    createdAt,
			},
		},
	}
	req := newJSONRequest(t, "/check-batch", batchReqBody)
	rr := httptest.NewRecorder()

	// When
	app.handleCheckBatch(rr, req)

	// Then
	if rr.Code != http.StatusOK {
		t.Fatalf("expected check-batch status 200, got %d body=%s", rr.Code, rr.Body.String())
	}

	var results map[string]bool
	if err := json.Unmarshal(rr.Body.Bytes(), &results); err != nil {
		t.Fatalf("failed to decode check-batch response: %v", err)
	}

	keyExist := "IMG_5555.HEIC|2026-05-21T10:00:00+09:00"
	keyNotExist := "IMG_9999.HEIC|2026-05-21T10:00:00+09:00"

	if val, ok := results[keyExist]; !ok || !val {
		t.Fatalf("expected key %q to be true (exists), got %v (all: %v)", keyExist, val, results)
	}
	if val, ok := results[keyNotExist]; !ok || val {
		t.Fatalf("expected key %q to be false (does not exist), got %v (all: %v)", keyNotExist, val, results)
	}
}

func newTestApp(t *testing.T) *app {
	t.Helper()

	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, ".tmp"), 0o755); err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	db, err := openDB(filepath.Join(root, dbFileName))
	if err != nil {
		t.Fatalf("failed to open db: %v", err)
	}
	t.Cleanup(func() {
		_ = db.Close()
	})

	return &app{
		db:        db,
		backupDir: root,
		maxBytes:  defaultMaxBytes,
	}
}

func newJSONRequest(t *testing.T, target string, body map[string]any) *http.Request {
	t.Helper()

	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("failed to marshal json request: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, target, bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
	return req
}

func newMultipartUploadRequest(t *testing.T, payload []byte, uploadFileName string, originalName string, createdAt string, fileSize string) *http.Request {
	t.Helper()

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	fileWriter, err := writer.CreateFormFile("file", uploadFileName)
	if err != nil {
		t.Fatalf("failed to create multipart file field: %v", err)
	}
	if _, err := io.Copy(fileWriter, bytes.NewReader(payload)); err != nil {
		t.Fatalf("failed to write multipart payload: %v", err)
	}
	if err := writer.WriteField("original_name", originalName); err != nil {
		t.Fatalf("failed to write original_name: %v", err)
	}
	if err := writer.WriteField("created_at", createdAt); err != nil {
		t.Fatalf("failed to write created_at: %v", err)
	}
	if err := writer.WriteField("file_size", fileSize); err != nil {
		t.Fatalf("failed to write file_size: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("failed to close multipart writer: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/upload", &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	return req
}
