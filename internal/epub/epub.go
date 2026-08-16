// Package epub implements safe EPUB Open Container Format packing, unpacking,
// and structural inspection.
package epub

import (
	"archive/zip"
	"compress/flate"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

const MIMEType = "application/epub+zip"

var ErrInvalidEPUB = errors.New("invalid EPUB")

type PackOptions struct {
	Force bool
}

type UnpackOptions struct {
	Force  bool
	Limits Limits
}

type Limits struct {
	MaxFiles     int
	MaxFileSize  int64
	MaxTotalSize int64
	MaxRatio     uint64
}

var DefaultLimits = Limits{
	MaxFiles:     20_000,
	MaxFileSize:  512 << 20,
	MaxTotalSize: 2 << 30,
	MaxRatio:     1_000,
}

type Report struct {
	Path       string   `json:"path"`
	Valid      bool     `json:"valid"`
	EntryCount int      `json:"entryCount"`
	Rootfiles  []string `json:"rootfiles,omitempty"`
	Issues     []Issue  `json:"issues"`
}

type Issue struct {
	Level   string `json:"level"`
	Code    string `json:"code"`
	Message string `json:"message"`
}

type containerDocument struct {
	Rootfiles []rootfile `xml:"rootfiles>rootfile"`
}

type rootfile struct {
	FullPath  string `xml:"full-path,attr"`
	MediaType string `xml:"media-type,attr"`
}

type sourceEntry struct {
	absPath string
	name    string
	size    int64
}

func DefaultPackedPath(src string) string {
	clean := filepath.Clean(src)
	base := filepath.Base(clean)
	if strings.EqualFold(filepath.Ext(base), ".epub") {
		base = strings.TrimSuffix(base, filepath.Ext(base))
	}
	base = strings.TrimSuffix(base, "_pkg")
	return filepath.Join(filepath.Dir(clean), base+".epub")
}

func DefaultUnpackedPath(src string, packageDir bool) string {
	clean := filepath.Clean(src)
	base := filepath.Base(clean)
	if strings.EqualFold(filepath.Ext(base), ".epub") {
		base = strings.TrimSuffix(base, filepath.Ext(base))
	}
	if packageDir {
		base += "_pkg.epub"
	}
	return filepath.Join(filepath.Dir(clean), base)
}

func Pack(src, dst string, opts PackOptions) error {
	srcAbs, err := filepath.Abs(src)
	if err != nil {
		return err
	}
	dstAbs, err := filepath.Abs(dst)
	if err != nil {
		return err
	}
	if filepath.Ext(dstAbs) == "" {
		return fmt.Errorf("output must have an .epub extension")
	}
	if !strings.EqualFold(filepath.Ext(dstAbs), ".epub") {
		return fmt.Errorf("output must have an .epub extension")
	}
	if samePath(srcAbs, dstAbs) {
		return fmt.Errorf("source and output must differ")
	}

	entries, err := collectSource(srcAbs, dstAbs)
	if err != nil {
		return err
	}
	if err := validateSource(srcAbs, entries); err != nil {
		return err
	}
	if err := ensureReplaceable(dstAbs, opts.Force, false); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dstAbs), 0o755); err != nil {
		return err
	}

	tmp, err := os.CreateTemp(filepath.Dir(dstAbs), ".epubzip-pack-*.epub")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	committed := false
	defer func() {
		if !committed {
			_ = os.Remove(tmpName)
		}
	}()

	if err := writeArchive(tmp, entries); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	report, err := Inspect(tmpName)
	if err != nil {
		return err
	}
	if !report.Valid {
		return fmt.Errorf("%w: generated container did not pass self-check: %s", ErrInvalidEPUB, summarizeIssues(report.Issues))
	}
	if err := commitPath(tmpName, dstAbs, opts.Force); err != nil {
		return err
	}
	committed = true
	return nil
}

