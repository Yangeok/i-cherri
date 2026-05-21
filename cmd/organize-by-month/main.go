package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var photoExts = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".heic": true,
	".heif": true,
	".png":  true,
	".dng":  true,
	".tiff": true,
	".tif":  true,
	".webp": true,
}

var videoExts = map[string]bool{
	".mov": true,
	".mp4": true,
	".m4v": true,
	".avi": true,
	".mkv": true,
}

var sidecarExts = map[string]bool{
	".aae": true,
}

type fileTask struct {
	srcPath string
	dstDir  string
	dstPath string
}

func main() {
	copyFlag := flag.Bool("copy", false, "Copy files instead of moving")
	dryRunFlag := flag.Bool("dry-run", false, "Dry run mode (no changes, print output only)")
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 || len(args) > 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s [--copy] [--dry-run] <src_dir> [dst_dir]\n", os.Args[0])
		os.Exit(1)
	}

	srcDir, err := filepath.Abs(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving source directory path: %v\n", err)
		os.Exit(1)
	}

	fi, err := os.Stat(srcDir)
	if err != nil || !fi.IsDir() {
		fmt.Fprintf(os.Stderr, "Error: %s is not a directory\n", srcDir)
		os.Exit(1)
	}

	dstDir := srcDir
	if len(args) == 2 {
		dstDir, err = filepath.Abs(args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error resolving destination directory path: %v\n", err)
			os.Exit(1)
		}
	}

	fmt.Printf("src: %s\n", srcDir)
	fmt.Printf("dst: %s\n", dstDir)
	mode := "move"
	if *copyFlag {
		mode = "copy"
	}
	dryRunLabel := ""
	if *dryRunFlag {
		dryRunLabel = " [dry-run]"
	}
	fmt.Printf("mode: %s%s\n\n", mode, dryRunLabel)

	organize(srcDir, dstDir, *copyFlag, *dryRunFlag)
}

