#!/usr/bin/env node
/**
 * jump — Personal SSH connection manager
 * Usage:  node ssh_manager.js [command] [args]
 *         node ssh_manager.js          (interactive menu)
 */

"use strict";

const os   = require("os");
const fs   = require("fs");
const path = require("path");
const net  = require("net");
const { spawnSync, execSync } = require("child_process");
const readline = require("readline");

const CONFIG_DIR   = path.join(os.homedir(), ".ssh_manager");
const DEVICES_FILE = path.join(CONFIG_DIR, "devices.json");
const VERSION      = "1.0.0";

// ── ANSI colors ──────────────────────────────────────────────────────────────
const R      = "\x1b[0m";
const BOLD   = "\x1b[1m";
const DIM    = "\x1b[2m";
const RED    = "\x1b[91m";
const GREEN  = "\x1b[92m";
const YELLOW = "\x1b[93m";
const BLUE   = "\x1b[94m";
const CYAN   = "\x1b[96m";
const WHITE  = "\x1b[97m";

const c = (color, text) => `${color}${text}${R}`;

// ── Storage ──────────────────────────────────────────────────────────────────
function loadDevices() {
  if (fs.existsSync(DEVICES_FILE)) {
    return JSON.parse(fs.readFileSync(DEVICES_FILE, "utf8"));
  }
  return {};
}

function saveDevices(devices) {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(DEVICES_FILE, JSON.stringify(devices, null, 2), "utf8");
}

// ── Print helpers ─────────────────────────────────────────────────────────────
function banner() {
  console.log(`
${BOLD}${CYAN}  ╔══════════════════════════════╗
  ║  ✈  jump  —  ssh manager   ║
  ╚══════════════════════════════╝${R}  ${DIM}v${VERSION}${R}
`);
}

function divider(label = "") {
  const width = 54;
  if (label) {
    const pad = Math.floor((width - label.length - 2) / 2);
    const right = width - pad - label.length - 2;
    console.log(`${DIM}${"─".repeat(pad)} ${label} ${"─".repeat(right)}${R}`);
  } else {
    console.log(`${DIM}${"─".repeat(width)}${R}`);
  }
}

const ok   = (m) => console.log(`  ${GREEN}✓${R}  ${m}`);
const warn = (m) => console.log(`  ${YELLOW}⚠${R}  ${m}`);
const err  = (m) => console.log(`  ${RED}✗${R}  ${m}`);
const info = (m) => console.log(`  ${CYAN}→${R}  ${m}`);

function deviceTag(d) {
  let tag = `${d.user || ""}@${d.host}`;
  if ((d.port || 22) !== 22) tag += `:${d.port}`;
  return tag;
}

