'use strict';
'require view';
'require ui';
'require fs';

// ============================================================
// Constants
// ============================================================

const TPROXY_RULE_FILE = '/etc/nftables.d/singbox.nft';
const TUN_INTERFACE    = 'singtun0';
const SINGBOX_BIN      = '/usr/bin/sing-box';
const UPDATER_BIN      = '/usr/bin/singbox-ui/singbox-ui-updater';
const UCI_CONFIG       = 'singbox-ui';
const UCI_SECTION      = 'main';
const ACE_BASE         = '/luci-static/resources/view/singbox-ui/ace/';

const CONFIGS = [
	{ name: 'config.json',  label: 'Main Config #1' },
	{ name: 'config2.json', label: 'Backup Config #2' },
	{ name: 'config3.json', label: 'Backup Config #3' },
];

// ============================================================
// Utilities
// ============================================================

const isValidUrl = url => {
	try { new URL(url); return true; } catch { return false; }
};

/**
 * Extract port from "external_controller" field in a sing-box JSON config.
 * Handles formats like "0.0.0.0:9090", "127.0.0.1:9090", ":9090".
 * Returns port string or null if not found.
 */
const parseDashboardPort = content => {
	const m = (content || '').match(/"external_controller"\s*:\s*"[^"]*:(\d+)"/);
	return m ? m[1] : null;
};

/**
 * Show a LuCI notification.
 */
const NOTIFY_TIMEOUT = { info: 6000, error: 10000 };
let autoHideNotificationEnabled = true;
const notify = (type, msg) => {
	const node    = ui.addNotification(null, msg, type);
	const timeout = NOTIFY_TIMEOUT[type] ?? 6000;
	if (node && autoHideNotificationEnabled)
		setTimeout(() => node.remove?.() ?? node.parentNode?.removeChild(node), timeout);
};

/** Unique /tmp path to avoid race conditions on concurrent requests. */
const tmpPath = prefix =>
	`/tmp/${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}.json`;

function reloadPage(delay = 600) {
	setTimeout(() => location.reload(), delay);
}

/**
 * Disable one or more buttons and show a CSS spinner while an async action runs.
 * If the button is removed from the DOM (card re-rendered) during the action,
 * the finally-block skips it gracefully via isConnected check.
 */
async function withButtons(btns, fn) {
	const list  = Array.isArray(btns) ? btns : (btns ? [btns] : []);
	const saved = list.map(b => b.innerHTML);
	list.forEach(b => {
		b.disabled   = true;
		b.innerHTML  = '<span class="sbox-spinner"></span>\u00A0' + b.textContent.trim();
	});
	try {
		return await fn();
	} finally {
		list.forEach((b, i) => {
			if (b.isConnected) {
				b.disabled  = false;
				b.innerHTML = saved[i];
			}
		});
	}
}

// ============================================================
// File helpers
// ============================================================

async function loadFile(path) {
	try { return (await fs.read(path)) || ''; }
	catch { return ''; }
}

async function saveFile(path, val) {
	await fs.write(path, val);
}

// ============================================================
// Service exec helpers
// ============================================================

async function execService(name, action) {
	try {
		const result = await fs.exec(`/etc/init.d/${name}`, [action]);
		const out    = String(result?.stdout ?? '').trim();
		console.log(`[${name}] ${action}: ${out}`);
		return out;
	} catch (err) {
		console.error(`[${name}] ${action} error:`, err);
		return 'error';
	}
}

/**
 * Lifecycle wrapper: start = enable+start, stop = stop+disable, else passthrough.
 * Logs the final service status after the operation completes.
 */
async function execServiceLifecycle(name, action) {
	const path = `/etc/init.d/${name}`;

	const run = async cmd => {
		try {
			const { stdout } = await fs.exec(path, [cmd]);
			if (stdout?.trim()) console.log(`[${name}] ${cmd}: ${stdout.trim()}`);
		} catch (err) {
			console.error(`[${name}] ${cmd} error:`, err);
		}
	};

	switch (action) {
		case 'stop':  await run('stop');   await run('disable'); break;
		case 'start': await run('enable'); await run('start');   break;
		default:      await run(action);                         break;
	}

	try {
		const { stdout } = await fs.exec(path, ['status']);
		console.log(`[${name}] status: ${stdout?.trim()}`);
	} catch (err) {
		console.error(`[${name}] status error:`, err);
	}
}

async function isServiceActive(name) {
	try   { await fs.stat(`/etc/init.d/${name}`); } catch { return false; }
	try   { return String((await fs.exec(`/etc/init.d/${name}`, ['status']))?.stdout ?? '').includes('running'); }
	catch { return false; }
}

// ============================================================
// nft / tproxy
// ============================================================

async function runNft(args) {
	try { return await fs.exec('/usr/sbin/nft', args); }
	catch { return await fs.exec('/usr/bin/nft', args); }
}

async function isTproxyTablePresent() {
	try {
		const result = await runNft(['list', 'table', 'ip', 'singbox']);
		return (result?.code ?? 1) === 0;
	} catch { return false; }
}

async function isTproxyUciPresent() {
	try {
		const r = await fs.exec('/sbin/uci', ['get', 'firewall.singbox_tproxy']);
		return (r?.code ?? 1) === 0;
	} catch { return false; }
}

async function isTunUciPresent() {
	try {
		const r = await fs.exec('/sbin/uci', ['get', 'network.proxy.device']);
		return String(r?.stdout ?? '').trim() === TUN_INTERFACE;
	} catch { return false; }
}

async function disableTproxy() {
	try   { await runNft(['delete', 'table', 'ip', 'singbox']); }
	catch (e) { console.warn('[tproxy] delete table failed:', e); }
}

async function enableTproxy() {
	try   { await runNft(['-f', TPROXY_RULE_FILE]); }
	catch (e) { console.warn('[tproxy] apply rules failed:', e); }
}

// ============================================================
// UCI helpers
// ============================================================

async function readUciFlag(option, fallback = false) {
	try {
		const r = await fs.exec('/sbin/uci', ['get', `${UCI_CONFIG}.${UCI_SECTION}.${option}`]);
		if ((r?.code ?? 0) !== 0) return fallback;
		const value = String(r?.stdout ?? '').trim();
		if (value === '1') return true;
		if (value === '0') return false;
		return fallback;
	} catch { return fallback; }
}

async function writeUciFlag(option, value) {
	await fs.exec('/sbin/uci', ['set',    `${UCI_CONFIG}.${UCI_SECTION}.${option}=${value ? '1' : '0'}`]);
	await fs.exec('/sbin/uci', ['commit', UCI_CONFIG]);
}

// ============================================================
// Config validation and formatting
// ============================================================

