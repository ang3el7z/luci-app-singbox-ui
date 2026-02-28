'use strict';
'require view';
'require ui';
'require fs';

// ============================================================
// Constants
// ============================================================

const TPROXY_RULE_FILE = '/etc/nftables.d/singbox.nft';
const SINGBOX_BIN      = '/usr/bin/sing-box';
const UPDATER_BIN      = '/usr/bin/singbox-ui/singbox-ui-updater';
const UCI_CONFIG       = 'singbox-ui';
const UCI_SECTION      = 'main';
const ACE_BASE         = '/luci-static/resources/view/singbox-ui/ace/';

const CONFIGS = [
	{ name: 'config.json',  label: 'Main Config'      },
	{ name: 'config2.json', label: 'Backup Config #1' },
	{ name: 'config3.json', label: 'Backup Config #2' },
];

// ============================================================
// Utilities
// ============================================================

const isValidUrl = url => {
	try { new URL(url); return true; } catch { return false; }
};

/**
 * Show a LuCI notification.
 * 'info' notifications auto-dismiss after 4 s — no manual close needed.
 * 'error' notifications stay until the user closes them.
 */
const NOTIFY_TIMEOUT = 4000;
const notify = (type, msg) => {
	const node = ui.addNotification(null, msg, type);
	if (type !== 'error' && node)
		setTimeout(() => node.remove?.() ?? node.parentNode?.removeChild(node), NOTIFY_TIMEOUT);
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
	catch { return await fs.exec('nft', args); }
}

async function isTproxyConfigPresent() {
	try { await fs.stat(TPROXY_RULE_FILE); return true; }
	catch { return false; }
}

