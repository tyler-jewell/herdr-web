/**
 * DOM wiring for Herdr control skeleton.
 * Integrations view is real; other nav items are stubs.
 * Spawn path: POST /api/herdr { argv: [...] } via local bridge only.
 */
(function () {
  "use strict";

  var Core = window.HerdrCore;
  var logEl = document.getElementById("log");
  var listEl = document.getElementById("integration-list");
  var bridgeBadge = document.getElementById("bridge-badge");
  var lastModel = [];
  var bridgeOk = false;

  function log(msg, kind) {
    if (!logEl) return;
    var line = document.createElement("div");
    line.className = "log-line" + (kind ? " log-" + kind : "");
    line.textContent =
      new Date().toISOString().slice(11, 19) + "  " + msg;
    logEl.appendChild(line);
    logEl.scrollTop = logEl.scrollHeight;
  }

  function setBridge(ok, detail) {
    bridgeOk = ok;
    if (!bridgeBadge) return;
    bridgeBadge.textContent = ok
      ? "bridge: live"
      : "bridge: offline — " + (detail || "start scripts/serve.sh");
    bridgeBadge.className = "badge " + (ok ? "badge-ok" : "badge-warn");
  }

  /**
   * Run pure herdr argv via local bridge. Never invents install logic.
   */
  function runHerdr(argv) {
    var v = Core.validateHerdrArgv(argv);
    if (!v.ok) {
      return Promise.reject(new Error(v.error));
    }
    var cmd = Core.argvToCommand(v.argv);
    log("→ " + cmd, "cmd");

    return fetch("/api/herdr", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ argv: v.argv }),
    }).then(function (res) {
      return res.json().then(function (body) {
        if (!res.ok || body.ok === false) {
          var err =
            (body && (body.error || body.stderr || body.stdout)) ||
            res.statusText;
          throw new Error(err || "bridge error");
        }
        return body;
      });
    });
  }

  function stateClass(state) {
    if (state === "installed" || state === "current") return "state-installed";
    if (state === "outdated") return "state-outdated";
    if (state === "not-installed") return "state-missing";
    return "state-unknown";
  }

  function stateLabel(state) {
    if (state === "not-installed") return "not installed";
    return state;
  }

  function renderList(model) {
    lastModel = model;
    listEl.innerHTML = "";
    for (var i = 0; i < model.length; i++) {
      listEl.appendChild(rowEl(model[i]));
    }
    document.getElementById("count-label").textContent =
      model.length + " integrations";
  }

  function rowEl(row) {
    var tr = document.createElement("tr");
    tr.dataset.target = row.name;
    tr.dataset.state = row.state;

    var tdName = document.createElement("td");
    tdName.className = "col-name";
    tdName.textContent = row.name;

    var tdState = document.createElement("td");
    tdState.className = "col-state " + stateClass(row.state);
    var badge = document.createElement("span");
    badge.className = "state-badge";
    badge.textContent = stateLabel(row.state);
    tdState.appendChild(badge);
    if (row.detail && row.detail !== stateLabel(row.state)) {
      var det = document.createElement("span");
      det.className = "state-detail";
      det.textContent = " " + row.detail;
      tdState.appendChild(det);
    }

    var tdPath = document.createElement("td");
    tdPath.className = "col-path";
    tdPath.textContent = row.path || "—";
    tdPath.title = row.path || "";

    var tdActions = document.createElement("td");
    tdActions.className = "col-actions";

    var installBtn = document.createElement("button");
    installBtn.type = "button";
    installBtn.className = "btn btn-install";
    installBtn.textContent =
      row.state === "outdated"
        ? "Update"
        : row.state === "current" || row.state === "installed"
          ? "Reinstall"
          : "Install";
    installBtn.dataset.action = "install";
    installBtn.dataset.target = row.name;
    installBtn.title = Core.argvToCommand(Core.installArgv(row.name));

    var uninstallBtn = document.createElement("button");
    uninstallBtn.type = "button";
    uninstallBtn.className = "btn btn-uninstall";
    uninstallBtn.textContent = "Uninstall";
    uninstallBtn.dataset.action = "uninstall";
    uninstallBtn.dataset.target = row.name;
    uninstallBtn.title = Core.argvToCommand(Core.uninstallArgv(row.name));
    // Shared rule with HerdrCore.canUninstall (current/installed/outdated).
    uninstallBtn.disabled = !Core.canUninstall(row.state);

    var copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "btn btn-ghost";
    copyBtn.textContent = "Copy cmd";
    copyBtn.dataset.action = "copy-install";
    copyBtn.dataset.target = row.name;

    tdActions.appendChild(installBtn);
    tdActions.appendChild(uninstallBtn);
    tdActions.appendChild(copyBtn);

    tr.appendChild(tdName);
    tr.appendChild(tdState);
    tr.appendChild(tdPath);
    tr.appendChild(tdActions);
    return tr;
  }

  function refreshStatus() {
    // Live catalog: status (+ optional install --help). Never a frozen list in JS.
    return runHerdr(Core.statusArgv())
      .then(function (body) {
        setBridge(true);
        var stdout = body.stdout || "";
        return runHerdr(Core.installHelpArgv())
          .then(function (helpBody) {
            var helpText =
              (helpBody.stdout || "") + "\n" + (helpBody.stderr || "");
            return { body: body, helpText: helpText };
          })
          .catch(function () {
            return { body: body, helpText: "" };
          });
      })
      .then(function (pack) {
        var body = pack.body;
        var model = Core.buildIntegrationModel(body.stdout || "", pack.helpText);
        renderList(model);
        log(
          "status: " +
            model.length +
            " rows from live CLI (exit " +
            body.exitCode +
            ")",
          "ok"
        );
        if (body.stderr) log(body.stderr.trim(), "warn");
      })
      .catch(function (err) {
        setBridge(false, err.message);
        log("refresh failed: " + err.message, "err");
        // Offline: no hard-coded catalog — empty until bridge + herdr respond.
        if (!lastModel.length) {
          renderList([]);
          log(
            "Start ./scripts/serve.sh for live herdr integration status discovery.",
            "warn"
          );
        }
      });
  }

  function onAction(ev) {
    var btn = ev.target.closest("button[data-action]");
    if (!btn) return;
    var action = btn.dataset.action;
    var target = btn.dataset.target;
    if (!target) return;

    if (action === "copy-install") {
      var cmd = Core.argvToCommand(Core.installArgv(target));
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(cmd).then(
          function () {
            log("copied: " + cmd, "ok");
          },
          function () {
            log("copy failed — cmd: " + cmd, "warn");
          }
        );
      } else {
        log("cmd: " + cmd, "cmd");
      }
      return;
    }

    var argv =
      action === "install"
        ? Core.installArgv(target)
        : action === "uninstall"
          ? Core.uninstallArgv(target)
          : null;
    if (!argv) return;

    btn.disabled = true;
    runHerdr(argv)
      .then(function (body) {
        log(
          (body.stdout || body.stderr || "(no output)").trim() ||
            "exit " + body.exitCode,
          body.exitCode === 0 ? "ok" : "err"
        );
        return refreshStatus();
      })
      .catch(function (err) {
        log(action + " " + target + " failed: " + err.message, "err");
        log(
          "fallback CLI: " + Core.argvToCommand(argv),
          "cmd"
        );
      })
      .then(function () {
        btn.disabled = false;
      });
  }

  function showView(name) {
    var views = document.querySelectorAll("[data-view]");
    for (var i = 0; i < views.length; i++) {
      views[i].hidden = views[i].dataset.view !== name;
    }
    var navs = document.querySelectorAll("nav [data-nav]");
    for (var j = 0; j < navs.length; j++) {
      navs[j].classList.toggle("active", navs[j].dataset.nav === name);
    }
  }

  function initNav() {
    document.querySelector("nav").addEventListener("click", function (ev) {
      var a = ev.target.closest("[data-nav]");
      if (!a) return;
      ev.preventDefault();
      showView(a.dataset.nav);
    });
  }

  function init() {
    if (!Core) {
      document.body.innerHTML =
        "<p>HerdrCore failed to load. Serve via scripts/serve.sh if file:// blocked scripts.</p>";
      return;
    }
    initNav();
    listEl.addEventListener("click", onAction);
    document
      .getElementById("btn-refresh")
      .addEventListener("click", function () {
        refreshStatus();
      });
    document
      .getElementById("btn-outdated")
      .addEventListener("click", function () {
        runHerdr(Core.statusArgv({ outdatedOnly: true }))
          .then(function (body) {
            log("outdated-only:\n" + (body.stdout || body.stderr || ""), "ok");
          })
          .catch(function (err) {
            log("outdated-only failed: " + err.message, "err");
          });
      });

    // No hard-coded targets — wait for live status (or empty offline).
    renderList([]);
    refreshStatus();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
