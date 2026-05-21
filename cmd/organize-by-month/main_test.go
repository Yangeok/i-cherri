package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParseExifDateTime(t *testing.T) {
	tests := []struct {
		input    string
		expected time.Time
		wantErr  bool
	}{
		{"2023:05:21 14:30:00", time.Date(2023, 5, 21, 14, 30, 0, 0, time.UTC), false},
		{"2024-12-31 23:59:59", time.Date(2024, 12, 31, 23, 59, 59, 0, time.UTC), false},
		{"invalid date", time.Time{}, true},
	}

	for _, tt := range tests {
		got, err := parseExifDateTime(tt.input)
		if (err != nil) != tt.wantErr {
			t.Errorf("parseExifDateTime(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			continue
		}
		if !tt.wantErr && !got.Equal(tt.expected) {
			t.Errorf("parseExifDateTime(%q) = %v, want %v", tt.input, got, tt.expected)
		}
	}
}

func TestUniquePath(t *testing.T) {
	tempDir := t.TempDir()
	target := filepath.Join(tempDir, "test.txt")

	// 1. Target doesn't exist on disk, map is empty -> should return target
	used := make(map[string]bool)
	got := uniquePath(target, used)
	if got != target {
		t.Errorf("expected %q, got %q", target, got)
	}

	// 2. Target exists in used map -> should append suffix _1
	used[target] = true
	got = uniquePath(target, used)
	expected := filepath.Join(tempDir, "test_1.txt")
	if got != expected {
		t.Errorf("expected %q, got %q", expected, got)
	}

	// 3. Target exists on disk -> should append suffix _1 (or next free)
	err := os.WriteFile(target, []byte("hello"), 0644)
	if err != nil {
		t.Fatal(err)
	}
	used = make(map[string]bool)
	got = uniquePath(target, used)
	if got != expected {
		t.Errorf("expected %q, got %q", expected, got)
	}
}

func TestOrganizeWithAaeCompanion(t *testing.T) {
	// Create temp directories
	srcDir := t.TempDir()
	dstDir := t.TempDir()

	// 1. Create a media file with a specific modification time
	// (We won't make a real EXIF header, so it falls back to mod time)
	mediaPath := filepath.Join(srcDir, "IMG_1234.HEIC")
	err := os.WriteFile(mediaPath, []byte("fake heic data"), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Set mod time of the media file to 2022-08-15
	mediaTime := time.Date(2022, 8, 15, 12, 0, 0, 0, time.Local)
	err = os.Chtimes(mediaPath, mediaTime, mediaTime)
	if err != nil {
		t.Fatal(err)
	}

	// 2. Create a companion .aae file
	// Its mod time will be different (say, now), but since it shares the same base "IMG_1234",
	// it should be organized into the same folder as the HEIC: "2022-08"
	aaePath := filepath.Join(srcDir, "IMG_1234.AAE")
	err = os.WriteFile(aaePath, []byte("fake aae data"), 0644)
	if err != nil {
		t.Fatal(err)
	}
	aaeTime := time.Date(2026, 5, 21, 12, 0, 0, 0, time.Local)
	err = os.Chtimes(aaePath, aaeTime, aaeTime)
	if err != nil {
		t.Fatal(err)
	}

	// Run organize (copy mode = false, dryRun = false)
	organize(srcDir, dstDir, false, false)

	// Check if both files are moved to dstDir/2022-08/
	expectedMediaDst := filepath.Join(dstDir, "2022-08", "IMG_1234.HEIC")
	expectedAaeDst := filepath.Join(dstDir, "2022-08", "IMG_1234.AAE")

	if _, err := os.Stat(expectedMediaDst); os.IsNotExist(err) {
		t.Errorf("Media file was not organized to %s", expectedMediaDst)
	}

	if _, err := os.Stat(expectedAaeDst); os.IsNotExist(err) {
		t.Errorf("Companion AAE file was not organized to %s", expectedAaeDst)
	}
}
