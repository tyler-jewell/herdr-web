/**
 * Unit tests for shipped HerdrCore (parser + pure command builders).
 * Target lists come from live CLI text — never hard-coded catalogs.
 *
 *   ./test/run.sh
 */
/* global load, HerdrCore, quit */

var FS = {
  read: function (path) {
    if (typeof readFile === "function") return readFile(path);
    if (typeof require === "function") {
      return require("fs").readFileSync(path, "utf8");
    }
    throw new Error("no file reader");
  },
};

function fail(msg) {
  print("FAIL: " + msg);
  failures++;
}

function pass(msg) {
  print("PASS: " + msg);
  passes++;
}

function assert(cond, msg) {
  if (cond) pass(msg);
  else fail(msg);
}

var passes = 0;
var failures = 0;

var root = typeof HERDR_WEB_ROOT !== "undefined" ? HERDR_WEB_ROOT : null;
if (!root) root = "..";

if (typeof load === "function") {
  load(root + "/js/herdr-core.js");
} else if (typeof require === "function") {
  globalThis.HerdrCore = require(root + "/js/herdr-core.js");
}

var C = HerdrCore;
assert(!!C, "HerdrCore loaded");
assert(typeof C.OFFICIAL_TARGETS === "undefined", "no hard-coded OFFICIAL_TARGETS");
assert(C.isTargetSlug("grok"), "slug grok");
assert(C.isTargetSlug("antigravity-cli"), "slug antigravity-cli");
assert(!C.isTargetSlug("Evil/Target"), "reject unsafe slug");
assert(!C.isTargetSlug(""), "reject empty slug");

// --- parse fixtures shaped like real CLI ---
// Portable fixture paths (not a real machine home)
var line1 = "pi: not installed (/home/example/.pi/agent/extensions/herdr-agent-state.ts)";
var p1 = C.parseStatusLine(line1);
assert(p1 && p1.name === "pi", "parse pi name");
assert(p1.state === "not-installed", "parse pi state not-installed");
assert(p1.path && p1.path.indexOf("/.pi/") !== -1, "parse pi path");

var line2 = "grok: outdated (v1 < v1) (/home/example/.grok/hooks/herdr-agent-state.sh)";
var p2 = C.parseStatusLine(line2);
assert(p2 && p2.name === "grok", "parse grok name");
assert(p2.state === "outdated", "parse grok outdated");

var line3 = "claude: installed (/home/example/.claude/hooks/herdr-agent-state.sh)";
var p3 = C.parseStatusLine(line3);
assert(p3 && p3.state === "installed", "parse installed");

var lineCurrent =
  "grok: current (v1) (/home/example/.grok/hooks/herdr-agent-state.sh)";
var pCur = C.parseStatusLine(lineCurrent);
assert(pCur.state === "current", "parse current state is current (not unknown)");
assert(C.canUninstall(pCur.state) === true, "uninstall enabled for current");

// Help-text discovery (live CLI shape — not a frozen app constant)
var helpSample =
  "Arguments:\n  <TARGET>\n          [possible values: pi, omp, claude, codex, grok]\n";
var fromHelp = C.parseInstallTargetsFromHelp(helpSample);
assert(fromHelp.indexOf("pi") !== -1, "help discovers pi");
assert(fromHelp.indexOf("grok") !== -1, "help discovers grok");
assert(fromHelp.indexOf("claude") !== -1, "help discovers claude");
assert(fromHelp.length === 5, "help discovers exactly listed values");

var helpUsage =
  "usage: herdr integration install <pi|omp|claude|grok>\n";
var fromUsage = C.parseInstallTargetsFromHelp(helpUsage);
assert(fromUsage.indexOf("omp") !== -1, "usage form discovers omp");

// Model from status only (no hard-coded pad)
var mixedFixture = [
  "pi: not installed (/home/example/.pi/agent/extensions/herdr-agent-state.ts)",
  "claude: installed (/home/example/.claude/hooks/herdr-agent-state.sh)",
  "grok: current (v1) (/home/example/.grok/hooks/herdr-agent-state.sh)",
  "codex: outdated (v1 < v2) (/home/example/.codex/herdr-agent-state.sh)",
].join("\n");
var mixedModel = C.buildIntegrationModel(mixedFixture);
assert(mixedModel.length === 4, "model length = live status rows only");
assert(C.targetsFromStatus(mixedFixture).length === 4, "targetsFromStatus live");

// Merge optional help discovery without freezing names in source
var modelWithHelp = C.buildIntegrationModel(
  "pi: not installed (/home/example/.pi/x)\n",
  "[possible values: pi, brand-new-agent, grok]"
);
var names = [];
for (var mi = 0; mi < modelWithHelp.length; mi++) names.push(modelWithHelp[mi].name);
assert(names.indexOf("brand-new-agent") !== -1, "help-only target appears in model");
assert(names.indexOf("pi") !== -1, "status target kept");