func organize(srcDir, dstDir string, copy, dryRun bool) {
	var mediaPaths []string
	var sidecarPaths []string

	err := filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			// Skip year-month directories (e.g. 2021-09) to avoid reprocessing organized photos
			if path != srcDir && isYearMonthDir(d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if photoExts[ext] || videoExts[ext] {
			mediaPaths = append(mediaPaths, path)
		} else if sidecarExts[ext] {
			sidecarPaths = append(sidecarPaths, path)
		}
		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error walking directory: %v\n", err)
		return
	}

	if len(mediaPaths) == 0 && len(sidecarPaths) == 0 {
		fmt.Println("No files to organize.")
		return
	}

	// Sort paths to keep ordering consistent
	sort.Strings(mediaPaths)
	sort.Strings(sidecarPaths)

	// Step 1: Map companionKey to target Date
	companionDates := make(map[string]time.Time)
	var tasks []fileTask

	for _, path := range mediaPaths {
		dt := getDate(path)
		dir := filepath.Dir(path)
		ext := filepath.Ext(path)
		baseWithoutExt := strings.TrimSuffix(filepath.Base(path), ext)
		companionKey := strings.ToLower(filepath.Join(dir, baseWithoutExt))

		companionDates[companionKey] = dt

		folderName := dt.Format("2006-01")
		targetFolder := filepath.Join(dstDir, folderName)

		tasks = append(tasks, fileTask{
			srcPath: path,
			dstDir:  targetFolder,
		})
	}

	// Step 2: Handle .aae sidecars
	for _, path := range sidecarPaths {
		dir := filepath.Dir(path)
		ext := filepath.Ext(path)
		baseWithoutExt := strings.TrimSuffix(filepath.Base(path), ext)
		companionKey := strings.ToLower(filepath.Join(dir, baseWithoutExt))

		var dt time.Time
		if companionDt, exists := companionDates[companionKey]; exists {
			dt = companionDt
		} else {
			// Fallback to file mod time
			fi, err := os.Stat(path)
			if err == nil {
				dt = fi.ModTime()
			} else {
				dt = time.Now()
			}
		}

		folderName := dt.Format("2006-01")
		targetFolder := filepath.Join(dstDir, folderName)

		tasks = append(tasks, fileTask{
			srcPath: path,
			dstDir:  targetFolder,
		})
	}

	// Step 3: Sort tasks by source path for clear output
	sort.Slice(tasks, func(i, j int) bool {
		return tasks[i].srcPath < tasks[j].srcPath
	})

	// To prevent name collisions during processing, we keep track of destination paths used
	usedDstPaths := make(map[string]bool)

	// Compute unique destination paths
	for i := range tasks {
		relFolder := tasks[i].dstDir
		fileName := filepath.Base(tasks[i].srcPath)
		targetPath := filepath.Join(relFolder, fileName)

		// Safety: if the file is already at the target destination, do not rename or move it
		if tasks[i].srcPath == targetPath {
			tasks[i].dstPath = targetPath
			usedDstPaths[targetPath] = true
			continue
		}

		dstPath := uniquePath(targetPath, usedDstPaths)
		tasks[i].dstPath = dstPath
		usedDstPaths[dstPath] = true
	}

	okCount := 0
	errCount := 0

	for _, task := range tasks {
		action := "move"
		if copy {
			action = "copy"
		}

		srcRel, err := filepath.Rel(srcDir, task.srcPath)
		if err != nil {
			srcRel = task.srcPath
		}
		dstRel, err := filepath.Rel(dstDir, task.dstPath)
		if err != nil {
			dstRel = task.dstPath
		}

		if task.srcPath == task.dstPath {
			// Skip actual operation and printing for files already in the correct place
			okCount++
			continue
		}

		fmt.Printf("[%s] %s  →  %s\n", action, srcRel, dstRel)

		if !dryRun {
			err := os.MkdirAll(task.dstDir, 0755)
			if err != nil {
				fmt.Printf("[skip] %s: failed to create folder %s: %v\n", filepath.Base(task.srcPath), task.dstDir, err)
				errCount++
				continue
			}

			if copy {
				err = copyFile(task.srcPath, task.dstPath)
			} else {
				err = moveFile(task.srcPath, task.dstPath)
			}

			if err != nil {
				fmt.Printf("[skip] %s: operation failed: %v\n", filepath.Base(task.srcPath), err)
				errCount++
			} else {
				okCount++
			}
		} else {
			okCount++
		}
	}

	label := ""
	if dryRun {
		label = "(dry-run) "
	}
	fmt.Printf("\n%sFinished: %d processed, %d errors, 0 skipped\n", label, okCount, errCount)
}

func isYearMonthDir(name string) bool {
	if len(name) != 7 {
		return false
	}
	if name[4] != '-' {
		return false
	}
	for i := 0; i < 7; i++ {
		if i == 4 {
			continue
		}
		if name[i] < '0' || name[i] > '9' {
			return false
		}
	}
	return true
}

func uniquePath(targetPath string, usedPaths map[string]bool) string {
	// If path doesn't exist on disk AND hasn't been reserved in this execution run
	if _, existsOnDisk := os.Stat(targetPath); os.IsNotExist(existsOnDisk) && !usedPaths[targetPath] {
		return targetPath
	}

	dir := filepath.Dir(targetPath)
	ext := filepath.Ext(targetPath)
	base := strings.TrimSuffix(filepath.Base(targetPath), ext)

	i := 1
	for {
		candidate := filepath.Join(dir, fmt.Sprintf("%s_%d%s", base, i, ext))
		if _, existsOnDisk := os.Stat(candidate); os.IsNotExist(existsOnDisk) && !usedPaths[candidate] {
			return candidate
		}
		i++
	}
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err = io.Copy(out, in); err != nil {
		return err
	}

	si, err := os.Stat(src)
	if err != nil {
		return err
	}
	return os.Chtimes(dst, si.ModTime(), si.ModTime())
}