async function isValidConfig(content) {
	if (!content?.trim()) return false;
	const tmp = tmpPath('singbox-check');
	try {
		await fs.write(tmp, content);
		const r = await fs.exec(SINGBOX_BIN, ['check', '-c', tmp]);
		if (r.code === 0) return true;
		let msg = String(r.stderr || '').trim();
		if (msg.includes(tmp)) msg = msg.substring(msg.indexOf(tmp) + tmp.length + 1).trim();
		notify('error', 'Config error: ' + (msg || 'validation failed'));
		return false;
	} catch (e) {
		notify('error', 'Validation error: ' + e.message);
		return false;
	} finally {
		try { await fs.remove(tmp); } catch (_) {}
	}
}

async function formatConfig(content) {
	if (!content?.trim()) return null;
	const tmp = tmpPath('singbox-fmt');
	try {
		await fs.write(tmp, content);
		const r = await fs.exec(SINGBOX_BIN, ['format', '-w', '-c', tmp]);
		if (r.code !== 0) {
			let msg = String(r.stderr || r.stdout || '').trim();
			if (msg.includes(tmp)) msg = msg.substring(msg.indexOf(tmp) + tmp.length + 1).trim();
			notify('error', 'Format failed: ' + (msg || 'unknown error'));
			return null;
		}
		return await loadFile(tmp);
	} catch (e) {
		notify('error', 'Format error: ' + e.message);
		return null;
	} finally {
		try { await fs.remove(tmp); } catch (_) {}
	}
}

/**
 * Count net brace/bracket depth change in a line (ignoring strings and comments).
 * Returns { delta, inBlockComment } where inBlockComment is true if line ends inside /* ... *\/.
 */
function getBraceDelta(line) {
	let delta = 0;
	let i = 0;
	const len = line.length;
	let inBlockComment = false;
	while (i < len) {
		const ch = line[i];
		if (inBlockComment) {
			if (ch === '*' && line[i + 1] === '/') { i += 2; inBlockComment = false; }
			else i++;
		} else if (ch === '"' || ch === "'") {
			const q = ch;
			i++;
			while (i < len) {
				if (line[i] === '\\') i += 2;
				else if (line[i] === q) { i++; break; }
				else i++;
			}
		} else if (ch === '/' && line[i + 1] === '/') {
			break;
		} else if (ch === '/' && line[i + 1] === '*') {
			i += 2;
			inBlockComment = true;
		} else {
			if (ch === '{' || ch === '[') delta++;
			else if (ch === '}' || ch === ']') delta--;
			i++;
		}
	}
	return { delta, inBlockComment };
}

/**
 * Format JSON5 by normalizing indentation (2 spaces per level).
 * Preserves comments, trailing commas, and key order.
 */
function formatJson5(content) {
	if (!content?.trim()) return null;
	const lines = content.split(/\r?\n/);
	let depth = 0;
	let inBlockComment = false;
	const out = [];
	for (let i = 0; i < lines.length; i++) {
		let line = lines[i];
		const trimmed = line.replace(/^\s*/, '');
		if (inBlockComment) {
			const end = trimmed.indexOf('*/');
			if (end === -1) {
				out.push('  '.repeat(depth) + trimmed);
				continue;
			}
			out.push('  '.repeat(depth) + trimmed.slice(0, end + 2));
			line = trimmed.slice(end + 2);
			inBlockComment = false;
			const rest = line.replace(/^\s*/, '');
			if (rest) {
				const { delta, inBlockComment: inBC } = getBraceDelta(rest);
				out.push('  '.repeat(depth) + rest);
				depth += delta;
				inBlockComment = inBC;
			}
		} else {
			const { delta, inBlockComment: inBC } = getBraceDelta(trimmed);
			out.push('  '.repeat(depth) + trimmed);
			depth += delta;
			inBlockComment = inBC;
		}
	}
	return out.join('\n');
}

// ============================================================
// Mode switching
// ============================================================

const MODE_SWITCH_BIN = '/usr/bin/singbox-ui/singbox-ui-mode-switch';

async function execModeSwitch(action) {
	const r = await fs.exec(MODE_SWITCH_BIN, [action]);
	const lines = String(r?.stdout ?? '').trim().split('\n');
	const lastLine = lines[lines.length - 1].trim();
	if (lastLine !== 'ok') {
		throw new Error(String(r?.stderr ?? r?.stdout ?? 'mode switch failed').trim() || 'mode switch failed');
	}
}

/**
 * Show a modal dialog.
 * options: { title, body, buttons: [{ cls, label, action }] }
 * Returns a close() function.
 */
function showModeModal(options) {
	const overlay = document.createElement('div');
	overlay.className = 'sbox-modal-overlay';

	const btns = options.buttons.map((b, i) =>
		`<button type="button" class="cbi-button cbi-button-${b.cls}" data-mi="${i}">${b.label}</button>`
	).join('');

	overlay.innerHTML = `
<div class="sbox-modal">
  <div class="sbox-modal-title">${options.title}</div>
  <div class="sbox-modal-body">${options.body}</div>
  <div class="sbox-modal-actions">
    ${btns}
    <button type="button" class="cbi-button cbi-button-neutral" data-cancel>Cancel</button>
  </div>
</div>`;

	const close = () => overlay.remove();

	overlay.querySelector('[data-cancel]').onclick = close;
	overlay.addEventListener('click', e => { if (e.target === overlay) close(); });

	options.buttons.forEach((b, i) => {
		overlay.querySelector(`[data-mi="${i}"]`).onclick = async btn => {
			close();
			const el = btn.currentTarget;
			el.disabled = true;
			try { await b.action(); } catch (e) { notify('error', e.message); }
		};
	});

	document.body.appendChild(overlay);
	return close;
}

// ============================================================
// Logs
// ============================================================

async function loadSingboxLogs() {
	try {
		const r   = await fs.exec('/sbin/logread');
		const raw = String(r?.stdout ?? '');
		if (!raw) return '';
		return raw.split('\n')
			.filter(l => l.includes('sing-box') || l.includes('singbox-ui'))
			.join('\n')
			.trim();
	} catch { return ''; }
}

// Strip ANSI SGR escape sequences (e.g. \x1b[36m, \x1b[38;5;135m, \x1b[0m)
const ANSI_RE = /\x1b\[[0-9;]*m/g;
// sing-box redundant UTC timestamp: "+0000 2026-03-01 01:31:11 "
const SBOX_TS_RE   = /\+\d{4} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} /g;
// sing-box connection trace ID + elapsed: "[3346304225 5.2s] "
const SBOX_CONN_RE = /\[\d+ \d+\.\d+s\] /g;
// logrus seconds-since-start counter appended to level: "INFO[0000]" → "INFO"
const SBOX_LVL_RE  = /\b(INFO|WARN|ERRO|FATA|DEBU)\[\d+\]/g;

