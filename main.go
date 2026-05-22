package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

const (
	defaultAddr      = ":8787"
	defaultBackupDir = "~/Photos"
	defaultMaxBytes  = int64(2147483648)
	dbFileName       = ".i-cherri.sqlite3"
)

type app struct {
	db        *sql.DB
	backupDir string
	maxBytes  int64
	saveMu    sync.Mutex
}

type uploadResult struct {
	OK           bool   `json:"ok"`
	Duplicate    bool   `json:"duplicate"`
	Saved        bool   `json:"saved"`
	SavedPath    string `json:"saved_path,omitempty"`
	ExistingPath string `json:"existing_path,omitempty"`
	Bytes        int64  `json:"bytes"`
	SHA256       string `json:"sha256"`
}

var buildTime = "unknown"

func main() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	reindexFlag := flag.Bool("reindex", false, "scan backup_dir and rebuild sqlite index")
	flag.Parse()

	log.Printf("i-cherri starting (build: %s)", buildTime)

	backupDir, err := resolveBackupDir()
	if err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(backupDir, 0o755); err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(backupDir, ".tmp"), 0o755); err != nil {
		log.Fatal(err)
	}

	dbPath := filepath.Join(backupDir, dbFileName)
	db, err := openDB(dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if *reindexFlag {
		if err := reindex(db, backupDir); err != nil {
			log.Fatal(err)
		}
		return
	}

	app := &app{
		db:        db,
		backupDir: backupDir,
		maxBytes:  defaultMaxBytes,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.handleHealth)
	mux.HandleFunc("/check", app.handleCheck)
	mux.HandleFunc("/check-batch", app.handleCheckBatch)
	mux.HandleFunc("/upload", app.handleUpload)

	// 모든 요청을 진입점에서 로깅하는 미들웨어
	rootHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("[ENTRY] %s %s from %s (Length: %d, Type: %s)", 
			r.Method, r.URL.Path, r.RemoteAddr, r.ContentLength, r.Header.Get("Content-Type"))
		mux.ServeHTTP(w, r)
	})

	server := &http.Server{
		Addr:              defaultAddr,
		Handler:           rootHandler,
		ReadHeaderTimeout: 10 * time.Second,
	}

	log.Printf("server addr: %s", defaultAddr)
	log.Printf("backup dir: %s", backupDir)
	log.Printf("sqlite db: %s", dbPath)
	log.Fatal(server.ListenAndServe())
}

func (a *app) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		log.Printf("health rejected remote=%s method=%s", r.RemoteAddr, r.Method)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	log.Printf("health remote=%s", r.RemoteAddr)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = io.WriteString(w, "ok")
}

func (a *app) handleCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		log.Printf("check rejected remote=%s method=%s", r.RemoteAddr, r.Method)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()
	var payload map[string]any
	decoder := json.NewDecoder(r.Body)
	decoder.UseNumber()
	if err := decoder.Decode(&payload); err != nil {
		log.Printf("check invalid-json remote=%s err=%v", r.RemoteAddr, err)
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid json"})
		return
	}

	originalName := strings.TrimSpace(stringValue(payload["original_name"]))
	createdAt := normalizeCreatedAt(strings.TrimSpace(stringValue(payload["created_at"])))

	savedPath, exists, err := lookupByMetadata(r.Context(), a.db, originalName, createdAt)
	if err != nil {
		log.Printf("check failed name=%q err=%v", originalName, err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "check failed"})
		return
	}

	log.Printf("check remote=%s exists=%t original_name=%q", r.RemoteAddr, exists, originalName)
	if exists {
		writeJSON(w, http.StatusOK, map[string]any{
			"exists":     true,
			"matched_by": "metadata",
			"saved_path": savedPath,
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"exists": false,
	})
}

type checkItem struct {
	OriginalName string `json:"original_name"`
	CreatedAt    string `json:"created_at"`
}

type checkBatchRequest struct {
	Files []checkItem `json:"files"`
}

