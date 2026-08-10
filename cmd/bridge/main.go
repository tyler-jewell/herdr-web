// Static + API bridge for herdr-web (isolatable Herdr plugin product).
//
// POST /api/herdr { "argv": ["herdr", "integration", ...] }
// GET  /__hmr  → live-reload version token (file mtime hash of UI assets)
// HTML responses inject a tiny poller so asset edits apply without manual refresh.
//
// Hot-reload is ON by default (HERDR_WEB_HOT_RELOAD=0 to disable).
package main

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

var (
	root = envOr("HERDR_WEB_ROOT", "")
	host = envOr("HERDR_WEB_HOST", "127.0.0.1")
	port = envOr("HERDR_WEB_PORT", "8765")
	hot  = hotEnabled()

	targetSlug = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)
)

const hmrSnippet = `
<script id="herdr-web-hmr">
(function () {
  if (window.__HERDR_WEB_HMR__) return;
  window.__HERDR_WEB_HMR__ = true;
  var last = null;
  function tick() {
    fetch("/__hmr", { cache: "no-store" })
      .then(function (r) { return r.json(); })
      .then(function (j) {
        if (last === null) { last = j.version; return; }
        if (j.version && j.version !== last) {
          last = j.version;
          location.reload();
        }
      })
      .catch(function () {})
      .then(function () { setTimeout(tick, 600); });
  }
  tick();
})();
</script>
`

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func hotEnabled() bool {
	v := strings.ToLower(envOr("HERDR_WEB_HOT_RELOAD", "1"))
	return v != "0" && v != "false" && v != "no"
}

func isTargetSlug(name string) bool {
	return name != "" && targetSlug.MatchString(name)
}

func validateHerdrArgv(argv []string) (bool, string) {
	if len(argv) == 0 {
		return false, "empty argv"
	}
	if argv[0] != "herdr" {
		return false, "only herdr is allowed"
	}
	if len(argv) < 3 || argv[1] != "integration" {
		return false, "only herdr integration … is allowed"
	}
	sub := argv[2]
	switch sub {
	case "status":
		if len(argv) == 3 {
			return true, ""
		}
		if len(argv) == 4 && argv[3] == "--outdated-only" {
			return true, ""
		}
		return false, "invalid status args"
	case "install":
		if len(argv) == 4 && argv[3] == "--help" {
			return true, ""
		}
		if len(argv) != 4 {
			return false, "install/uninstall need exactly one target"
		}
		if !isTargetSlug(argv[3]) {
			return false, "invalid target slug: " + argv[3]
		}
		return true, ""
	case "uninstall":
		if len(argv) != 4 {
			return false, "install/uninstall need exactly one target"
		}
		if !isTargetSlug(argv[3]) {
			return false, "invalid target slug: " + argv[3]
		}
		return true, ""
	default:
		return false, "unknown integration subcommand: " + sub
	}
}

func findHerdr() string {
	if p := os.Getenv("HERDR_BIN_PATH"); p != "" {
		return p
	}
	if p, err := exec.LookPath("herdr"); err == nil {
		return p
	}
	return ""
}

func runHerdr(argv []string) map[string]any {
	ok, errMsg := validateHerdrArgv(argv)
	if !ok {
		return map[string]any{"ok": false, "error": errMsg, "argv": argv}
	}
	herdr := findHerdr()
	if herdr == "" {
		return map[string]any{"ok": false, "error": "herdr not found on PATH", "argv": argv}
	}
	cmdArgs := append([]string{}, argv[1:]...)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, herdr, cmdArgs...)
	cmd.Env = os.Environ()
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	runErr := cmd.Run()
	exitCode := 0
	if runErr != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return map[string]any{
				"ok":      false,
				"error":   "herdr timed out",
				"argv":    argv,
				"command": herdr + " " + strings.Join(cmdArgs, " "),
			}
		}
		if ee, ok := runErr.(*exec.ExitError); ok {
			exitCode = ee.ExitCode()
		} else {
			return map[string]any{"ok": false, "error": runErr.Error(), "argv": argv}
		}
	}
	return map[string]any{
		"ok":       true,
		"argv":     argv,
		"command":  herdr + " " + strings.Join(cmdArgs, " "),
		"exitCode": exitCode,
		"stdout":   stdout.String(),
		"stderr":   stderr.String(),
	}
}