function colorizeLog(raw) {
	if (!raw) return '<span class="sbox-log-debug">No logs yet.</span>';
	return raw.split('\n').map(line => {
		const clean = line
			.replace(ANSI_RE, '')
			.replace(SBOX_TS_RE, '')
			.replace(SBOX_CONN_RE, '')
			.replace(SBOX_LVL_RE, '$1');
		const esc = clean
			.replace(/&/g, '&amp;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;');
		if (/\b(FATA|FATAL|PANIC)\b/.test(clean)) return `<span class="sbox-log-fatal">${esc}</span>`;
		if (/\b(ERRO|ERROR)\b/.test(clean))        return `<span class="sbox-log-error">${esc}</span>`;
		if (/\b(WARN|WARNING)\b/.test(clean))      return `<span class="sbox-log-warn">${esc}</span>`;
		if (/\bINFO\b/.test(clean))                return `<span class="sbox-log-info">${esc}</span>`;
		if (/\b(DEBU|DEBUG)\b/.test(clean))        return `<span class="sbox-log-debug">${esc}</span>`;
		return esc;
	}).join('\n');
}

// ============================================================
// Version info
// ============================================================

async function getVersions() {
	let singboxUi = '\u2014';
	let singbox   = '\u2014';
	try {
		const { stdout } = await fs.exec(SINGBOX_BIN, ['version']);
		const m = stdout?.match(/(\d+\.\d+\.\d+(?:-\S+)?)/);
		if (m) singbox = m[1];
	} catch (_) {}
	try {
		const { stdout } = await fs.exec('/bin/opkg', ['list-installed', 'luci-app-singbox-ui']);
		const m = stdout?.match(/luci-app-singbox-ui[^\d]*([\d.]+(?:-\d+)?)/);
		if (m) singboxUi = m[1];
	} catch (_) {
		try {
			const { stdout } = await fs.exec('/usr/bin/apk', ['info', '-e', 'luci-app-singbox-ui']);
			const m = stdout?.match(/luci-app-singbox-ui-([\d.]+(?:-r\d+)?)/);
			if (m) singboxUi = m[1];
		} catch (_) {}
	}
	return { singboxUi, singbox };
}

// ============================================================
// Ace editor
// ============================================================

function loadScript(src) {
	return new Promise((resolve, reject) => {
		const s  = document.createElement('script');
		s.src    = src;
		s.onload = resolve;
		s.onerror = reject;
		document.head.appendChild(s);
	});
}

async function initAceEditor(el, content) {
	await loadScript(ACE_BASE + 'ace.js');
	await loadScript(ACE_BASE + 'ext-language_tools.js');
	ace.config.set('basePath',   ACE_BASE);
	ace.config.set('workerPath', ACE_BASE);
	const ed = ace.edit(el);
	ed.setTheme('ace/theme/tomorrow_night_bright');
	ed.session.setMode('ace/mode/json5');
	ed.setValue(content || '', -1);
	ed.clearSelection();
	ed.session.setUseWorker(true);
	ed.setOptions({
		fontSize: '13px',
		showPrintMargin: false,
		wrap: true,
		highlightActiveLine: true,
		behavioursEnabled: true,
		showFoldWidgets: true,
		foldStyle: 'markbegin',
		enableBasicAutocompletion: true,
		enableLiveAutocompletion: true,
		enableSnippets: false,
	});
	window.singboxEditor = ed;
	return ed;
}

// ============================================================
// CSS (theme-aware via LuCI CSS variables)
// ============================================================

const PAGE_CSS = `<style>
.sbox-page { width: 100%; box-sizing: border-box; }
.sbox-card {
  background: var(--card-bg-color, #1a1a1a);
  border: 1px solid var(--border-color, #2e2e2e);
  border-radius: 10px;
  padding: 1rem 1.25rem;
  margin-bottom: 0.75rem;
  box-sizing: border-box;
  width: 100%;
}
.sbox-card-title {
  font-size: 0.7em;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--muted, #666);
  font-weight: 700;
  margin-bottom: 0.55rem;
}
.sbox-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.3em 0.55em;
  margin-bottom: 1rem;
  font-size: 1em;
  color: var(--muted, #aaa);
  text-align: center;
}
.sbox-header strong {
  color: var(--text-color, #ddd);
  font-weight: 600;
}
.sbox-header-dot {
  color: var(--muted, #444);
}
.sbox-header-mode {
  font-size: 0.78em;
  padding: 0.15em 0.55em;
  border-radius: 4px;
  border: 1px solid var(--border-color, #333);
  background: var(--card-bg-color, #1a1a1a);
  color: var(--muted, #888);
  font-weight: 500;
}
.sbox-header-mode-conflict {
  border-color: #e74c3c;
  color: #e74c3c;
}
.sbox-header-mode-btn {
  cursor: pointer;
}
.sbox-header-mode-btn:hover {
  border-color: var(--active-color, #4a9eff);
  color: var(--active-color, #4a9eff);
}
.sbox-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.65);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
}
.sbox-modal {
  background: var(--card-bg-color, #1a1a1a);
  border: 1px solid var(--border-color, #2e2e2e);
  border-radius: 10px;
  padding: 1.5rem 1.75rem;
  min-width: 280px;
  max-width: 420px;
  width: 90vw;
  box-sizing: border-box;
}
.sbox-modal-title {
  font-size: 0.95em;
  font-weight: 600;
  margin-bottom: 0.6rem;
  color: var(--text-color, #ddd);
}
.sbox-modal-body {
  font-size: 0.85em;
  color: var(--muted, #aaa);
  margin-bottom: 1.1rem;
  line-height: 1.5;
}
.sbox-modal-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}
.sbox-header-dash {
  font-size: 0.78em;
  padding: 0.15em 0.65em;
  margin-left: 0.25em;
}
.sbox-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}
.sbox-status {
  display: inline-flex;
  align-items: center;
  gap: 0.4em;
  font-weight: 600;
  font-size: 0.9em;
  white-space: nowrap;
}
.sbox-dot {
  width: 8px; height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.sbox-dot-running  { background: #2ecc71; box-shadow: 0 0 6px rgba(46,204,113,0.5); }
.sbox-dot-inactive { background: #e67e22; }
.sbox-dot-error    { background: #e74c3c; }
.sbox-color-running  { color: #2ecc71; }
.sbox-color-inactive { color: #e67e22; }
.sbox-color-error    { color: #e74c3c; }
.sbox-cfg-top {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.55rem;
  margin-bottom: 0.65rem;
}
.sbox-select {
  padding: 0.35rem 0.55rem;
  border-radius: 5px;
  border: 1px solid var(--border-color, #333);
  background: var(--input-bg, #242424);
  color: inherit;
  font-size: 0.9em;
  outline: none;
}
.sbox-select:focus { border-color: var(--active-color, #4a9eff); }
.sbox-input {
  flex: 1;
  min-width: 180px;
  padding: 0.35rem 0.6rem;
  border-radius: 5px;
  border: 1px solid var(--border-color, #333);
  background: var(--input-bg, #242424);
  color: inherit;
  font-size: 0.9em;
  box-sizing: border-box;
  outline: none;
}
.sbox-input:focus { border-color: var(--active-color, #4a9eff); }
.sbox-editor {
  width: 100%;
  height: 550px;
  border: 1px solid var(--border-color, #333);
  border-radius: 6px;
  margin: 0.65rem 0;
  box-sizing: border-box;
}
.sbox-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  align-items: center;
}
@keyframes sbox-spin { to { transform: rotate(360deg); } }
.sbox-spinner {
  display: inline-block;
  width: 0.75em; height: 0.75em;
  border: 2px solid currentColor;
  border-top-color: transparent;
  border-radius: 50%;
  animation: sbox-spin 0.6s linear infinite;
  vertical-align: middle;
}
.sbox-card-tabs {
  display: flex;
  gap: 0.2rem;
  margin-bottom: 0.75rem;
  border-bottom: 1px solid var(--border-color, #2e2e2e);
  padding-bottom: 0;
}
.sbox-tab {
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  padding: 0.3em 0.8em;
  margin-bottom: -1px;
  cursor: pointer;
  color: var(--muted, #888);
  font-size: 0.7em;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  transition: color 0.15s, border-color 0.15s;
}
.sbox-tab:hover { color: var(--text-color, #ddd); }
.sbox-tab-active {
  color: var(--text-color, #ddd);
  border-bottom-color: var(--active-color, #4a9eff);
}
.sbox-log-toolbar {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}
.sbox-log-meta {
  font-size: 0.75em;
  color: var(--muted, #666);
  margin-left: auto;
}
.sbox-log-viewer {
  position: relative;
}
.sbox-log-content {
  width: 100%;
  height: 520px;
  overflow-y: scroll;
  overflow-x: auto;
  background: #0d0d0d;
  border: 1px solid var(--border-color, #2e2e2e);
  border-radius: 6px;
  padding: 0.65rem 0.85rem;
  box-sizing: border-box;
  margin: 0;
  font-family: 'Cascadia Code', 'JetBrains Mono', 'Consolas', 'Menlo', monospace;
  font-size: 11.5px;
  line-height: 1.55;
  white-space: pre;
  color: #c9d1d9;
}
.sbox-log-info  { color: #3fb950; }
.sbox-log-warn  { color: #d29922; }
.sbox-log-error { color: #f85149; }
.sbox-log-fatal { color: #f85149; font-weight: 700; }
.sbox-log-debug { color: #6e7681; }
.sbox-log-scroll-btn {
  position: absolute;
  bottom: 0.65rem;
  right: 1.1rem;
  background: var(--card-bg-color, #1a1a1a);
  border: 1px solid var(--border-color, #444);
  border-radius: 5px;
  padding: 0.2em 0.6em;
  font-size: 0.78em;
  cursor: pointer;
  color: var(--muted, #888);
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.2s;
}
.sbox-log-scroll-btn.visible {
  opacity: 1;
  pointer-events: auto;
}
</style>`;

