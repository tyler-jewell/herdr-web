/**
 * Pure Herdr integration primitives (no install reimplementation).
 * Target inventory is NEVER hard-coded — discover live from CLI text:
 *   - herdr integration status  (rows)
 *   - herdr integration install --help  (possible values)
 *
 * Browser: window.HerdrCore
 * jsc/node: globalThis.HerdrCore (after load)
 */
(function (root) {
  "use strict";

  /** Safe integration target slug (structure only — CLI owns the catalog). */
  function isTargetSlug(name) {
    return typeof name === "string" && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name);
  }

  /**
   * Parse install targets from `herdr integration install --help` (or similar).
   * Looks for: [possible values: a, b, c]  or  usage: … <a|b|c>
   * @returns {string[]}
   */
  function parseInstallTargetsFromHelp(text) {
    var s = String(text || "");
    var out = [];
    var seen = {};

    function add(name) {
      name = String(name).trim();
      if (!isTargetSlug(name) || seen[name]) return;
      // skip help meta words
      if (
        name === "target" ||
        name === "possible" ||
        name === "values" ||
        name === "options"
      ) {
        return;
      }
      seen[name] = true;
      out.push(name);
    }

    var m = s.match(/possible values:\s*([^\]]+)\]/i);
    if (m) {
      var parts = m[1].split(/[,\s]+/);
      for (var i = 0; i < parts.length; i++) add(parts[i]);
    }

    if (out.length === 0) {
      var m2 = s.match(/<((?:[a-z0-9-]+\|)+[a-z0-9-]+)>/i);
      if (m2) {
        var alts = m2[1].split("|");
        for (var j = 0; j < alts.length; j++) add(alts[j]);
      }
    }

    return out;
  }

  /**
   * Target names discovered from live status output (order preserved).
   */
  function targetsFromStatus(statusText) {
    var rows = parseStatusOutput(statusText);
    var names = [];
    for (var i = 0; i < rows.length; i++) names.push(rows[i].name);
    return names;
  }

  /**
   * Parse one status line from `herdr integration status`.
   * Shapes:
   *   name: not installed (/path)
   *   name: installed (/path)
   *   name: outdated (v1 < v2) (/path)
   *   name: current (vN) (/path)
   * @returns {{name:string,state:string,detail:string,path:string|null}|null}
   */
  function parseStatusLine(line) {
    if (!line || typeof line !== "string") return null;
    var trimmed = line.replace(/\r$/, "").trim();
    if (!trimmed || trimmed.charAt(0) === "#") return null;

    var colon = trimmed.indexOf(":");
    if (colon < 1) return null;
    var name = trimmed.slice(0, colon).trim();
    var rest = trimmed.slice(colon + 1).trim();
    if (!name || !rest) return null;
    if (!isTargetSlug(name) && !/^[a-z0-9][a-z0-9_-]*$/i.test(name)) {
      // still accept CLI-emitted names that are slug-like
      if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(name)) return null;
    }

    var path = null;
    var pathRe = /\s+\(((\/|~)[^)]*)\)\s*$/;
    var pm = rest.match(pathRe);
    if (pm) {
      path = pm[1];
      rest = rest.slice(0, pm.index).trim();
    }

    var state = "unknown";
    var detail = rest;
    if (/^not installed\b/i.test(rest)) {
      state = "not-installed";
    } else if (/^installed\b/i.test(rest)) {
      state = "installed";
    } else if (/^outdated\b/i.test(rest)) {
      state = "outdated";
    } else if (/^current\b/i.test(rest)) {
      state = "current";
    }

    return { name: name, state: state, detail: detail, path: path };
  }

  function canUninstall(state) {
    return (
      state === "installed" ||
      state === "current" ||
      state === "outdated"
    );
  }

  function isPresent(state) {
    return canUninstall(state);
  }

  function parseStatusOutput(text) {
    var lines = String(text || "").split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var row = parseStatusLine(lines[i]);
      if (row) out.push(row);
    }
    return out;
  }

  /**
   * Build UI model from live CLI status text only (no hard-coded catalog).
   * Optional helpText merges any targets listed in install --help that
   * status omitted (still discovered live, not frozen in source).
   *
   * @param {string} statusText - stdout of `herdr integration status`
   * @param {string} [helpText] - stdout of `herdr integration install --help`
   */
  function buildIntegrationModel(statusText, helpText) {
    var parsed = parseStatusOutput(statusText);
    var byName = {};
    var order = [];
    for (var i = 0; i < parsed.length; i++) {
      byName[parsed[i].name] = parsed[i];
      order.push(parsed[i].name);
    }

    if (helpText) {
      var fromHelp = parseInstallTargetsFromHelp(helpText);
      for (var h = 0; h < fromHelp.length; h++) {
        var n = fromHelp[h];
        if (!byName[n]) {
          byName[n] = {
            name: n,
            state: "unknown",
            detail: "listed by install --help; no status line",
            path: null,
          };
          order.push(n);
        }
      }
    }

    var rows = [];
    for (var t = 0; t < order.length; t++) {
      rows.push(byName[order[t]]);
    }
    return rows;
  }

  function assertTargetSlug(target) {
    if (!isTargetSlug(target)) {
      throw new Error(
        "invalid integration target slug: " +
          target +
          " (CLI owns the catalog — use live status/help)"
      );
    }
  }

  function statusArgv(opts) {
    var argv = ["herdr", "integration", "status"];
    if (opts && opts.outdatedOnly) argv.push("--outdated-only");
    return argv;
  }

  /** Argv for help used to discover install targets live. */
  function installHelpArgv() {
    return ["herdr", "integration", "install", "--help"];
  }

  function installArgv(target) {
    assertTargetSlug(target);
    return ["herdr", "integration", "install", target];
  }

  function uninstallArgv(target) {
    assertTargetSlug(target);
    return ["herdr", "integration", "uninstall", target];
  }

  function shellQuote(s) {
    s = String(s);
    if (/^[a-zA-Z0-9_./:@%+=,-]+$/.test(s)) return s;
    return "'" + s.replace(/'/g, "'\\''") + "'";
  }

  function argvToCommand(argv) {
    return argv.map(shellQuote).join(" ");
  }

  /**
   * Validate argv is a pure herdr integration command we allow the bridge to run.
   * Does NOT hardcode target names — only shape; CLI rejects unknown targets.
   */
  function validateHerdrArgv(argv) {
    if (!argv || !argv.length) {
      return { ok: false, error: "empty argv" };
    }
    if (argv[0] !== "herdr") {
      return { ok: false, error: "only herdr is allowed" };
    }
    if (argv[1] !== "integration") {
      return { ok: false, error: "only herdr integration … is allowed" };
    }
    var sub = argv[2];
    if (sub === "status") {
      if (argv.length === 3) return { ok: true, argv: argv.slice() };
      if (argv.length === 4 && argv[3] === "--outdated-only") {
        return { ok: true, argv: argv.slice() };
      }
      return { ok: false, error: "invalid status args" };
    }
    if (sub === "install" && argv.length === 4 && argv[3] === "--help") {
      return { ok: true, argv: argv.slice() };
    }
    if (sub === "install" || sub === "uninstall") {
      if (argv.length !== 4) {
        return { ok: false, error: "install/uninstall need exactly one target" };
      }
      if (!isTargetSlug(argv[3])) {
        return { ok: false, error: "invalid target slug: " + argv[3] };
      }
      return { ok: true, argv: argv.slice() };
    }
    return { ok: false, error: "unknown integration subcommand: " + sub };
  }

  var api = {
    isTargetSlug: isTargetSlug,
    parseInstallTargetsFromHelp: parseInstallTargetsFromHelp,
    targetsFromStatus: targetsFromStatus,
    parseStatusLine: parseStatusLine,
    parseStatusOutput: parseStatusOutput,
    buildIntegrationModel: buildIntegrationModel,
    canUninstall: canUninstall,
    isPresent: isPresent,
    statusArgv: statusArgv,
    installHelpArgv: installHelpArgv,
    installArgv: installArgv,
    uninstallArgv: uninstallArgv,
    argvToCommand: argvToCommand,
    validateHerdrArgv: validateHerdrArgv,
  };

  root.HerdrCore = api;
  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
})(
  typeof globalThis !== "undefined"
    ? globalThis
    : typeof window !== "undefined"
      ? window
      : this
);
