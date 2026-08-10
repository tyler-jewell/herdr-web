package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHMRSnippetWired(t *testing.T) {
	if !strings.Contains(hmrSnippet, "herdr-web-hmr") {
		t.Fatal("HMR snippet missing herdr-web-hmr id")
	}
	if !strings.Contains(hmrSnippet, "/__hmr") {
		t.Fatal("HMR snippet missing /__hmr poll path")
	}
}

func TestHotDefaultEnv(t *testing.T) {
	// Module hot reflects env at init; type is bool
	_ = hot
}

func TestAssetVersionChangesOnEdit(t *testing.T) {
	// Resolve product root (parent of cmd/bridge when tests run from module root)
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// tests run with cwd = package dir (cmd/bridge) or module root depending on go test
	candidates := []string{
		filepath.Join(wd, "css", "app.css"),
		filepath.Join(wd, "..", "..", "css", "app.css"),
		filepath.Join(wd, "..", "css", "app.css"),
	}
	var css string
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			css = c
			break
		}
	}
	if css == "" {
		t.Fatal("css/app.css must exist relative to test cwd")
	}
	// set root for AssetVersion
	root = filepath.Dir(filepath.Dir(css))
	if filepath.Base(filepath.Dir(css)) != "css" {
		// css path is root/css/app.css → root is dirname of css dir
		root = filepath.Dir(filepath.Dir(css))
	}
	// css = <root>/css/app.css
	root = filepath.Dir(filepath.Dir(css))

	v1 := AssetVersion()
	original, err := os.ReadFile(css)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.WriteFile(css, original, 0o644) }()
	if err := os.WriteFile(css, append(original, []byte("\n/* hmr-test */\n")...), 0o644); err != nil {
		t.Fatal(err)
	}
	v2 := AssetVersion()
	if v1 == v2 {
		t.Fatalf("version should change after edit: %s vs %s", v1, v2)
	}
}

func TestValidateHerdrArgv(t *testing.T) {
	ok, _ := validateHerdrArgv([]string{"herdr", "integration", "status"})
	if !ok {
		t.Fatal("status should be ok")
	}
	ok, msg := validateHerdrArgv([]string{"python", "x"})
	if ok || msg == "" {
		t.Fatal("non-herdr should fail")
	}
	ok, _ = validateHerdrArgv([]string{"herdr", "integration", "install", "grok"})
	if !ok {
		t.Fatal("install grok should be ok")
	}
	ok, _ = validateHerdrArgv([]string{"herdr", "integration", "install", "Bad_Target"})
	if ok {
		t.Fatal("invalid slug should fail")
	}
}