// ============================================================
// HTML: inner content builders (card wrappers stay in place,
// only innerHTML is swapped on refresh — no full page reload)
// ============================================================

function buildControlInner(state) {
	const sk = state.singboxRunning
		? 'running'
		: (state.singboxStatus === 'error' ? 'error' : 'inactive');
	const statusLabel = sk === 'running' ? 'Running' : (sk === 'error' ? 'Error' : 'Inactive');

	const btn = (cls, action, label, title) =>
		`<button type="button" class="cbi-button cbi-button-${cls}" data-action="${action}"${title ? ` title="${title}"` : ''}>${label}</button>`;

	const svcLabel = () => {
		if (state.healthAutoupdaterServiceTempFlag) return 'Sing-Box & Health Autoupdater';
		if (state.autoupdaterServiceTempFlag)       return 'Sing-Box & Autoupdater';
		return 'Sing-Box';
	};

	const ctrlBtns = [
		state.isInitialConfigValid
			? btn(
				state.singboxRunning ? 'remove' : 'apply',
				'startStop',
				state.singboxRunning ? 'Stop' : 'Start',
				(state.singboxRunning ? 'Stop ' : 'Start ') + svcLabel())
			: '',
		state.singboxRunning && state.isInitialConfigValid
			? btn('reload', 'restart', 'Restart') : '',
	].filter(Boolean).join('');

	return `
  <div class="sbox-row">
    <span class="sbox-status sbox-color-${sk}">
      <span class="sbox-dot sbox-dot-${sk}"></span>${statusLabel}
    </span>
    ${ctrlBtns}
  </div>`;
}

function buildServiceInner(state) {
	const btn = (cls, action, label, title) =>
		`<button type="button" class="cbi-button cbi-button-${cls}" data-action="${action}"${title ? ` title="${title}"` : ''}>${label}</button>`;

	const svcBtns = [
		state.mainConfigHasUrl && !state.healthAutoupdaterEnabled
			? btn(
				state.autoupdaterEnabled ? 'negative' : 'positive',
				'toggleAutoupdater',
				state.autoupdaterEnabled ? 'Stop Autoupdater' : 'Autoupdater',
				state.autoupdaterEnabled
					? 'Stop periodic config update from subscription URL'
					: 'Start periodic config update from subscription URL')
			: '',
		state.mainConfigHasUrl && !state.autoupdaterEnabled
			? btn(
				state.healthAutoupdaterEnabled ? 'negative' : 'positive',
				'toggleHealthAutoupdater',
				state.healthAutoupdaterEnabled ? 'Stop Health Autoupdater' : 'Health Autoupdater',
				state.healthAutoupdaterEnabled
					? 'Stop config update on outbound health failure'
					: 'Update config when outbound health check fails')
			: '',
		btn(
			state.memdocEnabled ? 'negative' : 'positive',
			'toggleMemdoc',
			state.memdocEnabled ? 'Stop Memdoc' : 'Memdoc',
			state.memdocEnabled
				? 'Stop memory monitor'
				: 'Restart sing-box when free RAM is low'),
	].filter(Boolean).join('');

	return `
  <div class="sbox-row">${svcBtns}</div>`;
}

function buildSettingsInner(state) {
	const enabled = !!state.autoHideNotificationEnabled;
	const cls     = enabled ? 'positive' : 'negative';
	const label   = 'Auto Hide Notif';

	return `
  <div class="sbox-row">
    <button type="button" class="cbi-button cbi-button-${cls}" data-action="toggleAutoHideNotification">${label}</button>
    <span class="sbox-muted">Success: 6s, Error: 10s</span>
  </div>`;
}