func Unpack(src, dst string, opts UnpackOptions) error {
	limits, err := normalizedLimits(opts.Limits)
	if err != nil {
		return err
	}
	srcAbs, err := filepath.Abs(src)
	if err != nil {
		return err
	}
	dstAbs, err := filepath.Abs(dst)
	if err != nil {
		return err
	}
	if samePath(srcAbs, dstAbs) {
		return fmt.Errorf("source and output must differ")
	}
	if err := ensureReplaceable(dstAbs, opts.Force, true); err != nil {
		return err
	}

	r, err := zip.OpenReader(srcAbs)
	if err != nil {
		return fmt.Errorf("%w: open ZIP container: %v", ErrInvalidEPUB, err)
	}
	defer r.Close()
	if err := validateArchiveForExtraction(&r.Reader, limits); err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(dstAbs), 0o755); err != nil {
		return err
	}
	tmp, err := os.MkdirTemp(filepath.Dir(dstAbs), ".epubzip-unpack-*")
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			_ = os.RemoveAll(tmp)
		}
	}()

	if err := extractAll(&r.Reader, tmp, limits); err != nil {
		return err
	}
	entries, err := collectSource(tmp, "")
	if err != nil {
		return err
	}
	if err := validateSource(tmp, entries); err != nil {
		return fmt.Errorf("%w: extracted structure: %v", ErrInvalidEPUB, err)
	}
	if err := commitPath(tmp, dstAbs, opts.Force); err != nil {
		return err
	}
	committed = true
	return nil
}

func Inspect(filename string) (Report, error) {
	report := Report{Path: filename, Issues: []Issue{}}
	r, err := zip.OpenReader(filename)
	if err != nil {
		return report, fmt.Errorf("%w: open ZIP container: %v", ErrInvalidEPUB, err)
	}
	defer r.Close()
	report.EntryCount = len(r.File)

	addError := func(code, message string) {
		report.Issues = append(report.Issues, Issue{Level: "error", Code: code, Message: message})
	}
	addWarning := func(code, message string) {
		report.Issues = append(report.Issues, Issue{Level: "warning", Code: code, Message: message})
	}

	if len(r.File) == 0 {
		addError("empty", "the ZIP container has no entries")
		report.Valid = false
		return report, nil
	}
	first := r.File[0]
	if first.Name != "mimetype" {
		addError("mimetype-order", "mimetype is not the first ZIP entry")
	}
	if first.Name == "mimetype" {
		if first.Method != zip.Store {
			addError("mimetype-compression", "mimetype must be stored without compression")
		}
		if len(first.Extra) != 0 {
			addError("mimetype-extra", "mimetype must not contain ZIP extra fields")
		}
	}

	byName := make(map[string]*zip.File, len(r.File))
	folded := make(map[string]string, len(r.File))
	for _, f := range r.File {
		if err := validateEntryName(f.Name); err != nil {
			addError("unsafe-path", fmt.Sprintf("%q: %v", f.Name, err))
		}
		if _, exists := byName[f.Name]; exists {
			addError("duplicate-entry", fmt.Sprintf("duplicate ZIP entry %q", f.Name))
		} else {
			byName[f.Name] = f
		}
		fold := strings.ToLower(f.Name)
		if previous, exists := folded[fold]; exists && previous != f.Name {
			addError("case-collision", fmt.Sprintf("entries %q and %q collide on case-insensitive filesystems", previous, f.Name))
		} else {
			folded[fold] = f.Name
		}
		if f.Flags&1 != 0 {
			addError("zip-encryption", fmt.Sprintf("%q uses ZIP encryption, which OCF forbids", f.Name))
		}
		if f.Method != zip.Store && f.Method != zip.Deflate {
			addError("compression-method", fmt.Sprintf("%q uses unsupported ZIP method %d", f.Name, f.Method))
		}
		if f.Mode()&os.ModeSymlink != 0 {
			addError("symlink", fmt.Sprintf("%q is a symbolic link", f.Name))
		}
	}

	mime, ok := byName["mimetype"]
	if !ok {
		addError("mimetype-missing", "root mimetype entry is missing")
	} else if data, err := readZipFile(mime, 128); err != nil {
		addError("mimetype-read", err.Error())
	} else if string(data) != MIMEType {
		addError("mimetype-content", fmt.Sprintf("mimetype must contain exactly %q", MIMEType))
	}

	containerFile, ok := byName["META-INF/container.xml"]
	if !ok {
		addError("container-missing", "META-INF/container.xml is missing")
	} else {
		data, err := readZipFile(containerFile, 4<<20)
		if err != nil {
			addError("container-read", err.Error())
		} else {
			var doc containerDocument
			if err := xml.Unmarshal(data, &doc); err != nil {
				addError("container-xml", fmt.Sprintf("invalid container.xml: %v", err))
			} else if len(doc.Rootfiles) == 0 {
				addError("rootfile-missing", "container.xml does not declare a rootfile")
			} else {
				for _, root := range doc.Rootfiles {
					report.Rootfiles = append(report.Rootfiles, root.FullPath)
					if err := validateEntryName(root.FullPath); err != nil {
						addError("rootfile-path", fmt.Sprintf("rootfile %q is unsafe: %v", root.FullPath, err))
						continue
					}
					if _, exists := byName[root.FullPath]; !exists {
						addError("rootfile-not-found", fmt.Sprintf("declared rootfile %q is not in the archive", root.FullPath))
					}
					if root.MediaType != "" && root.MediaType != "application/oebps-package+xml" {
						addWarning("rootfile-media-type", fmt.Sprintf("rootfile %q has media-type %q", root.FullPath, root.MediaType))
					}
				}
			}
		}
	}

	report.Valid = true
	for _, issue := range report.Issues {
		if issue.Level == "error" {
			report.Valid = false
			break
		}
	}
	return report, nil
}

