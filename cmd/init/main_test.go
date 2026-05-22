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

func TestOrganizeSkipsAlreadyOrganizedAndSkipsYyyyMmDirs(t *testing.T) {
	srcDir := t.TempDir()
	dstDir := srcDir // same directory

	// Create a YYYY-MM directory
	alreadyOrganizedDir := filepath.Join(srcDir, "2021-09")
	err := os.MkdirAll(alreadyOrganizedDir, 0755)
	if err != nil {
		t.Fatal(err)
	}

	// Create a file in the YYYY-MM directory
	filePath := filepath.Join(alreadyOrganizedDir, "IMG_8477.JPG")
	err = os.WriteFile(filePath, []byte("fake jpeg"), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Set its mod time
	originalTime := time.Date(2021, 9, 15, 12, 0, 0, 0, time.Local)
	err = os.Chtimes(filePath, originalTime, originalTime)
	if err != nil {
		t.Fatal(err)
	}

	// Run organize (copy = false, dryRun = false)
	// Since 2021-09 is skipped, it should not process IMG_8477.JPG at all, and it should not rename it to _1.JPG!
	organize(srcDir, dstDir, false, false)

	// Verify the original file still exists and has not been renamed
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		t.Errorf("File %s was unexpectedly renamed or deleted!", filePath)
	}

	// Verify no _1.JPG file was created
	unexpectedPath := filepath.Join(alreadyOrganizedDir, "IMG_8477_1.JPG")
	if _, err := os.Stat(unexpectedPath); err == nil {
		t.Errorf("Unexpected renamed file %s was created!", unexpectedPath)
	}
}