function buildPageHtml(state) {
	const v         = state.versions;
	const dot       = '<span class="sbox-header-dot">\u00B7</span>';
	const proxyMode = (state.tproxyActive && state.tunActive)
		? 'conflict'
		: (state.tproxyActive ? 'tproxy' : (state.tunActive ? 'tun' : 'custom'));
	const opts      = CONFIGS.map(c => `<option value="${c.name}">${c.label}</option>`).join('');
	const cbtn      = (cls, action, label) =>
		`<button type="button" class="cbi-button cbi-button-${cls}" data-config-action="${action}">${label}</button>`;

	return `
<div class="sbox-header">
  singbox-ui <strong>${v.singboxUi}</strong>
  ${dot}
  sing-box <strong>${v.singbox}</strong>
  ${dot}
  <span id="sbox-mode-badge" class="sbox-header-mode${proxyMode === 'conflict' ? ' sbox-header-mode-conflict' : ''}${proxyMode !== 'custom' ? ' sbox-header-mode-btn' : ''}" data-mode="${proxyMode}">${
		proxyMode === 'custom'   ? 'custom setup' :
		proxyMode === 'conflict' ? '\u26A0 fix: tproxy + tun conflict' :
		proxyMode + ' mode'
	}</span>
  <button type="button" id="sbox-header-dash" class="cbi-button cbi-button-apply sbox-header-dash"${(state.singboxRunning && state.dashboardPort) ? '' : ' style="display:none"'}>Dashboard</button>
</div>
<div class="sbox-card" id="sbox-ctrl-svc">
  <div class="sbox-card-tabs">
    <button type="button" class="sbox-tab sbox-tab-active" data-tab="control">Control</button>
    <button type="button" class="sbox-tab" data-tab="services">Services</button>
    <button type="button" class="sbox-tab" data-tab="settings">Settings</button>
  </div>
  <div id="sbox-tab-control">${buildControlInner(state)}</div>
  <div id="sbox-tab-services" style="display:none">${buildServiceInner(state)}</div>
  <div id="sbox-tab-settings" style="display:none">${buildSettingsInner(state)}</div>
</div>
<div class="sbox-card" id="sbox-config">
  <div class="sbox-card-tabs">
    <button type="button" class="sbox-tab sbox-tab-active" data-tab="config">Config</button>
    <button type="button" class="sbox-tab" data-tab="logs">Logs</button>
  </div>
  <div id="sbox-tab-config">
    <div class="sbox-cfg-top">
      <select id="sbox-config-select" class="sbox-select">${opts}</select>
      <input type="url" id="sbox-url" class="sbox-input" placeholder="Subscription URL: https://\u2026" />
      ${cbtn('positive', 'saveUrl', 'Save URL')}
      ${cbtn('reload',   'update',  'Update')}
    </div>
    <div id="sbox-ace" class="sbox-editor"></div>
    <div class="sbox-actions">
      ${cbtn('apply',    'format',   'Format')}
      ${cbtn('positive', 'save',     'Save')}
      <button type="button" class="cbi-button cbi-button-apply"
        data-config-action="setAsMain" id="sbox-set-main-btn" style="display:none">Set as Main</button>
      ${cbtn('negative', 'clear', 'Clear All')}
    </div>
  </div>
  <div id="sbox-tab-logs" style="display:none">
    <div class="sbox-log-toolbar">
      <span class="sbox-log-meta" id="sbox-log-updated"></span>
    </div>
    <div class="sbox-log-viewer">
      <pre id="sbox-log-content" class="sbox-log-content"></pre>
      <button type="button" class="sbox-log-scroll-btn" id="sbox-log-scroll-btn" title="Scroll to bottom">\u2193 Bottom</button>
    </div>
  </div>
</div>`;
}

// ============================================================
// Page controller
// ============================================================