func collectSource(root, excluded string) ([]sourceEntry, error) {
	info, err := os.Stat(root)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("source is not a directory: %s", root)
	}
	excludedAbs := ""
	if excluded != "" {
		excludedAbs, _ = filepath.Abs(excluded)
	}
	var entries []sourceEntry
	err = filepath.WalkDir(root, func(filename string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		abs, err := filepath.Abs(filename)
		if err != nil {
			return err
		}
		if excludedAbs != "" && samePath(abs, excludedAbs) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if filename == root {
			return nil
		}
		if d.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("symbolic links are not allowed: %s", filename)
		}
		if d.IsDir() {
			return nil
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("non-regular file is not allowed: %s", filename)
		}
		if d.Name() == ".DS_Store" {
			return nil
		}
		rel, err := filepath.Rel(root, filename)
		if err != nil {
			return err
		}
		name := filepath.ToSlash(rel)
		if err := validateEntryName(name); err != nil {
			return fmt.Errorf("%s: %w", filename, err)
		}
		fi, err := d.Info()
		if err != nil {
			return err
		}
		entries = append(entries, sourceEntry{absPath: abs, name: name, size: fi.Size()})
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].name < entries[j].name })
	return entries, nil
}

func validateSource(root string, entries []sourceEntry) error {
	byName := make(map[string]sourceEntry, len(entries))
	for _, entry := range entries {
		byName[entry.name] = entry
	}
	mime, ok := byName["mimetype"]
	if !ok {
		return fmt.Errorf("%w: root mimetype file is missing", ErrInvalidEPUB)
	}
	data, err := os.ReadFile(mime.absPath)
	if err != nil {
		return err
	}
	if string(data) != MIMEType {
		return fmt.Errorf("%w: mimetype must contain exactly %q with no newline", ErrInvalidEPUB, MIMEType)
	}
	containerEntry, ok := byName["META-INF/container.xml"]
	if !ok {
		return fmt.Errorf("%w: META-INF/container.xml is missing", ErrInvalidEPUB)
	}
	data, err = os.ReadFile(containerEntry.absPath)
	if err != nil {
		return err
	}
	var doc containerDocument
	if err := xml.Unmarshal(data, &doc); err != nil {
		return fmt.Errorf("%w: invalid container.xml: %v", ErrInvalidEPUB, err)
	}
	if len(doc.Rootfiles) == 0 {
		return fmt.Errorf("%w: container.xml does not declare a rootfile", ErrInvalidEPUB)
	}
	for _, rootfile := range doc.Rootfiles {
		if err := validateEntryName(rootfile.FullPath); err != nil {
			return fmt.Errorf("%w: unsafe rootfile path %q: %v", ErrInvalidEPUB, rootfile.FullPath, err)
		}
		if _, ok := byName[rootfile.FullPath]; !ok {
			return fmt.Errorf("%w: declared rootfile %q is missing", ErrInvalidEPUB, rootfile.FullPath)
		}
	}
	_ = root
	return nil
}