func (a *app) handleCheckBatch(w http.ResponseWriter, r *http.Request) {
	log.Printf("[REQ] POST /check-batch from %s", r.RemoteAddr)
	if r.Method != http.MethodPost {
		log.Printf("check-batch rejected remote=%s method=%s", r.RemoteAddr, r.Method)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()
	var req checkBatchRequest
	decoder := json.NewDecoder(r.Body)
	decoder.UseNumber()
	if err := decoder.Decode(&req); err != nil {
		log.Printf("check-batch invalid-json remote=%s err=%v", r.RemoteAddr, err)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	results := make(map[string]bool)
	for _, file := range req.Files {
		originalName := strings.TrimSpace(file.OriginalName)
		createdAt := normalizeCreatedAt(strings.TrimSpace(file.CreatedAt))
		key := fmt.Sprintf("%s|%s", originalName, createdAt)
		key = strings.ReplaceAll(key, ".", "_")

		_, exists, err := lookupByMetadata(r.Context(), a.db, originalName, createdAt)
		if err != nil {
			log.Printf("check-batch lookup failed original_name=%q created_at=%q err=%v", originalName, createdAt, err)
			results[key] = false
			continue
		}
		results[key] = exists
	}

	log.Printf("check-batch remote=%s count=%d", r.RemoteAddr, len(req.Files))
	writeJSON(w, http.StatusOK, results)
}

func (a *app) handleUpload(w http.ResponseWriter, r *http.Request) {
	log.Printf("[REQ] POST /upload from %s", r.RemoteAddr)
	if r.Method != http.MethodPost {
		log.Printf("upload rejected remote=%s method=%s", r.RemoteAddr, r.Method)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	contentType := r.Header.Get("Content-Type")
	log.Printf("upload attempt remote=%s content-type=%q", r.RemoteAddr, contentType)

	switch {
	case strings.HasPrefix(contentType, "multipart/form-data"):
		a.handleMultipartUpload(w, r)
	case strings.HasPrefix(contentType, "application/json"):
		a.handleJSONUpload(w, r)
	default:
		a.handleRawBodyUpload(w, r)
	}
}

func (a *app) handleJSONUpload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, a.maxBytes*2)

	var payload struct {
		FileData     string `json:"file_data"`
		OriginalName string `json:"original_name"`
		CreatedAt    string `json:"created_at"`
		FileSize     string `json:"file_size"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		log.Printf("upload json-decode-failed remote=%s err=%v", r.RemoteAddr, err)
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid json"})
		return
	}

	fileBytes, err := base64.StdEncoding.DecodeString(payload.FileData)
	if err != nil {
		// iOS Shortcuts may produce URL-safe or padded variants
		fileBytes, err = base64.RawStdEncoding.DecodeString(payload.FileData)
		if err != nil {
			log.Printf("upload base64-decode-failed remote=%s err=%v", r.RemoteAddr, err)
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid base64"})
			return
		}
	}

	a.saveUpload(w, r, bytes.NewReader(fileBytes), payload.OriginalName, "", payload.CreatedAt)
}

func (a *app) handleMultipartUpload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, a.maxBytes)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		log.Printf("upload parse-failed remote=%s err=%v", r.RemoteAddr, err)
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": fmt.Sprintf("invalid multipart request: %v", err)})
		return
	}
	defer func() { _ = r.MultipartForm.RemoveAll() }()

	file, header, err := r.FormFile("file")
	if err != nil {
		log.Printf("upload missing-file remote=%s err=%v", r.RemoteAddr, err)
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "missing or invalid file field"})
		return
	}
	defer file.Close()

	originalName := r.FormValue("original_name")
	if originalName == "" {
		originalName = header.Filename
	}
	createdAtRaw := r.FormValue("created_at")

	a.saveUpload(w, r, file, originalName, header.Filename, createdAtRaw)
}

func (a *app) handleRawBodyUpload(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	originalName := q.Get("original_name")
	if originalName == "" {
		originalName = r.Header.Get("X-Original-Name")
	}
	createdAtRaw := q.Get("created_at")
	if createdAtRaw == "" {
		createdAtRaw = r.Header.Get("X-Created-At")
	}

	r.Body = http.MaxBytesReader(w, r.Body, a.maxBytes)
	a.saveUpload(w, r, r.Body, originalName, "", createdAtRaw)
}

func detectExt(p []byte) string {
	if len(p) < 4 {
		return ""
	}
	if p[0] == 0xFF && p[1] == 0xD8 && p[2] == 0xFF {
		return ".jpg"
	}
	if p[0] == 0x89 && p[1] == 0x50 && p[2] == 0x4E && p[3] == 0x47 {
		return ".png"
	}
	if p[0] == 0x47 && p[1] == 0x49 && p[2] == 0x46 {
		return ".gif"
	}
	if len(p) >= 12 {
		ftyp := string(p[4:8])
		brand := string(p[8:12])
		if ftyp == "ftyp" {
			switch brand {
			case "heic", "heix", "hevc", "hevx":
				return ".heic"
			case "mif1", "msf1":
				return ".heif"
			case "avif":
				return ".avif"
			case "qt  ":
				return ".mov"
			default:
				if strings.HasPrefix(brand, "mp4") || brand == "isom" || brand == "M4V " {
					return ".mp4"
				}
			}
		}
	}
	if len(p) >= 12 && p[0] == 0x52 && p[1] == 0x49 && p[2] == 0x46 && p[3] == 0x46 &&
		p[8] == 0x57 && p[9] == 0x45 && p[10] == 0x42 && p[11] == 0x50 {
		return ".webp"
	}
	return ""
}

func (a *app) saveUpload(w http.ResponseWriter, r *http.Request, src io.Reader, originalName, fallbackName, createdAtRaw string) {
	// Peek first 16 bytes for magic-number extension detection
	var peek [16]byte
	n, _ := io.ReadFull(src, peek[:])
	src = io.MultiReader(bytes.NewReader(peek[:n]), src)

	tmpFile, err := os.CreateTemp(filepath.Join(a.backupDir, ".tmp"), "upload-*")
	if err != nil {
		log.Printf("upload tmp-create-failed err=%v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to create temp file"})
		return
	}
	defer func() {
		if tmpFile != nil {
			_ = tmpFile.Close()
			_ = os.Remove(tmpFile.Name())
		}
	}()

	hasher := sha256.New()
	written, err := io.Copy(io.MultiWriter(tmpFile, hasher), src)
	if err != nil {
		log.Printf("upload copy-failed err=%v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to save uploaded file"})
		return
	}
	_ = tmpFile.Close()

	if written == 0 {
		log.Printf("upload empty-body remote=%s", r.RemoteAddr)
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "empty body"})
		return
	}

	shaValue := hex.EncodeToString(hasher.Sum(nil))
	finalName := sanitizeFilename(chooseOriginalName(originalName, fallbackName))
	if finalName == "" {
		finalName = generatedName("upload", time.Now())
	}
	if filepath.Ext(finalName) == "" {
		if ext := detectExt(peek[:n]); ext != "" {
			finalName += ext
		}
	}

	createdAtTime, createdAtStored := parseCreatedAtOrNow(createdAtRaw)
	monthFolder := createdAtTime.Format("2006-01")
	targetDir := filepath.Join(a.backupDir, monthFolder)
	_ = os.MkdirAll(targetDir, 0o755)

	a.saveMu.Lock()
	defer a.saveMu.Unlock()

	if existingPath, exists, err := lookupBySHA(r.Context(), a.db, shaValue); err == nil && exists {
		log.Printf("upload sha-duplicate remote=%s sha256=%s existing=%s", r.RemoteAddr, shaValue, existingPath)
		writeJSON(w, http.StatusOK, uploadResult{OK: true, Duplicate: true, ExistingPath: existingPath, SHA256: shaValue})
		return
	}

	targetPath, _ := uniqueTargetPath(targetDir, finalName)
	if err := os.Rename(tmpFile.Name(), targetPath); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to move file"})
		return
	}
	tmpFile = nil

	uploadedAt := time.Now().Format(time.RFC3339)
	_ = insertFile(r.Context(), a.db, shaValue, finalName, targetPath, createdAtStored, written, uploadedAt)

	log.Printf("upload success remote=%s name=%q sha256=%s", r.RemoteAddr, finalName, shaValue)
	writeJSON(w, http.StatusOK, uploadResult{OK: true, Saved: true, SavedPath: targetPath, Bytes: written, SHA256: shaValue})
}

func openDB(dbPath string) (*sql.DB, error) {
	db, err := openDBOnce(dbPath)
	if err != nil {
		// corrupt WAL/SHM leftover — wipe and retry once
		log.Printf("db open failed (%v), removing corrupt files and retrying", err)
		for _, suf := range []string{"", "-wal", "-shm"} {
			_ = os.Remove(dbPath + suf)
		}
		db, err = openDBOnce(dbPath)
	}
	return db, err
}

func openDBOnce(dbPath string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	pragmas := []string{
		"PRAGMA journal_mode=WAL;",
		"PRAGMA busy_timeout=5000;",
	}
	for _, pragma := range pragmas {
		if _, err := db.Exec(pragma); err != nil {
			_ = db.Close()
			return nil, err
		}
	}

	schema := []string{
		`CREATE TABLE IF NOT EXISTS files (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			sha256 TEXT NOT NULL UNIQUE,
			original_name TEXT,
			saved_path TEXT NOT NULL,
			created_at TEXT,
			file_size INTEGER NOT NULL,
			uploaded_at TEXT NOT NULL
		);`,
		`CREATE INDEX IF NOT EXISTS idx_files_metadata
			ON files(original_name, created_at, file_size);`,
		`CREATE INDEX IF NOT EXISTS idx_files_created_at
			ON files(created_at);`,
		`CREATE INDEX IF NOT EXISTS idx_files_original_name
			ON files(original_name);`,
	}
	for _, statement := range schema {
		if _, err := db.Exec(statement); err != nil {
			_ = db.Close()
			return nil, err
		}
	}

	return db, nil
}

func reindex(db *sql.DB, backupDir string) error {
	log.Printf("reindex start backup_dir=%s", backupDir)

	inserted := 0
	updated := 0
	seen := 0

	err := filepath.WalkDir(backupDir, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == backupDir {
			return nil
		}

		name := d.Name()
		if d.IsDir() {
			if name == ".tmp" || strings.HasPrefix(name, ".") {
				return filepath.SkipDir
			}
			return nil
		}

		if name == ".DS_Store" || name == dbFileName || strings.HasPrefix(name, ".") {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return nil
		}

		shaValue, err := sha256File(path)
		if err != nil {
			return err
		}

		now := time.Now().Format(time.RFC3339)
		createdAt := info.ModTime().Format(time.RFC3339)
		res, err := db.ExecContext(
			context.Background(),
			`INSERT INTO files (sha256, original_name, saved_path, created_at, file_size, uploaded_at)
			 VALUES (?, ?, ?, ?, ?, ?)
			 ON CONFLICT(sha256) DO UPDATE SET
			   original_name = excluded.original_name,
			   saved_path = excluded.saved_path,
			   created_at = excluded.created_at,
			   file_size = excluded.file_size,
			   uploaded_at = excluded.uploaded_at`,
			shaValue,
			name,
			path,
			createdAt,
			info.Size(),
			now,
		)
		if err != nil {
			return err
		}

		affected, _ := res.RowsAffected()
		if affected > 0 {
			inserted++
		} else {
			updated++
		}
		seen++
		return nil
	})
	if err != nil {
		return err
	}

	log.Printf("reindex done scanned=%d inserted_or_updated=%d updated_hint=%d", seen, inserted, updated)
	return nil
}

func lookupByMetadata(ctx context.Context, db *sql.DB, originalName, createdAt string) (string, bool, error) {
	var savedPath string
	err := db.QueryRowContext(
		ctx,
		`SELECT saved_path
		 FROM files
		 WHERE original_name = ? AND created_at = ?
		 LIMIT 1`,
		originalName,
		createdAt,
	).Scan(&savedPath)
	if errors.Is(err, sql.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return savedPath, true, nil
}

func lookupBySHA(ctx context.Context, db *sql.DB, shaValue string) (string, bool, error) {
	var savedPath string
	err := db.QueryRowContext(
		ctx,
		`SELECT saved_path
		 FROM files
		 WHERE sha256 = ?
		 LIMIT 1`,
		shaValue,
	).Scan(&savedPath)
	if errors.Is(err, sql.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return savedPath, true, nil
}

func insertFile(ctx context.Context, db *sql.DB, shaValue, originalName, savedPath, createdAt string, fileSize int64, uploadedAt string) error {
	_, err := db.ExecContext(
		ctx,
		`INSERT INTO files (sha256, original_name, saved_path, created_at, file_size, uploaded_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		shaValue,
		originalName,
		savedPath,
		createdAt,
		fileSize,
		uploadedAt,
	)
	return err
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	encoder := json.NewEncoder(w)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(value)
}

func stringValue(v any) string {
	switch typed := v.(type) {
	case string:
		return typed
	case json.Number:
		return typed.String()
	case float64:
		return strconv.FormatFloat(typed, 'f', -1, 64)
	default:
		return fmt.Sprintf("%v", v)
	}
}

func int64Value(v any) (int64, error) {
	switch typed := v.(type) {
	case nil:
		return 0, nil
	case int64:
		return typed, nil
	case int:
		return int64(typed), nil
	case float64:
		return int64(typed), nil
	case json.Number:
		return typed.Int64()
	case string:
		if strings.TrimSpace(typed) == "" {
			return 0, nil
		}
		return strconv.ParseInt(strings.TrimSpace(typed), 10, 64)
	default:
		return 0, fmt.Errorf("unsupported numeric value %T", v)
	}
}

func parseCreatedAtOrNow(raw string) (time.Time, string) {
	normalized := normalizeCreatedAt(raw)
	if normalized != "" {
		if parsed, err := time.Parse(time.RFC3339, normalized); err == nil {
			return parsed, normalized
		}
	}
	now := time.Now()
	return now, now.Format(time.RFC3339)
}

func normalizeCreatedAt(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if parsed, err := time.Parse(time.RFC3339, raw); err == nil {
		return parsed.Format(time.RFC3339)
	}
	layouts := []string{
		time.RFC3339Nano,
		"2006-01-02 15:04:05 -0700",
		"2006-01-02 15:04:05 -0700 MST",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed.Format(time.RFC3339)
		}
	}
	return raw
}

func chooseOriginalName(originalName, fallback string) string {
	originalName = strings.TrimSpace(originalName)
	if originalName != "" {
		return originalName
	}
	fallback = strings.TrimSpace(fallback)
	if fallback != "" {
		return fallback
	}
	return generatedName("upload", time.Now())
}

func generatedName(prefix string, now time.Time) string {
	return fmt.Sprintf("%s_%s", prefix, now.Format("20060102_150405"))
}

func sanitizeFilename(name string) string {
	name = filepath.Base(strings.TrimSpace(name))
	name = strings.ReplaceAll(name, "\x00", "")
	name = strings.ReplaceAll(name, "/", "_")
	name = strings.ReplaceAll(name, "\\", "_")
	name = strings.TrimSpace(name)
	if name == "" || name == "." || name == ".." {
		return ""
	}

	var builder strings.Builder
	for _, r := range name {
		switch {
		case r == ':' || r == '*' || r == '?' || r == '"' || r == '<' || r == '>' || r == '|':
			builder.WriteRune('_')
		case r < 32:
			builder.WriteRune('_')
		default:
			builder.WriteRune(r)
		}
	}
	cleaned := strings.Trim(strings.TrimSpace(builder.String()), ".")
	if cleaned == "" {
		return ""
	}
	return cleaned
}

func uniqueTargetPath(targetDir, fileName string) (string, error) {
	ext := filepath.Ext(fileName)
	base := strings.TrimSuffix(fileName, ext)
	if base == "" {
		base = "upload"
	}

	for i := 0; ; i++ {
		candidate := fileName
		if i > 0 {
			candidate = fmt.Sprintf("%s__%d%s", base, i, ext)
		}
		fullPath := filepath.Join(targetDir, candidate)
		_, err := os.Stat(fullPath)
		if errors.Is(err, os.ErrNotExist) {
			return fullPath, nil
		}
		if err != nil {
			return "", err
		}
	}
}

func sha256File(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(hasher.Sum(nil)), nil
}

func isUniqueConstraint(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(strings.ToLower(err.Error()), "unique constraint failed")
}

func isBodyTooLarge(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "request body too large")
}

func resolveBackupDir() (string, error) {
	return expandPath(defaultBackupDir)
}

func expandPath(path string) (string, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return "", fmt.Errorf("empty path")
	}
	if path == "~" || strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		if path == "~" {
			return home, nil
		}
		return filepath.Join(home, strings.TrimPrefix(path, "~/")), nil
	}
	return filepath.Clean(path), nil
}