function initPage(page, state, mainContent, mainUrl) {
	let currentConfig = CONFIGS[0];

	// ----------------------------------------------------------
	// Control card: re-render in place after start/stop/restart
	// (no full page reload needed for status changes)
	// ----------------------------------------------------------

	async function refreshControlCard() {
		const [singboxStatus, tproxyActive, tunActive] = await Promise.all([
			execService('sing-box', 'status'),
			isTproxyUciPresent(),
			isTunUciPresent(),
		]);
		state.singboxStatus  = singboxStatus;
		state.singboxRunning = singboxStatus.includes('running');
		state.tproxyActive   = tproxyActive;
		state.tunActive      = tunActive;

		const card = page.querySelector('#sbox-tab-control');
		if (card) { card.innerHTML = buildControlInner(state); bindControlCard(); }

		updateDashBtn();
	}

	function updateDashBtn() {
		const b = page.querySelector('#sbox-header-dash');
		if (b) b.style.display = (state.singboxRunning && state.dashboardPort) ? '' : 'none';
	}

	function bindControlCard() {
		const actions = {
			async startStop(b) {
				await withButtons(b, async () => {
					try {
						if (state.singboxRunning) {
							if (state.tproxyActive) await disableTproxy();
							await execService('sing-box', 'stop');
							if (state.autoupdaterServiceTempFlag)
								await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
							else if (state.healthAutoupdaterServiceTempFlag)
								await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
							notify('info', 'Sing-Box stopped');
						} else {
							await execService('sing-box', 'start');
							if (state.tproxyActive) await enableTproxy();
							if (state.autoupdaterServiceTempFlag)
								await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
							else if (state.healthAutoupdaterServiceTempFlag)
								await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
							notify('info', 'Sing-Box started');
						}
					} catch (e) {
						notify('error', 'Operation failed: ' + e.message);
					}
					await refreshControlCard();
				});
			},

			async restart(b) {
				await withButtons(b, async () => {
					try {
						await execService('sing-box', 'restart');
						if (state.autoupdaterServiceTempFlag)
							await execServiceLifecycle('singbox-ui-autoupdater-service', 'restart');
						else if (state.healthAutoupdaterServiceTempFlag)
							await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart');
						notify('info', 'Sing-Box restarted');
					} catch (e) {
						notify('error', 'Restart failed: ' + e.message);
					}
					await refreshControlCard();
				});
			},

			dashboard() {
				window.open(`${window.location.protocol}//${window.location.hostname}:9090/ui/`, '_blank');
			},
		};

		page.querySelectorAll('#sbox-tab-control [data-action]').forEach(b => {
			const fn = actions[b.dataset.action];
			if (fn) b.onclick = () => fn(b).catch(() => {});
		});
	}

	// ----------------------------------------------------------
	// Lightweight status poll (catches external stop/start)
	// ----------------------------------------------------------

	const STATUS_POLL_MS = 5000;
	let statusPollId = null;

	function startStatusPoll() {
		if (statusPollId) return;
		statusPollId = setInterval(() => {
			refreshControlCard().catch(() => {});
		}, STATUS_POLL_MS);
	}

	function stopStatusPoll() {
		if (statusPollId) {
			clearInterval(statusPollId);
			statusPollId = null;
		}
	}

	startStatusPoll();

	document.addEventListener('visibilitychange', () => {
		if (document.hidden) stopStatusPoll();
		else startStatusPoll();
	});

	// ----------------------------------------------------------
	// Service card: re-render in place after toggle actions
	// ----------------------------------------------------------

	async function refreshServiceCard() {
		state.autoupdaterEnabled       = await isServiceActive('singbox-ui-autoupdater-service');
		state.healthAutoupdaterEnabled = await isServiceActive('singbox-ui-health-autoupdater-service');
		state.memdocEnabled            = await isServiceActive('singbox-ui-memdoc-service');

		const card = page.querySelector('#sbox-tab-services');
		if (card) { card.innerHTML = buildServiceInner(state); bindServiceCard(); }
	}

	function bindServiceCard() {
		const actions = {
			async toggleAutoupdater(b) {
				await withButtons(b, async () => {
					try {
						if (state.autoupdaterEnabled) {
							await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
							await writeUciFlag('autoupdater_service_state', false);
							notify('info', 'Autoupdater stopped');
						} else {
							await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
							await writeUciFlag('health_autoupdater_service_state', false);
							await writeUciFlag('autoupdater_service_state', true);
							await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
							notify('info', 'Autoupdater started');
						}
					} catch (e) { notify('error', 'Toggle failed: ' + e.message); }
					await refreshServiceCard();
				});
			},

			async toggleHealthAutoupdater(b) {
				await withButtons(b, async () => {
					try {
						if (state.healthAutoupdaterEnabled) {
							await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
							await writeUciFlag('health_autoupdater_service_state', false);
							notify('info', 'Health Autoupdater stopped');
						} else {
							await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
							await writeUciFlag('autoupdater_service_state', false);
							await writeUciFlag('health_autoupdater_service_state', true);
							await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
							notify('info', 'Health Autoupdater started');
						}
					} catch (e) { notify('error', 'Toggle failed: ' + e.message); }
					await refreshServiceCard();
				});
			},

			async toggleMemdoc(b) {
				await withButtons(b, async () => {
					try {
						if (state.memdocEnabled) {
							await execServiceLifecycle('singbox-ui-memdoc-service', 'stop');
							notify('info', 'Memdoc stopped');
						} else {
							await execServiceLifecycle('singbox-ui-memdoc-service', 'start');
							notify('info', 'Memdoc started');
						}
					} catch (e) { notify('error', 'Toggle failed: ' + e.message); }
					await refreshServiceCard();
				});
			},
		};

		page.querySelectorAll('#sbox-tab-services [data-action]').forEach(b => {
			const fn = actions[b.dataset.action];
			if (fn) b.onclick = () => fn(b).catch(() => {});
		});
	}

	// ----------------------------------------------------------
	// Config card: in-place editor/URL updates, no page reload
	// (setAsMain and clear still reload — they swap content)
	// ----------------------------------------------------------

	// ----------------------------------------------------------
	// Settings card: notification behavior
	// ----------------------------------------------------------

	async function refreshSettingsCard() {
		const card = page.querySelector('#sbox-tab-settings');
		if (card) { card.innerHTML = buildSettingsInner(state); bindSettingsCard(); }
	}

	function bindSettingsCard() {
		const actions = {
			async toggleAutoHideNotification(b) {
				await withButtons(b, async () => {
					try {
						state.autoHideNotificationEnabled = !state.autoHideNotificationEnabled;
						autoHideNotificationEnabled = state.autoHideNotificationEnabled;
						await writeUciFlag('autohide_notification', state.autoHideNotificationEnabled);
						notify('info', 'Auto hide notifications ' + (state.autoHideNotificationEnabled ? 'enabled' : 'disabled'));
					} catch (e) {
						notify('error', 'Settings update failed: ' + e.message);
					}
					await refreshSettingsCard();
				});
			},
		};

		page.querySelectorAll('#sbox-tab-settings [data-action]').forEach(b => {
			const fn = actions[b.dataset.action];
			if (fn) b.onclick = () => fn(b).catch(() => {});
		});
	}

	const urlEl      = page.querySelector('#sbox-url');
	const selectEl   = page.querySelector('#sbox-config-select');
	const setMainBtn = page.querySelector('#sbox-set-main-btn');

	if (urlEl) urlEl.value = mainUrl || '';

	const configActions = {
		async saveUrl(b) {
			const url = urlEl?.value.trim() || '';
			if (!url)             return notify('error', 'URL is empty');
			if (!isValidUrl(url)) return notify('error', 'Invalid URL');
			await withButtons(b, async () => {
				try {
					await saveFile('/etc/sing-box/url_' + currentConfig.name, url);
					notify('info', 'URL saved');
					const r = await fs.exec(UPDATER_BIN, [
						'/etc/sing-box/url_' + currentConfig.name,
						'/etc/sing-box/' + currentConfig.name,
					]);
					if (r.code === 2) {
						notify('info', 'No changes detected');
					} else if (r.code !== 0) {
						notify('error', r.stderr || r.stdout || 'Update failed');
					} else {
						const newContent = await loadFile('/etc/sing-box/' + currentConfig.name);
						const ed = window.singboxEditor;
						if (ed) { ed.setValue(newContent, -1); ed.clearSelection(); }
						notify('info', currentConfig.label + ' updated');
				if (currentConfig.name === 'config.json') {
						await execService('sing-box', 'reload');
						notify('info', 'Sing-Box reloaded');
						state.isInitialConfigValid = await isValidConfig(newContent);
						state.mainConfigHasUrl = true;
						state.dashboardPort = parseDashboardPort(newContent);
						await refreshControlCard();
						await refreshServiceCard();
					}
					}
				} catch (e) {
					notify('error', 'Save URL failed: ' + e.message);
				}
			});
		},

		async update(b) {
			await withButtons(b, async () => {
				try {
					const r = await fs.exec(UPDATER_BIN, [
						'/etc/sing-box/url_' + currentConfig.name,
						'/etc/sing-box/' + currentConfig.name,
					]);
					if (r.code === 2) return notify('info', 'No changes detected');
					if (r.code !== 0) return notify('error', r.stderr || r.stdout || 'Update failed');
					const newContent = await loadFile('/etc/sing-box/' + currentConfig.name);
					const ed = window.singboxEditor;
					if (ed) { ed.setValue(newContent, -1); ed.clearSelection(); }
					notify('info', currentConfig.label + ' updated');
					if (currentConfig.name === 'config.json') {
						await execService('sing-box', 'reload');
						notify('info', 'Sing-Box reloaded');
						state.isInitialConfigValid = await isValidConfig(newContent);
						state.dashboardPort = parseDashboardPort(newContent);
						await refreshControlCard();
					}
				} catch (e) { notify('error', 'Update failed: ' + e.message); }
			});
		},

		format(b) {
			const ed = window.singboxEditor;
			if (!ed) return notify('error', 'Editor not ready');
			const val = ed.getValue();
			if (!val?.trim()) return notify('info', 'Nothing to format');

			const applyFormatted = async (formatted) => {
				if (formatted != null) {
					ed.setValue(formatted, -1);
					ed.clearSelection();
					notify('info', 'Formatted');
				}
			};

			showModeModal({
				title: 'Format config',
				body: '<b>sing-box</b> — validates and reorders keys per schema.<br>'
				    + '<b>JSON5</b> — fixes indentation, preserves comments and key order.',
				buttons: [
					{
						cls: 'apply', label: 'sing-box',
						action: () => withButtons(b, async () =>
							applyFormatted(await formatConfig(val))
						),
					},
					{
						cls: 'positive', label: 'JSON5',
						action: () => withButtons(b, async () =>
							applyFormatted(formatJson5(val))
						),
					},
				],
			});
		},

		async save(b) {
			const ed = window.singboxEditor;
			if (!ed) return;
			const val = ed.getValue();
			if (!val) return notify('error', 'Config is empty');
			await withButtons(b, async () => {
				try {
					if (!(await isValidConfig(val))) return;
					await saveFile('/etc/sing-box/' + currentConfig.name, val);
					notify('info', 'Config saved');
					if (currentConfig.name === 'config.json') {
						await execService('sing-box', 'reload');
						notify('info', 'Sing-Box reloaded');
						state.isInitialConfigValid = true;
						state.dashboardPort = parseDashboardPort(val);
						await refreshControlCard();
					}
				} catch (e) { notify('error', 'Save failed: ' + e.message); }
			});
		},

		async setAsMain(b) {
			if (currentConfig.name === 'config.json') return;
			await withButtons(b, async () => {
				try {
					const [nc, no, nu, ou] = await Promise.all([
						loadFile('/etc/sing-box/' + currentConfig.name),
						loadFile('/etc/sing-box/config.json'),
						loadFile('/etc/sing-box/url_' + currentConfig.name),
						loadFile('/etc/sing-box/url_config.json'),
					]);
					await saveFile('/etc/sing-box/config.json',               nc);
					await saveFile('/etc/sing-box/' + currentConfig.name,     no);
					await saveFile('/etc/sing-box/url_config.json',           nu);
					await saveFile('/etc/sing-box/url_' + currentConfig.name, ou);
					await execService('sing-box', 'reload');
					notify('info', currentConfig.label + ' is now main config');
				} catch (e) {
					notify('error', 'Set as main failed: ' + e.message);
				} finally {
					reloadPage();
				}
			});
		},

		clear(b) {
			showModeModal({
				title: 'Clear all data?',
				body:  `Config and URL for <b>${currentConfig.label}</b> will be erased.<br>This cannot be undone.`,
				buttons: [{
					cls: 'remove', label: 'Clear',
					action: async () => {
						await withButtons(b, async () => {
							try {
								await saveFile('/etc/sing-box/' + currentConfig.name,     '{}');
								await saveFile('/etc/sing-box/url_' + currentConfig.name, '');
								if (currentConfig.name === 'config.json') {
									if (await isTproxyTablePresent()) await disableTproxy();
									await execService('sing-box', 'stop');
									await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
									await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
									notify('info', 'Config cleared, services stopped');
								} else {
									notify('info', currentConfig.label + ' cleared');
								}
							} catch (e) {
								notify('error', 'Clear failed: ' + e.message);
							} finally {
								reloadPage();
							}
						});
					},
				}],
			});
		},
	};

	page.querySelectorAll('[data-config-action]').forEach(b => {
		const fn = configActions[b.dataset.configAction];
		if (fn) b.onclick = () => fn(b).catch(() => {});
	});

	// Config select: swap editor content and URL field without page reload
	if (selectEl) {
		selectEl.addEventListener('change', async () => {
			const cfg = CONFIGS.find(c => c.name === selectEl.value);
			if (!cfg) return;
			currentConfig = cfg;
			const [content, url] = await Promise.all([
				loadFile('/etc/sing-box/' + cfg.name),
				loadFile('/etc/sing-box/url_' + cfg.name),
			]);
			const ed = window.singboxEditor;
			if (ed) { ed.setValue(content || '', -1); ed.clearSelection(); }
			if (urlEl)      urlEl.value = url || '';
			if (setMainBtn) setMainBtn.style.display = cfg.name === 'config.json' ? 'none' : 'inline-block';
		});
	}

	// Initial bind
	bindControlCard();
	bindServiceCard();
	bindSettingsCard();

	const dashBtn = page.querySelector('#sbox-header-dash');
	if (dashBtn) dashBtn.onclick = () => {
		if (state.dashboardPort)
			window.open(`${window.location.protocol}//${window.location.hostname}:${state.dashboardPort}/ui/`, '_blank');
	};

	// Mode badge click handler
	const modeBadge = page.querySelector('#sbox-mode-badge');
	if (modeBadge) {
		const mode = modeBadge.dataset.mode;

		const switchTo = async (disable, enable) => {
			notify('info', 'Switching mode\u2026');
			try {
				if (disable) await execModeSwitch(disable);
				if (enable)  await execModeSwitch(enable);
				notify('info', 'Mode switched, reloading\u2026');
				reloadPage(1200);
			} catch (e) {
				notify('error', 'Mode switch failed: ' + e.message);
			}
		};

		if (mode === 'tun') {
			modeBadge.onclick = () => showModeModal({
				title: 'Switch to tproxy mode?',
				body:  'tun interface <b>singtun0</b> will be removed.<br>tproxy nft rules and policy routing will be applied.',
				buttons: [{
					cls: 'apply', label: 'Switch to tproxy',
					action: () => switchTo('disable-tun', 'enable-tproxy'),
				}],
			});
		} else if (mode === 'tproxy') {
			modeBadge.onclick = () => showModeModal({
				title: 'Switch to tun mode?',
				body:  'tproxy nft rules will be removed.<br>tun interface <b>singtun0</b> and firewall zone will be configured.',
				buttons: [{
					cls: 'apply', label: 'Switch to tun',
					action: () => switchTo('disable-tproxy', 'enable-tun'),
				}],
			});
		} else if (mode === 'conflict') {
			modeBadge.onclick = () => showModeModal({
				title: '\u26A0 Conflict: tproxy + tun both active',
				body:  'Both modes are active simultaneously. Disable one to resolve:',
				buttons: [
					{
						cls: 'apply', label: 'Keep tproxy (disable tun)',
						action: () => switchTo('disable-tun', null),
					},
					{
						cls: 'reload', label: 'Keep tun (disable tproxy)',
						action: () => switchTo('disable-tproxy', null),
					},
				],
			});
		}
	}

	// ---------------------------------------------------------------
	// Control / Services / Settings tab switching
	// ---------------------------------------------------------------

	const tabControl   = page.querySelector('[data-tab="control"]');
	const tabServices  = page.querySelector('[data-tab="services"]');
	const tabSettings  = page.querySelector('[data-tab="settings"]');
	const paneControl  = page.querySelector('#sbox-tab-control');
	const paneServices = page.querySelector('#sbox-tab-services');
	const paneSettings = page.querySelector('#sbox-tab-settings');

	const setCtrlSvcTab = name => {
		if (!tabControl || !tabServices || !tabSettings || !paneControl || !paneServices || !paneSettings) return;

		tabControl.classList.toggle('sbox-tab-active', name === 'control');
		tabServices.classList.toggle('sbox-tab-active', name === 'services');
		tabSettings.classList.toggle('sbox-tab-active', name === 'settings');
		paneControl.style.display  = name === 'control' ? '' : 'none';
		paneServices.style.display = name === 'services' ? '' : 'none';
		paneSettings.style.display = name === 'settings' ? '' : 'none';
	};

	if (tabControl && tabServices && tabSettings && paneControl && paneServices && paneSettings) {
		tabControl.onclick  = () => setCtrlSvcTab('control');
		tabServices.onclick = () => setCtrlSvcTab('services');
		tabSettings.onclick = () => setCtrlSvcTab('settings');
	}

	// ---------------------------------------------------------------
	// Config / Logs tab switching
	// ---------------------------------------------------------------

	const tabConfig  = page.querySelector('[data-tab="config"]');
	const tabLogs    = page.querySelector('[data-tab="logs"]');
	const paneConfig = page.querySelector('#sbox-tab-config');
	const paneLogs   = page.querySelector('#sbox-tab-logs');
	const logContent = page.querySelector('#sbox-log-content');
	const logUpdated = page.querySelector('#sbox-log-updated');
	const logScrollBtn  = page.querySelector('#sbox-log-scroll-btn');

	let logTimer = null;

	const isAtBottom = el => el.scrollHeight - el.scrollTop - el.clientHeight < 60;

	const updateScrollBtn = () => {
		if (!logScrollBtn || !logContent) return;
		logScrollBtn.classList.toggle('visible', !isAtBottom(logContent));
	};

	async function refreshLogs() {
		const atBottom = !logContent || isAtBottom(logContent);
		try {
			const raw = await loadSingboxLogs();
			if (logContent) logContent.innerHTML = colorizeLog(raw);
			if (logUpdated) {
				const t = new Date();
				logUpdated.textContent = `Updated ${t.getHours().toString().padStart(2,'0')}:${t.getMinutes().toString().padStart(2,'0')}:${t.getSeconds().toString().padStart(2,'0')}`;
			}
		} catch (_) {}
		if (atBottom && logContent) logContent.scrollTop = logContent.scrollHeight;
		updateScrollBtn();
	}

	function startLogRefresh() {
		refreshLogs();
		logTimer = setInterval(refreshLogs, 3000);
	}

	function stopLogRefresh() {
		clearInterval(logTimer);
		logTimer = null;
	}

	if (logContent) {
		logContent.addEventListener('scroll', updateScrollBtn);
	}

	if (logScrollBtn && logContent) {
		logScrollBtn.onclick = () => {
			logContent.scrollTop = logContent.scrollHeight;
			updateScrollBtn();
		};
	}

	if (tabConfig && tabLogs && paneConfig && paneLogs) {
		tabConfig.onclick = () => {
			tabConfig.classList.add('sbox-tab-active');
			tabLogs.classList.remove('sbox-tab-active');
			paneConfig.style.display = '';
			paneLogs.style.display = 'none';
			stopLogRefresh();
		};
		tabLogs.onclick = () => {
			tabLogs.classList.add('sbox-tab-active');
			tabConfig.classList.remove('sbox-tab-active');
			paneLogs.style.display = '';
			paneConfig.style.display = 'none';
			startLogRefresh();
		};
	}

	document.addEventListener('visibilitychange', () => {
		if (!paneLogs || paneLogs.style.display === 'none') return;
		if (document.hidden) stopLogRefresh();
		else startLogRefresh();
	});

	// Init Ace editor
	const aceEl = page.querySelector('#sbox-ace');
	if (aceEl) {
		initAceEditor(aceEl, mainContent).catch(e => {
			console.error('[singbox-ui] Ace init error:', e);
			notify('error', 'Editor failed to load: ' + e.message);
		});
	}
}