// AssetVersion hashes mtimes of watched UI assets — changes when agents edit files.
func AssetVersion() string {
	h := sha1.New()
	var paths []string
	// index.html
	p := filepath.Join(root, "index.html")
	if st, err := os.Stat(p); err == nil && !st.IsDir() {
		paths = append(paths, p)
	}
	for _, dir := range []string{"css", "js"} {
		base := filepath.Join(root, dir)
		_ = filepath.WalkDir(base, func(path string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			paths = append(paths, path)
			return nil
		})
	}
	sort.Strings(paths)
	for _, path := range paths {
		st, err := os.Stat(path)
		if err != nil {
			continue
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			rel = path
		}
		_, _ = io.WriteString(h, rel)
		_, _ = io.WriteString(h, strconv.FormatInt(st.ModTime().UnixNano(), 10))
		_, _ = io.WriteString(h, strconv.FormatInt(st.Size(), 10))
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}

func writeJSON(w http.ResponseWriter, code int, obj any) {
	data, err := json.Marshal(obj)
	if err != nil {
		http.Error(w, `{"ok":false,"error":"encode"}`, http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_, _ = w.Write(data)
}

func serveHTMLWithHMR(w http.ResponseWriter, r *http.Request) {
	index := filepath.Join(root, "index.html")
	body, err := os.ReadFile(index)
	if err != nil {
		http.Error(w, "index.html missing", http.StatusNotFound)
		return
	}
	if !bytes.Contains(body, []byte("herdr-web-hmr")) {
		if bytes.Contains(body, []byte("</body>")) {
			body = bytes.Replace(body, []byte("</body>"), []byte(hmrSnippet+"</body>"), 1)
		} else {
			body = append(body, []byte(hmrSnippet)...)
		}
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Length", strconv.Itoa(len(body)))
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(body)
	log.Print("hot-reload: injected HMR poller into index.html")
}

func handleAPI(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/api/herdr" {
		http.Error(w, "only POST /api/herdr", http.StatusNotFound)
		return
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"ok": false, "error": "read body"})
		return
	}
	var body struct {
		Argv []string `json:"argv"`
	}
	if len(raw) == 0 {
		raw = []byte("{}")
	}
	if err := json.Unmarshal(raw, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"ok": false, "error": "invalid JSON"})
		return
	}
	if p := os.Getenv("HERDR_BIN_PATH"); p != "" {
		dir := filepath.Dir(p)
		os.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	}
	result := runHerdr(body.Argv)
	code := http.StatusOK
	if ok, _ := result["ok"].(bool); !ok {
		code = http.StatusBadRequest
	}
	writeJSON(w, code, result)
}

func resolveRoot() string {
	if r := os.Getenv("HERDR_WEB_ROOT"); r != "" {
		return r
	}
	wd, err := os.Getwd()
	if err == nil {
		if st, err := os.Stat(filepath.Join(wd, "index.html")); err == nil && !st.IsDir() {
			return wd
		}
		// scripts/ cwd → parent is product root
		if filepath.Base(wd) == "scripts" {
			parent := filepath.Dir(wd)
			if st, err := os.Stat(filepath.Join(parent, "index.html")); err == nil && !st.IsDir() {
				return parent
			}
		}
	}
	// go run: directory containing this source file's parent
	_, file, _, ok := runtime.Caller(0)
	if ok {
		parent := filepath.Dir(filepath.Dir(file))
		if st, err := os.Stat(filepath.Join(parent, "index.html")); err == nil && !st.IsDir() {
			return parent
		}
	}
	if wd != "" {
		return wd
	}
	return "."
}

func main() {
	root = resolveRoot()
	if err := os.Chdir(root); err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/__hmr", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.Error(w, "method", http.StatusMethodNotAllowed)
			return
		}
		ver := "off"
		if hot {
			ver = AssetVersion()
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"ok":         true,
			"hot_reload": hot,
			"version":    ver,
		})
	})
	mux.HandleFunc("/api/herdr", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, "POST only", http.StatusMethodNotAllowed)
			return
		}
		handleAPI(w, r)
	})
	fileServer := http.FileServer(http.Dir(root))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method == http.MethodGet || r.Method == http.MethodHead {
			if (r.URL.Path == "/" || r.URL.Path == "/index.html") && hot {
				serveHTMLWithHMR(w, r)
				return
			}
			fileServer.ServeHTTP(w, r)
			return
		}
		http.Error(w, "method", http.StatusMethodNotAllowed)
	})

	addr := host + ":" + port
	log.Printf("listening on http://%s/  root=%s  hot_reload=%v", addr, root, hot)
	if hot {
		log.Printf("hot-reload: watching UI assets; /__hmr version=%s", AssetVersion())
	}
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
