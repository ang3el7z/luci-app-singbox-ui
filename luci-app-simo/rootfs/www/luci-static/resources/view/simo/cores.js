'use strict';
'require view';
'require fs';
'require ui';

const CORES = [
	{ id: 'mihomo', title: 'Mihomo', config: '/opt/simo/cores/mihomo/config.yaml' },
	{ id: 'singbox', title: 'sing-box', config: '/opt/simo/cores/singbox/config.json' },
];

const SERVICE_FLAGS = [
	{ id: 'autoupdater', title: 'Autoupdate', option: 'autoupdater_service_state', service: 'simo-autoupdater-service' },
	{ id: 'health', title: 'Health', option: 'health_autoupdater_service_state', service: 'simo-health-autoupdater-service' },
	{ id: 'memdoc', title: 'Memory', option: 'memdoc_service_state', service: 'simo-memdoc-service' },
];

function esc(value) {
	return String(value == null ? '' : value)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;');
}

function notify(type, message) {
	ui.addNotification(null, E('p', String(message || '')), type);
}

async function exec(path, args) {
	const result = await fs.exec(path, args || []);
	if (result && result.code) {
		throw new Error(String(result.stderr || result.stdout || 'command failed').trim());
	}
	return String(result?.stdout || '').trim();
}

async function readUci(option, fallback) {
	try {
		const out = await exec('/sbin/uci', ['get', 'simo.main.' + option]);
		return out || fallback;
	} catch (_) {
		return fallback;
	}
}

async function writeUci(option, value) {
	await exec('/sbin/uci', ['set', 'simo.main.' + option + '=' + value]);
	await exec('/sbin/uci', ['commit', 'simo']);
}

async function coreStatus(core) {
	let status = 'missing';
	let version = 'not installed';
	try { status = await exec('/usr/bin/simo/simo-core', [core, 'status']); } catch (_) {}
	try { version = await exec('/usr/bin/simo/simo-core', [core, 'version']); } catch (_) {}
	return { status, version };
}

async function serviceRunning(name) {
	try {
		return (await exec('/etc/init.d/' + name, ['status'])).includes('running');
	} catch (_) {
		return false;
	}
}

async function loadState() {
	const activeCore = await readUci('core', 'mihomo');
	const mode = await readUci('mode', 'tproxy');
	const flags = {};
	for (const item of SERVICE_FLAGS)
		flags[item.id] = await readUci(item.option, '0') === '1';
	flags.guard = await readUci('internet_only', '0') === '1';

	const statuses = {};
	for (const core of CORES)
		statuses[core.id] = await coreStatus(core.id);

	return {
		activeCore,
		mode,
		flags,
		statuses,
		running: await serviceRunning('simo'),
	};
}

const CSS = `
.simo-page{--bg:#111214;--panel:#17191d;--border:#2a2d33;--text:#e3e6eb;--muted:#8f97a3;--accent:#5c7088;--ok:#2ecc71;--bad:#f85149;color:var(--text)}
.simo-head{display:flex;align-items:center;justify-content:center;flex-wrap:wrap;gap:8px;margin-bottom:12px;color:var(--muted);font-size:13px}
.simo-head strong{color:var(--text)}
.simo-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px}
.simo-card{background:var(--panel);border:1px solid var(--border);border-radius:8px;padding:14px;margin-bottom:10px}
.simo-card h3{margin:0 0 10px;font-size:15px}
.simo-row{display:flex;align-items:center;flex-wrap:wrap;gap:8px;margin-top:8px}
.simo-muted{color:var(--muted);font-size:12px}
.simo-pill{display:inline-flex;align-items:center;border:1px solid var(--border);border-radius:999px;padding:3px 8px;font-size:12px;color:var(--muted)}
.simo-pill-on{border-color:rgba(46,204,113,.45);color:#63d996;background:rgba(46,204,113,.12)}
.simo-pill-off{border-color:rgba(248,81,73,.35);color:#ff8f89;background:rgba(248,81,73,.12)}
.simo-select{min-width:160px}
.simo-code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12px;color:var(--muted)}
`;

function coreCard(core, state) {
	const active = state.activeCore === core.id;
	const status = state.statuses[core.id] || {};
	return `
<div class="simo-card">
  <h3>${esc(core.title)} ${active ? '<span class="simo-pill simo-pill-on">active</span>' : ''}</h3>
  <div class="simo-muted">Binary: <span class="simo-code">${esc(status.status)}</span></div>
  <div class="simo-muted">Version: <span class="simo-code">${esc(status.version)}</span></div>
  <div class="simo-muted">Config: <span class="simo-code">${esc(core.config)}</span></div>
  <div class="simo-row">
    <button class="cbi-button cbi-button-apply" data-core="${core.id}" data-action="activate">Activate</button>
    <button class="cbi-button cbi-button-positive" data-core="${core.id}" data-action="install">Install / Update Core</button>
    <button class="cbi-button cbi-button-neutral" data-core="${core.id}" data-action="check">Check Config</button>
  </div>
</div>`;
}