func moveFile(src, dst string) error {
	err := os.Rename(src, dst)
	if err == nil {
		return nil
	}
	// Fallback for cross-device mount links
	if err := copyFile(src, dst); err != nil {
		return err
	}
	return os.Remove(src)
}

// ── DATE PARSING FUNCTIONS ───────────────────────────────────────────────────

func getDate(path string) time.Time {
	ext := strings.ToLower(filepath.Ext(path))
	var dt *time.Time

	if ext == ".jpg" || ext == ".jpeg" {
		dt, _ = readExifDateJPEG(path)
	} else if ext == ".heic" || ext == ".heif" {
		dt, _ = readExifDateHEIC(path)
	} else if videoExts[ext] {
		dt, _ = readDateVideo(path)
	}

	if dt == nil {
		fi, err := os.Stat(path)
		if err == nil {
			mtime := fi.ModTime()
			dt = &mtime
		} else {
			now := time.Now()
			dt = &now
		}
	}

	return *dt
}

func readExifDateJPEG(path string) (*time.Time, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	hdr := make([]byte, 2)
	if _, err := io.ReadFull(f, hdr); err != nil || hdr[0] != 0xff || hdr[1] != 0xd8 {
		return nil, errors.New("not a jpeg")
	}

	for {
		marker := make([]byte, 2)
		if _, err := io.ReadFull(f, marker); err != nil {
			break
		}
		if marker[0] != 0xff {
			break
		}
		var segLen uint16
		if err := binary.Read(f, binary.BigEndian, &segLen); err != nil {
			break
		}
		if segLen < 2 {
			break
		}
		segLen -= 2

		if marker[1] == 0xe1 { // APP1
			data := make([]byte, segLen)
			if _, err := io.ReadFull(f, data); err != nil {
				break
			}
			return parseExifBlock(data)
		} else {
			if _, err := f.Seek(int64(segLen), io.SeekCurrent); err != nil {
				break
			}
		}
	}
	return nil, errors.New("no exif app1")
}

func parseExifBlock(data []byte) (*time.Time, error) {
	if len(data) < 6 {
		return nil, errors.New("too short")
	}
	if string(data[:4]) != "Exif" || data[4] != 0 || data[5] != 0 {
		return nil, errors.New("invalid exif header")
	}
	tiff := data[6:]
	if len(tiff) < 8 {
		return nil, errors.New("too short tiff")
	}
	byteOrder := string(tiff[:2])
	var endian binary.ByteOrder
	if byteOrder == "II" {
		endian = binary.LittleEndian
	} else if byteOrder == "MM" {
		endian = binary.BigEndian
	} else {
		return nil, errors.New("invalid byte order")
	}

	ifd0Off := endian.Uint32(tiff[4:8])
	if int(ifd0Off) >= len(tiff) {
		return nil, errors.New("invalid ifd0 offset")
	}

	u16 := func(off int) uint16 {
		if off+2 > len(tiff) {
			return 0
		}
		return endian.Uint16(tiff[off : off+2])
	}
	u32 := func(off int) uint32 {
		if off+4 > len(tiff) {
			return 0
		}
		return endian.Uint32(tiff[off : off+4])
	}

	n := u16(int(ifd0Off))
	var exifIfdOff uint32
	for i := 0; i < int(n); i++ {
		entry := int(ifd0Off) + 2 + i*12
		tag := u16(entry)
		if tag == 0x8769 {
			exifIfdOff = u32(entry + 8)
			break
		}
	}

	parseDateFromIFD := func(offset uint32) *time.Time {
		if offset == 0 || int(offset) >= len(tiff) {
			return nil
		}
		numEntries := u16(int(offset))
		for i := 0; i < int(numEntries); i++ {
			entry := int(offset) + 2 + i*12
			tag := u16(entry)
			if tag == 0x9003 || tag == 0x9004 || tag == 0x0132 {
				count := u32(entry + 4)
				valOff := u32(entry + 8)
				if count <= 4 {
					valOff = uint32(entry + 8)
				}
				if int(valOff)+19 > len(tiff) {
					continue
				}
				raw := string(tiff[valOff : valOff+19])
				raw = strings.Trim(raw, "\x00 ")
				if t, err := parseExifDateTime(raw); err == nil {
					return &t
				}
			}
		}
		return nil
	}

	if t := parseDateFromIFD(ifd0Off); t != nil {
		return t, nil
	}
	if exifIfdOff != 0 {
		if t := parseDateFromIFD(exifIfdOff); t != nil {
			return t, nil
		}
	}

	return nil, errors.New("datetime tag not found")
}