function pad(str, len) {
  const visible = str.replace(/\x1b\[[0-9;]*m/g, "");
  return str + " ".repeat(Math.max(0, len - visible.length));
}

// ── Device table ──────────────────────────────────────────────────────────────
function printTable(devices) {
  const names = Object.keys(devices);
  if (names.length === 0) {
    warn("No devices saved yet. Run  add  to add one.");
    return;
  }

  const colName  = Math.max(4, ...names.map(n => n.length));
  const colHost  = Math.max(7, ...names.map(n => (devices[n].host || "").length));
  const colUser  = Math.max(4, ...names.map(n => (devices[n].user || "").length));
  const colPort  = 5;
  const colGroup = Math.max(5, ...names.map(n => (devices[n].group || "—").length));

  const hdr = [
    `  ${BOLD}${CYAN}${"NAME".padEnd(colName)}${R}`,
    `${BOLD}${"HOST/IP".padEnd(colHost)}${R}`,
    `${BOLD}${"USER".padEnd(colUser)}${R}`,
    `${BOLD}${"PORT".padEnd(colPort)}${R}`,
    `${BOLD}${"GROUP".padEnd(colGroup)}${R}`,
    `${BOLD}NOTES${R}`,
  ].join("  ");
  console.log(hdr);
  divider();

  for (const name of names.sort()) {
    const d     = devices[name];
    const group = d.group || "—";
    const notes = d.notes || "";
    const user  = d.user  || "";
    const port  = d.port  || 22;

    const row = [
      `  ${pad(c(BOLD + GREEN, name), colName + BOLD.length + GREEN.length + R.length)}`,
      pad(c(YELLOW, d.host), colHost + YELLOW.length + R.length),
      user.padEnd(colUser),
      pad(c(DIM, String(port)), colPort + DIM.length + R.length),
      group.padEnd(colGroup),
      c(DIM, notes),
    ].join("  ");
    console.log(row);
  }

  divider();
  console.log(`  ${DIM}${names.length} device(s)${R}\n`);
}

// ── Prompt (async readline) ───────────────────────────────────────────────────
function askQuestion(rl, label, defaultVal = "") {
  const hint = defaultVal ? ` [${DIM}${defaultVal}${R}]` : "";
  return new Promise((resolve) => {
    rl.question(`  ${BOLD}${label}${R}${hint}: `, (ans) => {
      resolve(ans.trim() || defaultVal);
    });
  });
}

// ── Commands ──────────────────────────────────────────────────────────────────
function cmdList(devices) {
  banner();
  divider("saved devices");
  printTable(devices);
}

async function cmdAdd(devices, rl) {
  console.log(`\n${BOLD}  Add a new device${R}\n`);

  let name;
  while (!name) {
    name = await askQuestion(rl, "Alias (short name)");
    if (!name) {
      err("Alias cannot be empty.");
      name = null;
    } else if (devices[name]) {
      err(`'${name}' already exists. Use  edit  to update it.`);
      name = null;
    }
  }

  const host  = await askQuestion(rl, "Hostname or IP");
  const user  = await askQuestion(rl, "SSH username", os.userInfo().username || "");
  const portS = await askQuestion(rl, "Port", "22");
  const key   = await askQuestion(rl, "Identity file (.pem/.key path, blank = default)", "");
  const group = await askQuestion(rl, "Group / tag", "");
  const notes = await askQuestion(rl, "Notes", "");

  const port = parseInt(portS, 10) || 22;

  const device = {
    host,
    user,
    port,
    added: new Date().toISOString(),
  };
  if (key)   device.identity = key;
  if (group) device.group    = group;
  if (notes) device.notes    = notes;

  devices[name] = device;
  saveDevices(devices);
  ok(`Saved  ${c(BOLD, name)}  →  ${deviceTag(device)}\n`);
}

function doConnect(name, d) {
  const host = d.host;
  const user = d.user || "";
  const port = d.port || 22;
  const key  = d.identity || "";

  const args = [];
  if (port !== 22) args.push("-p", String(port));
  if (key)         args.push("-i", key);
  args.push(user ? `${user}@${host}` : host);

  info(`Connecting to ${c(BOLD, name)}  (ssh ${args.join(" ")})\n`);

  // Update last_used
  const live = loadDevices();
  if (live[name]) {
    live[name].last_used = new Date().toISOString();
    saveDevices(live);
  }

  const result = spawnSync("ssh", args, { stdio: "inherit", shell: process.platform === "win32" });
  if (result.error && result.error.code === "ENOENT") {
    err("'ssh' not found. Make sure OpenSSH is installed and in your PATH.");
    info("On Windows: Settings → Apps → Optional Features → OpenSSH Client");
  }
}

async function cmdEdit(devices, name, rl) {
  if (!devices[name]) { err(`No device named '${name}'.`); return; }
  const d = devices[name];
  console.log(`\n${BOLD}  Editing '${name}'  ${DIM}(Enter to keep current)${R}\n`);

  d.host     = await askQuestion(rl, "Hostname or IP",        d.host     || "");
  d.user     = await askQuestion(rl, "Username",              d.user     || "");
  const portS = await askQuestion(rl, "Port",                  String(d.port || 22));
  d.port     = parseInt(portS, 10) || 22;
  d.identity = await askQuestion(rl, "Identity file",         d.identity || "");
  d.group    = await askQuestion(rl, "Group",                 d.group    || "");
  d.notes    = await askQuestion(rl, "Notes",                 d.notes    || "");

  for (const k of ["identity", "group", "notes"]) {
    if (!d[k]) delete d[k];
  }

  devices[name] = d;
  saveDevices(devices);
  ok(`Updated '${name}'.\n`);
}

async function cmdRemove(devices, name, rl) {
  if (!devices[name]) { err(`No device named '${name}'.`); return; }
  const ans = await askQuestion(rl, `Delete '${name}'? (yes/no)`, "no");
  if (ans.toLowerCase() === "yes" || ans.toLowerCase() === "y") {
    delete devices[name];
    saveDevices(devices);
    ok(`Removed '${name}'.`);
  } else {
    info("Cancelled.");
  }
}

function cmdPing(devices, name) {
  if (!devices[name]) { err(`No device named '${name}'.`); return; }
  const d    = devices[name];
  const host = d.host;
  const port = d.port || 22;
  info(`Checking ${host}:${port} …`);

  return new Promise((resolve) => {
    const socket = new net.Socket();
    socket.setTimeout(5000);
    socket.connect(port, host, () => {
      ok(`${host}:${port} is ${c(GREEN, "reachable")} (SSH port open)\n`);
      socket.destroy();
      resolve();
    });
    socket.on("error", (e) => {
      err(`${host}:${port} is ${c(RED, "unreachable")} — ${e.message}\n`);
      resolve();
    });
    socket.on("timeout", () => {
      err(`${host}:${port} is ${c(RED, "unreachable")} — timeout\n`);
      socket.destroy();
      resolve();
    });
  });
}

async function cmdCopyId(devices, name, rl) {
  if (!devices[name]) { err(`No device named '${name}'.`); return; }
  const d   = devices[name];
  const key = await askQuestion(rl, "Public key path", path.join(os.homedir(), ".ssh", "id_rsa.pub"));
  const args = ["-i", key];
  const port = d.port || 22;
  if (port !== 22) args.push("-p", String(port));
  const userHost = d.user ? `${d.user}@${d.host}` : d.host;
  args.push(userHost);
  info(`Running: ssh-copy-id ${args.join(" ")}`);
  const r = spawnSync("ssh-copy-id", args, { stdio: "inherit", shell: process.platform === "win32" });
  if (r.error && r.error.code === "ENOENT") {
    err("'ssh-copy-id' not found. On Windows, copy your public key manually:");
    info(`cat ~/.ssh/id_rsa.pub | ssh ${userHost} "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"`);
  }
}

async function cmdExport(devices, rl) {
  const outPath = await askQuestion(rl, "Export to file", "jump_devices.json");
  fs.writeFileSync(outPath, JSON.stringify(devices, null, 2), "utf8");
  ok(`Exported ${Object.keys(devices).length} device(s) to ${outPath}\n`);
}

async function cmdImport(devices, rl) {
  const src = await askQuestion(rl, "Import from file", "jump_devices.json");
  if (!fs.existsSync(src)) { err(`File not found: ${src}`); return; }
  const incoming = JSON.parse(fs.readFileSync(src, "utf8"));
  let merged = 0;
  for (const [name, d] of Object.entries(incoming)) {
    if (devices[name]) {
      const ans = await askQuestion(rl, `'${name}' exists — overwrite? (yes/no)`, "no");
      if (ans.toLowerCase() !== "yes" && ans.toLowerCase() !== "y") continue;
    }
    devices[name] = d;
    merged++;
  }
  saveDevices(devices);
  ok(`Imported ${merged} device(s).\n`);
}

// ── Interactive menu ──────────────────────────────────────────────────────────
async function interactiveMenu() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  // Re-enable raw mode after SSH so readline stays responsive
  rl.on("close", () => process.exit(0));

  let devices = loadDevices();
  banner();

  while (true) {
    divider("saved devices");
    printTable(devices);
    divider("actions");

    const actions = [
      ["c", "connect",  "SSH into a device"],
      ["a", "add",      "Add new device"],
      ["e", "edit",     "Edit a device"],
      ["r", "remove",   "Remove a device"],
      ["p", "ping",     "Ping (check reachability)"],
      ["k", "copy-id",  "Copy SSH key to device"],
      ["x", "export",   "Export devices to JSON"],
      ["i", "import",   "Import devices from JSON"],
      ["q", "quit",     "Exit"],
    ];

    for (const [key, name, desc] of actions) {
      console.log(`  ${c(BOLD + CYAN, `[${key}]`)}  ${c(BOLD, name.padEnd(10))}  ${c(DIM, desc)}`);
    }
    console.log();

    let choice;
    try {
      choice = await new Promise((resolve) => {
        rl.question(`  ${BOLD}>${R} `, resolve);
      });
    } catch {
      break;
    }
    choice = (choice || "").trim().toLowerCase();
    console.log();

    if (choice === "q" || choice === "quit" || choice === "exit") {
      info("Bye!\n");
      rl.close();
      return;
    }

    if (choice === "c" || choice === "connect") {
      const names = Object.keys(devices).sort();
      if (names.length === 0) { warn("No devices. Add one first."); continue; }
      names.forEach((n, i) => console.log(`  ${c(CYAN, `${i+1}.`)} ${n}  ${c(DIM, deviceTag(devices[n]))}`));
      console.log();
      const sel = await askQuestion(rl, "Device name or number");
      if (!sel) continue;
      let target = sel;
      if (/^\d+$/.test(sel)) {
        const idx = parseInt(sel, 10) - 1;
        target = names[idx] || sel;
      }
      if (!devices[target]) { err(`No device '${target}'.`); continue; }
      // Pause readline so SSH gets full tty
      rl.pause();
      doConnect(target, devices[target]);
      rl.resume();
      devices = loadDevices();

    } else if (choice === "a" || choice === "add") {
      await cmdAdd(devices, rl);

    } else if (choice === "e" || choice === "edit") {
      const name = await askQuestion(rl, "Device name to edit");
      if (name) { await cmdEdit(devices, name, rl); devices = loadDevices(); }

    } else if (choice === "r" || choice === "remove") {
      const name = await askQuestion(rl, "Device name to remove");
      if (name) { await cmdRemove(devices, name, rl); devices = loadDevices(); }

    } else if (choice === "p" || choice === "ping") {
      const name = await askQuestion(rl, "Device name to ping");
      if (name) await cmdPing(devices, name);

    } else if (choice === "k" || choice === "copy-id") {
      const name = await askQuestion(rl, "Device name");
      if (name) await cmdCopyId(devices, name, rl);

    } else if (choice === "x" || choice === "export") {
      await cmdExport(devices, rl);

    } else if (choice === "i" || choice === "import") {
      await cmdImport(devices, rl);
      devices = loadDevices();

    } else {
      warn(`Unknown command '${choice}'.`);
    }
  }
}