// ============================================================
// Main LuCI view
// ============================================================

return view.extend({
	handleSave:      null,
	handleSaveApply: null,
	handleReset:     null,

	async render() {
		const [
			singboxStatus,
			healthAutoupdaterEnabled,
			autoupdaterEnabled,
			memdocEnabled,
			versions,
			mainContent,
			healthAutoupdaterServiceTempFlag,
			autoupdaterServiceTempFlag,
			mainConfigUrl,
			autoHideNotificationEnabled,
		] = await Promise.all([
			execService('sing-box', 'status'),
			isServiceActive('singbox-ui-health-autoupdater-service'),
			isServiceActive('singbox-ui-autoupdater-service'),
			isServiceActive('singbox-ui-memdoc-service'),
			getVersions(),
			loadFile('/etc/sing-box/config.json'),
			readUciFlag('health_autoupdater_service_state'),
			readUciFlag('autoupdater_service_state'),
			loadFile('/etc/sing-box/url_config.json'),
			readUciFlag('autohide_notification'),
		]);

		const [tproxyActive, tunActive, isInitialConfigValid] = await Promise.all([
			isTproxyUciPresent(),
			isTunUciPresent(),
			isValidConfig(mainContent.trim()),
		]);
		const mainUrl              = mainConfigUrl.trim();

		const state = {
			versions,
			singboxStatus,
			singboxRunning:                   singboxStatus.includes('running'),
			isInitialConfigValid,
			tproxyActive,
			tunActive,
			mainConfigHasUrl:                 isValidUrl(mainUrl),
			dashboardPort:                    parseDashboardPort(mainContent),
			healthAutoupdaterServiceTempFlag,
			autoupdaterServiceTempFlag,
			autoupdaterEnabled,
			healthAutoupdaterEnabled,
			memdocEnabled,
			autoHideNotificationEnabled,
		};
		autoHideNotificationEnabled = !!state.autoHideNotificationEnabled;

		const page = document.createElement('div');
		page.className = 'sbox-page';
		page.innerHTML = PAGE_CSS + buildPageHtml(state);

		setTimeout(() => {
			try {
				initPage(page, state, mainContent, mainUrl);
			} catch (e) {
				console.error('[singbox-ui] initPage error:', e);
				notify('error', 'Page init failed: ' + e.message);
			}
		}, 50);

		return page;
	},
});