func parseExifDateTime(s string) (time.Time, error) {
	if t, err := time.Parse("2006:01:02 15:04:05", s); err == nil {
		return t, nil
	}
	return time.Parse("2006-01-02 15:04:05", s)
}

func readExifDateHEIC(path string) (*time.Time, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	idx := 0
	for {
		pos := bytes.Index(data[idx:], []byte("Exif\x00\x00"))
		if pos == -1 {
			break
		}
		actualPos := idx + pos
		end := actualPos + 65536
		if end > len(data) {
			end = len(data)
		}
		if t, err := parseExifBlock(data[actualPos:end]); err == nil {
			return t, nil
		}
		idx = actualPos + 1
	}
	return nil, errors.New("no exif found in heic")
}

var macEpoch = time.Date(1904, 1, 1, 0, 0, 0, 0, time.UTC)

func readDateVideo(path string) (*time.Time, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return parseMP4Boxes(f, 0, 0)
}

func parseMP4Boxes(f *os.File, limit int64, depth int) (*time.Time, error) {
	if depth > 6 {
		return nil, errors.New("depth limit reached")
	}
	start, err := f.Seek(0, io.SeekCurrent)
	if err != nil {
		return nil, err
	}

	for {
		hdr := make([]byte, 8)
		if _, err := io.ReadFull(f, hdr); err != nil {
			break
		}
		size := int64(binary.BigEndian.Uint32(hdr[0:4]))
		box := string(hdr[4:8])

		var dataSize int64
		if size == 1 {
			sizeHdr := make([]byte, 8)
			if _, err := io.ReadFull(f, sizeHdr); err != nil {
				break
			}
			size = int64(binary.BigEndian.Uint64(sizeHdr))
			dataSize = size - 16
		} else if size == 0 {
			break
		} else {
			dataSize = size - 8
		}

		pos, err := f.Seek(0, io.SeekCurrent)
		if err != nil {
			break
		}

		if box == "moov" || box == "udta" || box == "meta" || box == "ilst" {
			t, err := parseMP4Boxes(f, dataSize, depth+1)
			if err == nil && t != nil {
				return t, nil
			}
		} else if box == "mvhd" {
			readLen := dataSize
			if readLen > 28 {
				readLen = 28
			}
			raw := make([]byte, readLen)
			if _, err := io.ReadFull(f, raw); err == nil && len(raw) > 0 {
				version := raw[0]
				var ts uint64
				if version == 1 && len(raw) >= 25 {
					ts = binary.BigEndian.Uint64(raw[8:16])
				} else if version == 0 && len(raw) >= 13 {
					ts = uint64(binary.BigEndian.Uint32(raw[4:8]))
				}
				if ts > 0 {
					dt := macEpoch.Add(time.Duration(ts) * time.Second)
					if dt.Year() >= 2000 && dt.Year() <= 2100 {
						return &dt, nil
					}
				}
			}
		}

		if _, err := f.Seek(pos+dataSize, io.SeekStart); err != nil {
			break
		}

		current, err := f.Seek(0, io.SeekCurrent)
		if err != nil {
			break
		}
		if limit > 0 && current >= start+limit {
			break
		}
	}
	return nil, errors.New("mvhd not found")
}