function renderHtml(state) {
	return `
<style>${CSS}</style>
<div class="simo-page">
  <div class="simo-head">
    <strong>Simo</strong>
    <span>active core</span>
    <select id="simo-active-core" class="simo-select">
      ${CORES.map(c => `<option value="${c.id}"${state.activeCore === c.id ? ' selected' : ''}>${esc(c.title)}</option>`).join('')}
    </select>
    <span class="simo-pill ${state.running ? 'simo-pill-on' : 'simo-pill-off'}">${state.running ? 'running' : 'stopped'}</span>
  </div>

  <div class="simo-card">
    <h3>Control</h3>
    <div class="simo-row">
      <button class="cbi-button cbi-button-positive" data-service="start">Start</button>
      <button class="cbi-button cbi-button-negative" data-service="stop">Stop</button>
      <button class="cbi-button cbi-button-reload" data-service="restart">Restart</button>
      <button class="cbi-button cbi-button-apply" data-service="reload">Reload</button>
      <a class="cbi-button cbi-button-neutral" href="${L.url('admin/services/simo/config')}">Mihomo Config UI</a>
    </div>
  </div>

  <div class="simo-grid">${CORES.map(core => coreCard(core, state)).join('')}</div>

  <div class="simo-card">
    <h3>Core Rules</h3>
    <div class="simo-muted">Actions are routed to the active provider: <span class="simo-code">/opt/simo/cores/${esc(state.activeCore)}/bin/${esc(state.activeCore === 'singbox' ? 'singbox-rules' : 'mihomo-rules')}</span></div>
    <div class="simo-row">
      <button class="cbi-button cbi-button-apply" data-mode="enable-tun">Enable TUN</button>
      <button class="cbi-button cbi-button-neutral" data-mode="disable-tun">Disable TUN</button>
      <button class="cbi-button cbi-button-apply" data-mode="enable-tproxy">Enable TPROXY</button>
      <button class="cbi-button cbi-button-neutral" data-mode="disable-tproxy">Disable TPROXY</button>
      <button class="cbi-button cbi-button-reload" data-mode="repair_policy">Repair Policy</button>
      <button class="cbi-button cbi-button-neutral" data-mode="validate_policy">Validate Policy</button>
    </div>
  </div>

  <div class="simo-card">
    <h3>Services</h3>
    <div class="simo-row">
      <button class="cbi-button ${state.flags.guard ? 'cbi-button-negative' : 'cbi-button-positive'}" data-guard>${state.flags.guard ? 'Stop' : 'Start'} Guard</button>
      ${SERVICE_FLAGS.map(item => `<button class="cbi-button ${state.flags[item.id] ? 'cbi-button-negative' : 'cbi-button-positive'}" data-helper="${item.id}">${state.flags[item.id] ? 'Stop' : 'Start'} ${esc(item.title)}</button>`).join('')}
    </div>
  </div>
</div>`;
}

async function refresh(root) {
	const state = await loadState();
	root.innerHTML = renderHtml(state);
	bind(root, state);
}

function bind(root, state) {
	const selector = root.querySelector('#simo-active-core');
	if (selector) {
		selector.onchange = async () => {
			try {
				await exec('/etc/init.d/simo', ['stop']);
				await writeUci('core', selector.value);
				notify('info', 'Active core changed to ' + selector.value);
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	}

	root.querySelectorAll('[data-service]').forEach(btn => {
		btn.onclick = async () => {
			try {
				await exec('/etc/init.d/simo', [btn.dataset.service]);
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	});

	root.querySelectorAll('[data-core]').forEach(btn => {
		btn.onclick = async () => {
			const core = btn.dataset.core;
			try {
				if (btn.dataset.action === 'activate') {
					await exec('/etc/init.d/simo', ['stop']);
					await writeUci('core', core);
				} else if (btn.dataset.action === 'install') {
					await exec('/usr/bin/simo/simo-core', [core, 'install_latest']);
				} else if (btn.dataset.action === 'check') {
					await exec('/usr/bin/simo/simo-core', [core, 'check']);
					notify('info', core + ' config is valid');
				}
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	});

	root.querySelectorAll('[data-mode]').forEach(btn => {
		btn.onclick = async () => {
			try {
				await exec('/usr/bin/simo/simo-core', [state.activeCore, 'rules', btn.dataset.mode]);
				notify('info', state.activeCore + ' rules command completed');
			} catch (e) {
				notify('error', e.message);
			}
		};
	});

	const guardBtn = root.querySelector('[data-guard]');
	if (guardBtn) {
		guardBtn.onclick = async () => {
			const next = state.flags.guard ? '0' : '1';
			try {
				await writeUci('internet_only', next);
				await exec('/usr/bin/simo/simo-core', [state.activeCore, 'rules', 'guard_refresh']);
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	}

	root.querySelectorAll('[data-helper]').forEach(btn => {
		btn.onclick = async () => {
			const item = SERVICE_FLAGS.find(x => x.id === btn.dataset.helper);
			if (!item) return;
			const next = state.flags[item.id] ? '0' : '1';
			try {
				await writeUci(item.option, next);
				await exec('/etc/init.d/' + item.service, [next === '1' ? 'start' : 'stop']);
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	});
}

return view.extend({
	handleSave: null,
	handleSaveApply: null,
	handleReset: null,

	async render() {
		const root = E('div');
		await refresh(root);
		return root;
	}
});
