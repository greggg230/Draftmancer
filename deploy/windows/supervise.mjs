// Keeps a self-hosted Draftmancer up on Windows: runs the built server and
// restarts it whenever it exits. Public traffic reaches it through Tailscale
// Funnel (port 8443) and the Cloudflare Worker in deploy/cloudflare/.
//
//   node deploy/windows/supervise.mjs
//
// Expects .env at the repo root (PORT / NODE_ENV / SECRET_KEY, read by the
// server via --env-file).
// Logs go to logs/. Started at logon by the "Draftmancer" scheduled task
// (deploy/windows/install-task.ps1) through start-hidden.vbs.

import { spawn } from "node:child_process";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const logDir = path.join(root, "logs");
fs.mkdirSync(logDir, { recursive: true });

const MaxLogBytes = 20 * 1024 * 1024;
const supervisorLog = path.join(logDir, "supervisor.log");

function log(msg) {
	fs.appendFileSync(supervisorLog, `${new Date().toISOString()} ${msg}\n`);
}

// Single instance: the hub and the scheduled task can both try to start us.
// A named pipe is released by the OS when its owner dies, so it never goes stale.
const lock = net.createServer();
lock.once("error", () => {
	log("another supervisor is already running; exiting");
	process.exit(0);
});
await new Promise((resolve) => lock.listen("\\\\.\\pipe\\draftmancer-supervisor", resolve));

function openLog(name) {
	const file = path.join(logDir, name);
	try {
		if (fs.statSync(file).size > MaxLogBytes) fs.renameSync(file, file + ".1");
	} catch {
		// Missing file is fine.
	}
	return fs.openSync(file, "a");
}

const children = new Map();
let stopping = false;

function keepAlive(name, command, args) {
	let delay = 5_000;
	const launch = () => {
		if (stopping) return;
		const fd = openLog(`${name}.log`);
		const startedAt = Date.now();
		const child = spawn(command, args, { cwd: root, stdio: ["ignore", fd, fd], windowsHide: true });
		fs.closeSync(fd);
		children.set(name, child);
		log(`${name} started (pid ${child.pid})`);
		const onDone = (why) => {
			children.delete(name);
			if (stopping) return;
			// Back off on crash loops; reset once a run has lasted a while.
			delay = Date.now() - startedAt > 5 * 60_000 ? 5_000 : Math.min(delay * 2, 60_000);
			log(`${name} ${why}; restarting in ${delay / 1000}s`);
			setTimeout(launch, delay);
		};
		child.once("error", (err) => onDone(`failed to start: ${err.message}`));
		child.once("exit", (code, signal) => onDone(`exited (code ${code}, signal ${signal})`));
	};
	launch();
}

function shutdown() {
	stopping = true;
	log("supervisor stopping");
	for (const child of children.values()) child.kill();
	process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

log(`supervisor started (pid ${process.pid})`);

keepAlive("server", process.execPath, [
	"--env-file-if-exists=.env",
	"--experimental-json-modules",
	"--max-old-space-size=4096",
	".",
]);