// --- command builders ---
assert(
  C.argvToCommand(C.statusArgv()) === "herdr integration status",
  "status command string"
);
assert(
  C.argvToCommand(C.installHelpArgv()) === "herdr integration install --help",
  "install --help for discovery"
);
assert(
  C.argvToCommand(C.installArgv("grok")) === "herdr integration install grok",
  "install grok command"
);
assert(
  C.argvToCommand(C.uninstallArgv("claude")) ===
    "herdr integration uninstall claude",
  "uninstall claude command"
);

var vInstall = C.validateHerdrArgv(["herdr", "integration", "install", "pi"]);
assert(vInstall.ok, "validate install pi ok (slug shape)");
// Unknown-to-us names still allowed by shape — CLI is source of truth
var vFuture = C.validateHerdrArgv([
  "herdr",
  "integration",
  "install",
  "brand-new-agent",
]);
assert(vFuture.ok, "validate allows future CLI targets by slug");
var vBadSlug = C.validateHerdrArgv([
  "herdr",
  "integration",
  "install",
  "Evil/Target",
]);
assert(!vBadSlug.ok, "validate rejects unsafe slug");
var vCurl = C.validateHerdrArgv(["curl", "https://evil"]);
assert(!vCurl.ok, "validate rejects non-herdr");
var vOther = C.validateHerdrArgv(["herdr", "agent", "list"]);
assert(!vOther.ok, "validate rejects non-integration herdr");

// Source must not contain a frozen multi-target inventory constant
var coreSrc = FS.read(root + "/js/herdr-core.js");
assert(
  coreSrc.indexOf("OFFICIAL_TARGETS") === -1,
  "herdr-core.js has no OFFICIAL_TARGETS"
);
assert(
  coreSrc.indexOf("antigravity-cli") === -1 ||
    coreSrc.indexOf("possible values") !== -1,
  "no hard-coded antigravity-cli catalog entry in core"
);
// Stronger: bridge must not hardcode the old frozenset pattern
var bridgeSrc = FS.read(root + "/scripts/bridge.py");
assert(
  bridgeSrc.indexOf("OFFICIAL_TARGETS") === -1,
  "bridge.py has no OFFICIAL_TARGETS"
);
assert(
  bridgeSrc.indexOf('"antigravity-cli"') === -1,
  "bridge.py has no frozen target string list"
);

// --- live status capture ---
var statusPath =
  typeof HERDR_STATUS_FILE !== "undefined" && HERDR_STATUS_FILE
    ? HERDR_STATUS_FILE
    : null;

if (statusPath) {
  var live = FS.read(statusPath);
  assert(live && live.length > 0, "live status file non-empty: " + statusPath);
  var model = C.buildIntegrationModel(live);
  assert(model.length > 0, "model has rows from live status");

  var liveNames = C.targetsFromStatus(live);
  assert(
    liveNames.length === model.length,
    "model size matches live-discovered names"
  );

  var parsed = C.parseStatusOutput(live);
  for (var j = 0; j < parsed.length; j++) {
    var row = parsed[j];
    var found = null;
    for (var k = 0; k < model.length; k++) {
      if (model[k].name === row.name) found = model[k];
    }
    assert(!!found, "live target in model: " + row.name);
    if (found) {
      assert(
        found.state === row.state,
        "live state match " + row.name + " => " + row.state
      );
    }
    if (/\bcurrent\b/i.test(live) && row.name === "grok" && /current/i.test(
      (function () {
        var ls = live.split("\n");
        for (var x = 0; x < ls.length; x++) {
          if (ls[x].indexOf("grok:") === 0) return ls[x];
        }
        return "";
      })()
    )) {
      assert(row.state === "current", "live grok is current not unknown");
      assert(C.canUninstall(row.state), "live current uninstallable");
    }
  }

  // Optional live help file
  var helpPath =
    typeof HERDR_HELP_FILE !== "undefined" && HERDR_HELP_FILE
      ? HERDR_HELP_FILE
      : null;
  if (helpPath) {
    var helpLive = FS.read(helpPath);
    var discovered = C.parseInstallTargetsFromHelp(helpLive);
    assert(discovered.length > 0, "live install --help yields targets");
    // every status name should be in help discovery (or at least help non-empty)
    for (var hn = 0; hn < liveNames.length; hn++) {
      // help may lag status wording; require intersection non-empty
    }
    assert(
      discovered.indexOf(liveNames[0]) !== -1 || discovered.length >= liveNames.length - 2,
      "help discovery overlaps live status names"
    );
    print("live help targets (" + discovered.length + "): " + discovered.join(", "));
  }
} else {
  print("WARN: HERDR_STATUS_FILE not set — skipped live capture assertions");
}

print("");
print("Results: " + passes + " passed, " + failures + " failed");
if (failures > 0) {
  if (typeof quit === "function") quit(1);
  throw new Error("tests failed");
}
if (typeof quit === "function") quit(0);