async function isTproxyTablePresent() {
	try { await runNft(['list', 'table', 'ip', 'singbox']); return true; }
	catch { return false; }
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

async function readUciFlag(option) {
	try {
		const r = await fs.exec('/sbin/uci', ['get', `${UCI_CONFIG}.${UCI_SECTION}.${option}`]);
		return String(r?.stdout ?? '').trim() === '1';
	} catch { return false; }
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
.sbox-version {
  font-size: 0.8em;
  color: var(--muted, #888);
  margin-bottom: 0.55rem;
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
  height: 450px;
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
</style>`;

// ============================================================
// HTML: inner content builders (card wrappers stay in place,
// only innerHTML is swapped on refresh — no full page reload)
// ============================================================

function buildControlInner(state) {
	const v           = state.versions;
	const dot         = '\u00B7';
	const proxyMode   = state.tproxyConfigPresent ? 'tproxy' : 'tun';
	const sk          = state.singboxRunning
		? 'running'
		: (state.singboxStatus === 'error' ? 'error' : 'inactive');
	const statusLabel = sk === 'running' ? 'Running' : (sk === 'error' ? 'Error' : 'Inactive');

	const btn = (cls, action, label, title) =>
		`<button type="button" class="cbi-button cbi-button-${cls}" data-action="${action}"${title ? ` title="${title}"` : ''}>${label}</button>`;

	const svcLabel = () => {
		if (state.healthAutoupdaterServiceTempFlag) return 'Sing\u2011Box & Health Autoupdater';
		if (state.autoupdaterServiceTempFlag)       return 'Sing\u2011Box & Autoupdater';
		return 'Sing\u2011Box';
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
		state.singboxRunning
			? btn('apply', 'dashboard', 'Dashboard') : '',
	].filter(Boolean).join('');

	return `
  <div class="sbox-version">singbox-ui ${v.singboxUi} ${dot} sing-box ${v.singbox} ${dot} ${proxyMode} mode</div>
  <div class="sbox-card-title">Control</div>
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
  <div class="sbox-card-title">Services</div>
  <div class="sbox-row">${svcBtns}</div>`;
}

function buildPageHtml(state) {
	const opts = CONFIGS.map(c => `<option value="${c.name}">${c.label}</option>`).join('');
	const cbtn = (cls, action, label) =>
		`<button type="button" class="cbi-button cbi-button-${cls}" data-config-action="${action}">${label}</button>`;

	return `
<div class="sbox-card" id="sbox-control">${buildControlInner(state)}</div>
<div class="sbox-card" id="sbox-services">${buildServiceInner(state)}</div>
<div class="sbox-card" id="sbox-config">
  <div class="sbox-card-title">Config</div>
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
		state.singboxStatus = await execService('sing-box', 'status');
		state.singboxRunning = state.singboxStatus.includes('running');
		if (state.singboxRunning)
			state.tproxyActive = state.tproxyConfigPresent || await isTproxyTablePresent();

		const card = page.querySelector('#sbox-control');
		if (card) { card.innerHTML = buildControlInner(state); bindControlCard(); }
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
							notify('info', 'Sing\u2011Box stopped');
						} else {
							await execService('sing-box', 'start');
							if (state.tproxyConfigPresent) await enableTproxy();
							if (state.autoupdaterServiceTempFlag)
								await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
							else if (state.healthAutoupdaterServiceTempFlag)
								await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
							notify('info', 'Sing\u2011Box started');
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
						notify('info', 'Sing\u2011Box restarted');
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

		page.querySelectorAll('#sbox-control [data-action]').forEach(b => {
			const fn = actions[b.dataset.action];
			if (fn) b.onclick = () => fn(b).catch(() => {});
		});
	}

	// ----------------------------------------------------------
	// Service card: re-render in place after toggle actions
	// ----------------------------------------------------------

	async function refreshServiceCard() {
		state.autoupdaterEnabled       = await isServiceActive('singbox-ui-autoupdater-service');
		state.healthAutoupdaterEnabled = await isServiceActive('singbox-ui-health-autoupdater-service');
		state.memdocEnabled            = await isServiceActive('singbox-ui-memdoc-service');

		const card = page.querySelector('#sbox-services');
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

		page.querySelectorAll('#sbox-services [data-action]').forEach(b => {
			const fn = actions[b.dataset.action];
			if (fn) b.onclick = () => fn(b).catch(() => {});
		});
	}

	// ----------------------------------------------------------
	// Config card: in-place editor/URL updates, no page reload
	// (setAsMain and clear still reload — they swap content)
	// ----------------------------------------------------------

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
							notify('info', 'Sing\u2011Box reloaded');
							state.isInitialConfigValid = await isValidConfig(newContent);
							state.mainConfigHasUrl = true;
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
						notify('info', 'Sing\u2011Box reloaded');
						state.isInitialConfigValid = await isValidConfig(newContent);
						await refreshControlCard();
					}
				} catch (e) { notify('error', 'Update failed: ' + e.message); }
			});
		},

		async format(b) {
			const ed = window.singboxEditor;
			if (!ed) return notify('error', 'Editor not ready');
			const val = ed.getValue();
			if (!val?.trim()) return notify('info', 'Nothing to format');
			await withButtons(b, async () => {
				const formatted = await formatConfig(val);
				if (formatted != null) {
					ed.setValue(formatted, -1);
					ed.clearSelection();
					notify('info', 'Formatted');
				}
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
						notify('info', 'Sing\u2011Box reloaded');
						state.isInitialConfigValid = true;
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

		async clear(b) {
			if (!confirm(
				`Clear all data for "${currentConfig.label}"?\n` +
				`Config and URL will be erased. This cannot be undone.`
			)) return;
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
			tproxyConfigPresent,
			mainConfigUrl,
		] = await Promise.all([
			execService('sing-box', 'status'),
			isServiceActive('singbox-ui-health-autoupdater-service'),
			isServiceActive('singbox-ui-autoupdater-service'),
			isServiceActive('singbox-ui-memdoc-service'),
			getVersions(),
			loadFile('/etc/sing-box/config.json'),
			readUciFlag('health_autoupdater_service_state'),
			readUciFlag('autoupdater_service_state'),
			isTproxyConfigPresent(),
			loadFile('/etc/sing-box/url_config.json'),
		]);

		const tproxyActive         = tproxyConfigPresent || await isTproxyTablePresent();
		const isInitialConfigValid = await isValidConfig(mainContent.trim());
		const mainUrl              = mainConfigUrl.trim();

		const state = {
			versions,
			singboxStatus,
			singboxRunning:                   singboxStatus.includes('running'),
			isInitialConfigValid,
			tproxyConfigPresent,
			tproxyActive,
			mainConfigHasUrl:                 isValidUrl(mainUrl),
			healthAutoupdaterServiceTempFlag,
			autoupdaterServiceTempFlag,
			autoupdaterEnabled,
			healthAutoupdaterEnabled,
			memdocEnabled,
		};

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
