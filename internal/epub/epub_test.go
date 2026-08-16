package epub

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPackInspectAndUnpack(t *testing.T) {
	src := makeValidSource(t)
	dst := filepath.Join(t.TempDir(), "book.epub")
	if err := Pack(src, dst, PackOptions{}); err != nil {
		t.Fatalf("Pack: %v", err)
	}

	r, err := zip.OpenReader(dst)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	if got := r.File[0].Name; got != "mimetype" {
		t.Fatalf("first entry = %q, want mimetype", got)
	}
	if r.File[0].Method != zip.Store {
		t.Fatalf("mimetype method = %d, want Store", r.File[0].Method)
	}
	if len(r.File[0].Extra) != 0 {
		t.Fatalf("mimetype has %d bytes of extra data", len(r.File[0].Extra))
	}

	report, err := Inspect(dst)
	if err != nil {
		t.Fatal(err)
	}
	if !report.Valid {
		t.Fatalf("report invalid: %+v", report.Issues)
	}

	out := filepath.Join(t.TempDir(), "out")
	if err := Unpack(dst, out, UnpackOptions{Limits: DefaultLimits}); err != nil {
		t.Fatalf("Unpack: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(out, "EPUB", "chapter.xhtml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "<html/>" {
		t.Fatalf("chapter content = %q", data)
	}
	info, err := os.Stat(filepath.Join(out, "EPUB", "chapter.xhtml"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o644 {
		t.Fatalf("chapter permissions = %o, want 644", info.Mode().Perm())
	}
}

func TestPackRejectsInvalidMimetype(t *testing.T) {
	src := makeValidSource(t)
	writeFile(t, filepath.Join(src, "mimetype"), MIMEType+"\n")
	err := Pack(src, filepath.Join(t.TempDir(), "bad.epub"), PackOptions{})
	if err == nil || !strings.Contains(err.Error(), "mimetype") {
		t.Fatalf("Pack error = %v, want mimetype error", err)
	}
}

func TestUnpackRejectsPathTraversal(t *testing.T) {
	archive := filepath.Join(t.TempDir(), "evil.epub")
	writeTestZip(t, archive, []testZipEntry{
		{name: "mimetype", body: MIMEType, method: zip.Store},
		{name: "../escaped", body: "owned", method: zip.Deflate},
	})
	parent := t.TempDir()
	out := filepath.Join(parent, "out")
	err := Unpack(archive, out, UnpackOptions{Limits: DefaultLimits})
	if err == nil || !strings.Contains(err.Error(), "unsafe entry") {
		t.Fatalf("Unpack error = %v, want unsafe entry", err)
	}
	if _, err := os.Stat(filepath.Join(parent, "escaped")); !os.IsNotExist(err) {
		t.Fatalf("path traversal created a file: %v", err)
	}
}

func TestUnpackRejectsSymlink(t *testing.T) {
	archive := filepath.Join(t.TempDir(), "symlink.epub")
	f, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	h := &zip.FileHeader{Name: "link", Method: zip.Store}
	h.SetMode(os.ModeSymlink | 0o777)
	w, err := zw.CreateHeader(h)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = w.Write([]byte("target"))
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	err = Unpack(archive, filepath.Join(t.TempDir(), "out"), UnpackOptions{Limits: DefaultLimits})
	if err == nil || !strings.Contains(err.Error(), "symbolic link") {
		t.Fatalf("Unpack error = %v, want symbolic link error", err)
	}
}

func TestInspectDetectsInvalidOrder(t *testing.T) {
	archive := filepath.Join(t.TempDir(), "wrong-order.epub")
	writeTestZip(t, archive, []testZipEntry{
		{name: "EPUB/book.opf", body: "<package/>", method: zip.Deflate},
		{name: "mimetype", body: MIMEType, method: zip.Store},
		{name: "META-INF/container.xml", body: containerXML, method: zip.Deflate},
	})
	report, err := Inspect(archive)
	if err != nil {
		t.Fatal(err)
	}
	if report.Valid {
		t.Fatal("Inspect reported an archive with late mimetype as valid")
	}
	if !hasIssue(report, "mimetype-order") {
		t.Fatalf("issues = %+v, want mimetype-order", report.Issues)
	}
}

func TestForceReplacesOnlyAfterSuccessfulPack(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "book.epub")
	if err := os.WriteFile(dst, []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}
	bad := t.TempDir()
	if err := Pack(bad, dst, PackOptions{Force: true}); err == nil {
		t.Fatal("Pack succeeded for invalid source")
	}
	data, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "old" {
		t.Fatalf("failed pack changed old output to %q", data)
	}

	if err := Pack(makeValidSource(t), dst, PackOptions{Force: true}); err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(mustRead(t, dst), []byte("old")) {
		t.Fatal("successful forced pack did not replace output")
	}
}

const containerXML = `<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="EPUB/book.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`

func makeValidSource(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	writeFile(t, filepath.Join(root, "mimetype"), MIMEType)
	writeFile(t, filepath.Join(root, "META-INF", "container.xml"), containerXML)
	writeFile(t, filepath.Join(root, "EPUB", "book.opf"), `<package xmlns="http://www.idpf.org/2007/opf" version="3.0"/>`)
	writeFile(t, filepath.Join(root, "EPUB", "chapter.xhtml"), "<html/>")
	writeFile(t, filepath.Join(root, ".DS_Store"), "ignored")
	return root
}

func writeFile(t *testing.T, filename, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(filename), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filename, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

type testZipEntry struct {
	name   string
	body   string
	method uint16
}

func writeTestZip(t *testing.T, filename string, entries []testZipEntry) {
	t.Helper()
	f, err := os.Create(filename)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	for _, entry := range entries {
		h := &zip.FileHeader{Name: entry.name, Method: entry.method}
		w, err := zw.CreateHeader(h)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write([]byte(entry.body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
}

func hasIssue(report Report, code string) bool {
	for _, issue := range report.Issues {
		if issue.Code == code {
			return true
		}
	}
	return false
}

func mustRead(t *testing.T, filename string) []byte {
	t.Helper()
	data, err := os.ReadFile(filename)
	if err != nil {
		t.Fatal(err)
	}
	return data
}