func writeArchive(dst *os.File, entries []sourceEntry) error {
	zw := zip.NewWriter(dst)
	zw.RegisterCompressor(zip.Deflate, func(w io.Writer) (io.WriteCloser, error) {
		return flate.NewWriter(w, flate.BestCompression)
	})
	closeWithError := func(err error) error {
		if closeErr := zw.Close(); err == nil {
			return closeErr
		}
		return err
	}

	var mime sourceEntry
	var rest []sourceEntry
	for _, entry := range entries {
		if entry.name == "mimetype" {
			mime = entry
		} else {
			rest = append(rest, entry)
		}
	}
	if mime.name == "" {
		return closeWithError(fmt.Errorf("%w: mimetype is missing", ErrInvalidEPUB))
	}
	// Construct this header manually: no timestamp means no extended timestamp
	// extra field, satisfying the OCF requirement for mimetype.
	mimeHeader := &zip.FileHeader{Name: "mimetype", Method: zip.Store}
	mimeHeader.SetMode(0o644)
	if err := addFile(zw, mimeHeader, mime); err != nil {
		return closeWithError(err)
	}
	for _, entry := range rest {
		header := &zip.FileHeader{Name: entry.name, Method: zip.Deflate}
		header.SetMode(0o644)
		if err := addFile(zw, header, entry); err != nil {
			return closeWithError(err)
		}
	}
	return zw.Close()
}

func addFile(zw *zip.Writer, header *zip.FileHeader, entry sourceEntry) error {
	w, err := zw.CreateHeader(header)
	if err != nil {
		return err
	}
	r, err := os.Open(entry.absPath)
	if err != nil {
		return err
	}
	defer r.Close()
	written, err := io.Copy(w, r)
	if err != nil {
		return err
	}
	if written != entry.size {
		return fmt.Errorf("file changed while packing: %s", entry.absPath)
	}
	return r.Close()
}

func validateArchiveForExtraction(r *zip.Reader, limits Limits) error {
	if len(r.File) > limits.MaxFiles {
		return fmt.Errorf("%w: archive has %d entries; limit is %d", ErrInvalidEPUB, len(r.File), limits.MaxFiles)
	}
	var total uint64
	seen := make(map[string]struct{}, len(r.File))
	folded := make(map[string]string, len(r.File))
	for _, f := range r.File {
		if err := validateEntryName(f.Name); err != nil {
			return fmt.Errorf("%w: unsafe entry %q: %v", ErrInvalidEPUB, f.Name, err)
		}
		if _, ok := seen[f.Name]; ok {
			return fmt.Errorf("%w: duplicate entry %q", ErrInvalidEPUB, f.Name)
		}
		seen[f.Name] = struct{}{}
		fold := strings.ToLower(f.Name)
		if previous, ok := folded[fold]; ok && previous != f.Name {
			return fmt.Errorf("%w: entries %q and %q collide on case-insensitive filesystems", ErrInvalidEPUB, previous, f.Name)
		}
		folded[fold] = f.Name
		if f.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%w: symbolic link entry %q is not allowed", ErrInvalidEPUB, f.Name)
		}
		if f.Flags&1 != 0 {
			return fmt.Errorf("%w: ZIP-encrypted entry %q is not allowed", ErrInvalidEPUB, f.Name)
		}
		if f.UncompressedSize64 > uint64(limits.MaxFileSize) {
			return fmt.Errorf("%w: entry %q exceeds the per-file limit", ErrInvalidEPUB, f.Name)
		}
		if ^uint64(0)-total < f.UncompressedSize64 {
			return fmt.Errorf("%w: uncompressed size overflow", ErrInvalidEPUB)
		}
		total += f.UncompressedSize64
		if total > uint64(limits.MaxTotalSize) {
			return fmt.Errorf("%w: archive exceeds the total uncompressed size limit", ErrInvalidEPUB)
		}
		if !strings.HasSuffix(f.Name, "/") && f.UncompressedSize64 > 0 {
			if f.CompressedSize64 == 0 || (limits.MaxRatio > 0 && f.UncompressedSize64/f.CompressedSize64 > limits.MaxRatio) {
				return fmt.Errorf("%w: entry %q exceeds the compression ratio limit", ErrInvalidEPUB, f.Name)
			}
		}
	}
	return nil
}