// ── CLI entry point ───────────────────────────────────────────────────────────
async function main() {
  const args = process.argv.slice(2);
  const cmd  = args[0];
  const arg2 = args[1];

  if (cmd === "--version" || cmd === "-v") {
    console.log(`jump ${VERSION}`);
    return;
  }

  if (cmd === "--help" || cmd === "-h" || cmd === "help") {
    console.log(`
${BOLD}jump${R} ${VERSION} — personal SSH connection manager

${BOLD}USAGE${R}
  jump [command] [name]
  jump                    open interactive menu

${BOLD}COMMANDS${R}
  list                    list all saved devices
  add                     add a new device
  connect  <name>         SSH into a device
  remove   <name>         delete a device
  edit     <name>         edit a device
  ping     <name>         check if SSH port is reachable
  copy-id  <name>         copy your public SSH key to a device
  export                  export devices to a JSON file
  import                  import devices from a JSON file

${BOLD}EXAMPLES${R}
  jump                    (interactive menu)
  jump list
  jump add
  jump connect homeserver
  jump ping nas
`);
    return;
  }

  const devices = loadDevices();

  // Non-interactive commands
  if (cmd === "list") {
    cmdList(devices);
    return;
  }
  if (cmd === "ping" && arg2) {
    await cmdPing(devices, arg2);
    return;
  }
  if (cmd === "connect" && arg2) {
    if (!devices[arg2]) { err(`No device '${arg2}'.`); process.exit(1); }
    doConnect(arg2, devices[arg2]);
    return;
  }

  // Interactive (for add, edit, remove, copy-id, export, import, or no command)
  if (!cmd) {
    await interactiveMenu();
    return;
  }

  // Commands that need readline
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    if (cmd === "add") {
      await cmdAdd(devices, rl);
    } else if (cmd === "edit" && arg2) {
      await cmdEdit(devices, arg2, rl);
    } else if (cmd === "remove" && arg2) {
      await cmdRemove(devices, arg2, rl);
    } else if (cmd === "copy-id" && arg2) {
      await cmdCopyId(devices, arg2, rl);
    } else if (cmd === "export") {
      await cmdExport(devices, rl);
    } else if (cmd === "import") {
      await cmdImport(devices, rl);
    } else {
      err(`Unknown command '${cmd}'. Run  jump --help  for usage.`);
    }
  } finally {
    rl.close();
  }
}

main().catch((e) => {
  if (e.code !== "ERR_USE_AFTER_CLOSE") {
    console.error(e);
    process.exit(1);
  }
});