func extractAll(r *zip.Reader, root string, limits Limits) error {
	var total int64
	for _, f := range r.File {
		name := strings.TrimSuffix(f.Name, "/")
		if name == "" {
			continue
		}
		target := filepath.Join(root, filepath.FromSlash(name))
		if err := ensureWithin(root, target); err != nil {
			return err
		}
		if strings.HasSuffix(f.Name, "/") {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		rc, err := f.Open()
		if err != nil {
			return fmt.Errorf("open %q: %w", f.Name, err)
		}
		out, err := os.OpenFile(target, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
		if err != nil {
			_ = rc.Close()
			return err
		}
		written, copyErr := io.Copy(out, io.LimitReader(rc, limits.MaxFileSize+1))
		closeOutErr := out.Close()
		closeInErr := rc.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeOutErr != nil {
			return closeOutErr
		}
		if closeInErr != nil {
			return closeInErr
		}
		if written != int64(f.UncompressedSize64) {
			return fmt.Errorf("%w: entry %q size differs from its ZIP header", ErrInvalidEPUB, f.Name)
		}
		total += written
		if written > limits.MaxFileSize || total > limits.MaxTotalSize {
			return fmt.Errorf("%w: extraction size limit exceeded", ErrInvalidEPUB)
		}
	}
	return nil
}

func validateEntryName(name string) error {
	if name == "" {
		return fmt.Errorf("empty path")
	}
	if strings.ContainsRune(name, '\x00') {
		return fmt.Errorf("contains NUL")
	}
	if strings.Contains(name, "\\") {
		return fmt.Errorf("contains a backslash")
	}
	if strings.HasPrefix(name, "/") {
		return fmt.Errorf("absolute path")
	}
	trimmed := strings.TrimSuffix(name, "/")
	clean := path.Clean(trimmed)
	if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return fmt.Errorf("path escapes the container root")
	}
	if clean != trimmed {
		return fmt.Errorf("path is not normalized")
	}
	return nil
}

func readZipFile(f *zip.File, limit int64) ([]byte, error) {
	if f.UncompressedSize64 > uint64(limit) {
		return nil, fmt.Errorf("%q exceeds the %d-byte inspection limit", f.Name, limit)
	}
	r, err := f.Open()
	if err != nil {
		return nil, err
	}
	defer r.Close()
	data, err := io.ReadAll(io.LimitReader(r, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > limit {
		return nil, fmt.Errorf("%q exceeds the %d-byte inspection limit", f.Name, limit)
	}
	return data, nil
}

func normalizedLimits(limits Limits) (Limits, error) {
	if limits == (Limits{}) {
		limits = DefaultLimits
	}
	if limits.MaxFiles <= 0 || limits.MaxFileSize <= 0 || limits.MaxTotalSize <= 0 {
		return Limits{}, fmt.Errorf("all extraction limits must be positive")
	}
	return limits, nil
}

func ensureReplaceable(target string, force, wantDirectory bool) error {
	info, err := os.Lstat(target)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if !force {
		return fmt.Errorf("output already exists: %s (use --force to replace it)", target)
	}
	if !wantDirectory && info.IsDir() {
		return fmt.Errorf("refusing to replace directory with EPUB file: %s", target)
	}
	return nil
}

func commitPath(temp, target string, force bool) error {
	if _, err := os.Lstat(target); errors.Is(err, os.ErrNotExist) {
		return os.Rename(temp, target)
	} else if err != nil {
		return err
	}
	if !force {
		return fmt.Errorf("output already exists: %s", target)
	}
	backup, err := uniqueBackupPath(target)
	if err != nil {
		return err
	}
	if err := os.Rename(target, backup); err != nil {
		return err
	}
	if err := os.Rename(temp, target); err != nil {
		_ = os.Rename(backup, target)
		return err
	}
	if err := os.RemoveAll(backup); err != nil {
		return fmt.Errorf("output replaced, but temporary backup could not be removed: %w", err)
	}
	return nil
}

func uniqueBackupPath(target string) (string, error) {
	parent := filepath.Dir(target)
	placeholder, err := os.CreateTemp(parent, ".epubzip-backup-*")
	if err != nil {
		return "", err
	}
	name := placeholder.Name()
	if err := placeholder.Close(); err != nil {
		return "", err
	}
	if err := os.Remove(name); err != nil {
		return "", err
	}
	return name, nil
}

func ensureWithin(root, target string) error {
	rel, err := filepath.Rel(root, target)
	if err != nil {
		return err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel) {
		return fmt.Errorf("%w: extraction target escapes output directory", ErrInvalidEPUB)
	}
	return nil
}

func samePath(a, b string) bool {
	return filepath.Clean(a) == filepath.Clean(b)
}

func summarizeIssues(issues []Issue) string {
	var messages []string
	for _, issue := range issues {
		if issue.Level == "error" {
			messages = append(messages, issue.Message)
		}
	}
	return strings.Join(messages, "; ")
}
