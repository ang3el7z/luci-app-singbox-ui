'use strict';
'require view';
'require fs';
'require ui';

const FALLBACK_CORES = [
	{
		id: 'mihomo',
		title: 'Mihomo',
		bin: '/opt/simo/cores/mihomo/bin/mihomo',
		rules: '/opt/simo/cores/mihomo/bin/mihomo-rules',
		config: '/opt/simo/cores/mihomo/config.yaml',
		urlConfig: '/opt/simo/cores/mihomo/url_config.yaml',
	},
	{
		id: 'singbox',
		title: 'sing-box',
		bin: '/opt/simo/cores/singbox/bin/sing-box',
		rules: '/opt/simo/cores/singbox/bin/singbox-rules',
		config: '/opt/simo/cores/singbox/config.json',
		urlConfig: '/opt/simo/cores/singbox/url_config.json',
	},
];

const CORE_MANIFEST_DIR = '/usr/libexec/simo/cores';
const SERVICE_FLAGS = [
	{ id: 'autoupdater', title: 'Autoupdate Service', option: 'autoupdater_service_state', service: 'simo-autoupdater-service' },
	{ id: 'health', title: 'Health Service', option: 'health_autoupdater_service_state', service: 'simo-health-autoupdater-service' },
	{ id: 'memdoc', title: 'Memory Service', option: 'memdoc_service_state', service: 'simo-memdoc-service' },
];

function basename(path) {
	return String(path || '').replace(/\/$/, '').split('/').pop();
}

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

async function readFile(path, fallback) {
	if (!path) return fallback || '';
	try {
		return String(await fs.read(path));
	} catch (_) {
		return fallback || '';
	}
}

async function writeFile(path, content) {
	if (!path) throw new Error('file path is not configured');
	await fs.write(path, String(content || '').trimEnd() + '\n');
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

async function writeUciMany(values) {
	const keys = Object.keys(values || {});
	for (const key of keys)
		await exec('/sbin/uci', ['set', 'simo.main.' + key + '=' + values[key]]);
	await exec('/sbin/uci', ['commit', 'simo']);
}

function boolValue(value, fallback) {
	const clean = String(value == null ? '' : value).trim().toLowerCase();
	if (['1', 'true', 'yes', 'on'].includes(clean)) return true;
	if (['0', 'false', 'no', 'off'].includes(clean)) return false;
	return !!fallback;
}

function normalizeMode(mode) {
	const value = String(mode || '').trim().toLowerCase();
	return ['tproxy', 'tun', 'mixed'].includes(value) ? value : 'tproxy';
}

function normalizeTunStack(stack) {
	const value = String(stack || '').trim().toLowerCase();
	return ['system', 'gvisor', 'mixed'].includes(value) ? value : 'system';
}

function normalizeDnsMode(mode) {
	const value = String(mode || '').trim().toLowerCase();
	return ['fake-ip', 'redir-host'].includes(value) ? value : 'fake-ip';
}

function normalizeManifest(data, fallbackId) {
	const item = data || {};
	const id = String(item.id || fallbackId || '').trim();
	if (!id) return null;
	return {
		id,
		title: String(item.title || id),
		bin: String(item.bin || ''),
		rules: String(item.rules || ''),
		config: String(item.mainConfig || item.config || ''),
		urlConfig: String(item.urlConfig || ''),
	};
}

async function loadCores() {
	try {
		const entries = await fs.list(CORE_MANIFEST_DIR);
		const names = (entries || [])
			.map(item => item.name || item.filename || item.path || '')
			.map(basename)
			.filter(Boolean)
			.sort();
		const cores = [];
		for (const name of names) {
			try {
				const raw = await fs.read(CORE_MANIFEST_DIR + '/' + name + '/manifest.json');
				const core = normalizeManifest(JSON.parse(raw), name);
				if (core) cores.push(core);
			} catch (_) {}
		}
		if (cores.length) return cores;
	} catch (_) {}
	return FALLBACK_CORES.slice();
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

function activeProvider(state) {
	return state.cores.find(c => c.id === state.activeCore) || state.cores[0] || FALLBACK_CORES[0];
}

async function loadLogs() {
	try {
		return await exec('/sbin/logread', ['-e', 'simo']);
	} catch (_) {}
	try {
		const raw = await exec('/sbin/logread', []);
		return raw.split('\n').filter(line => /(simo|mihomo|sing-box|singbox|clash)/i.test(line)).join('\n');
	} catch (_) {
		return '';
	}
}

async function loadState() {
	const activeCore = await readUci('core', 'mihomo');
	const mode = normalizeMode(await readUci('mode', 'tproxy'));
	const cores = await loadCores();
	const provider = cores.find(c => c.id === activeCore) || cores[0] || FALLBACK_CORES[0];
	const flags = {};
	for (const item of SERVICE_FLAGS)
		flags[item.id] = await readUci(item.option, '0') === '1';
	flags.guard = await readUci('internet_only', '0') === '1';

	const statuses = {};
	for (const core of cores)
		statuses[core.id] = await coreStatus(core.id);

	return {
		activeCore: provider.id,
		mode,
		network: {
			tunStack: normalizeTunStack(await readUci('tun_stack', 'system')),
			dnsEnabled: boolValue(await readUci('dns_enabled', '1'), true),
			dnsMode: normalizeDnsMode(await readUci('dns_mode', 'fake-ip')),
			remoteDns: await readUci('remote_dns', 'https://dns.google/dns-query'),
			directDns: await readUci('direct_dns', '223.5.5.5'),
			blockQuic: boolValue(await readUci('block_quic', '1'), true),
		},
		cores,
		flags,
		statuses,
		running: await serviceRunning('simo'),
		configContent: await readFile(provider.config, ''),
		urlContent: await readFile(provider.urlConfig, ''),
	};
}

const CSS = `
.simo-page{--panel:#17191d;--border:#2a2d33;--text:#e3e6eb;--muted:#8f97a3;--ok:#2ecc71;--bad:#f85149;color:var(--text)}
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
.simo-editor,.simo-log{width:100%;min-height:320px;box-sizing:border-box;border:1px solid var(--border);border-radius:6px;background:#111214;color:var(--text);font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12px;line-height:1.45;padding:10px}
.simo-log{min-height:180px;white-space:pre-wrap;overflow:auto}
.simo-input{min-width:260px;flex:1}
.simo-settings-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px;margin-top:10px}
.simo-field{display:flex;flex-direction:column;gap:4px}
.simo-field label{font-size:12px;color:var(--muted)}
.simo-check{display:flex;align-items:center;gap:6px;margin-top:20px;color:var(--text)}
`;

function coreCard(core, state) {
	const active = state.activeCore === core.id;
	const status = state.statuses[core.id] || {};
	return `
<div class="simo-card">
  <h3>${esc(core.title)} ${active ? '<span class="simo-pill simo-pill-on">active</span>' : ''}</h3>
  <div class="simo-muted">Engine: <span class="simo-code">${esc(status.status)}</span></div>
  <div class="simo-muted">Version: <span class="simo-code">${esc(status.version)}</span></div>
  <div class="simo-muted">Config: <span class="simo-code">${esc(core.config)}</span></div>
  <div class="simo-muted">URL: <span class="simo-code">${esc(core.urlConfig || 'provider url')}</span></div>
  <div class="simo-row">
    <button class="cbi-button cbi-button-apply" data-core="${core.id}" data-action="activate">Activate</button>
    <button class="cbi-button cbi-button-positive" data-core="${core.id}" data-action="install">Install / Update Engine</button>
    <button class="cbi-button cbi-button-neutral" data-core="${core.id}" data-action="check">Check Config</button>
  </div>
</div>`;
}

function modeButtonClass(mode, activeMode) {
	return mode === activeMode ? 'cbi-button-positive' : 'cbi-button-apply';
}

function selected(value, current) {
	return value === current ? ' selected' : '';
}

function renderHtml(state) {
	const provider = activeProvider(state);
	const network = state.network || {};
	return `
<style>${CSS}</style>
<div class="simo-page">
  <div class="simo-head">
    <strong>Simo</strong>
    <span>active engine</span>
    <select id="simo-active-core" class="simo-select">
      ${state.cores.map(c => `<option value="${c.id}"${state.activeCore === c.id ? ' selected' : ''}>${esc(c.title)}</option>`).join('')}
    </select>
    <span class="simo-pill ${state.running ? 'simo-pill-on' : 'simo-pill-off'}">${state.running ? 'running' : 'stopped'}</span>
  </div>

  <div class="simo-card">
    <h3>Service Control</h3>
    <div class="simo-row">
      <button class="cbi-button cbi-button-positive" data-service="start">Start</button>
      <button class="cbi-button cbi-button-negative" data-service="stop">Stop</button>
      <button class="cbi-button cbi-button-reload" data-service="restart">Restart</button>
      <button class="cbi-button cbi-button-apply" data-service="reload">Reload</button>
    </div>
  </div>

  <div class="simo-grid">${state.cores.map(core => coreCard(core, state)).join('')}</div>

  <div class="simo-card">
    <h3>Network Mode</h3>
    <div class="simo-muted">Commands are routed to the active engine provider: <span class="simo-code">${esc(provider.rules || 'provider rules')}</span></div>
    <div class="simo-row">
      <button class="cbi-button ${modeButtonClass('tun', state.mode)}" data-mode="enable-tun">Use TUN</button>
      <button class="cbi-button ${modeButtonClass('tproxy', state.mode)}" data-mode="enable-tproxy">Use TPROXY</button>
      <button class="cbi-button ${modeButtonClass('mixed', state.mode)}" data-mode="enable-mixed">Use Mixed</button>
      <button class="cbi-button cbi-button-neutral" data-mode="disable-tun">Disable TUN</button>
      <button class="cbi-button cbi-button-neutral" data-mode="disable-tproxy">Disable TPROXY</button>
      <button class="cbi-button cbi-button-reload" data-mode="repair_policy">Repair Policy</button>
      <button class="cbi-button cbi-button-neutral" data-mode="validate_policy">Validate Policy</button>
    </div>
    <div class="simo-settings-grid">
      <div class="simo-field">
        <label for="simo-tun-stack">TUN stack</label>
        <select id="simo-tun-stack" class="cbi-input-select">
          <option value="system"${selected('system', network.tunStack)}>system</option>
          <option value="gvisor"${selected('gvisor', network.tunStack)}>gvisor</option>
          <option value="mixed"${selected('mixed', network.tunStack)}>mixed</option>
        </select>
      </div>
      <label class="simo-check">
        <input id="simo-block-quic" type="checkbox"${network.blockQuic ? ' checked' : ''} />
        <span>Block QUIC</span>
      </label>
    </div>
  </div>

  <div class="simo-card">
    <h3>DNS</h3>
    <div class="simo-settings-grid">
      <label class="simo-check">
        <input id="simo-dns-enabled" type="checkbox"${network.dnsEnabled ? ' checked' : ''} />
        <span>Use engine DNS</span>
      </label>
      <div class="simo-field">
        <label for="simo-dns-mode">DNS mode</label>
        <select id="simo-dns-mode" class="cbi-input-select">
          <option value="fake-ip"${selected('fake-ip', network.dnsMode)}>fake-ip</option>
          <option value="redir-host"${selected('redir-host', network.dnsMode)}>redir-host</option>
        </select>
      </div>
      <div class="simo-field">
        <label for="simo-remote-dns">Remote DNS</label>
        <input id="simo-remote-dns" class="cbi-input-text" type="text" value="${esc(network.remoteDns)}" />
      </div>
      <div class="simo-field">
        <label for="simo-direct-dns">Direct DNS</label>
        <input id="simo-direct-dns" class="cbi-input-text" type="text" value="${esc(network.directDns)}" />
      </div>
    </div>
    <div class="simo-row">
      <button class="cbi-button cbi-button-positive" data-network-save>Save Network Settings</button>
      <button class="cbi-button cbi-button-apply" data-network-apply>Apply To Active Config</button>
    </div>
  </div>

  <div class="simo-card">
    <h3>Provider Config</h3>
    <div class="simo-muted">Active engine: <span class="simo-code">${esc(provider.title)}</span></div>
    <div class="simo-muted">Config file: <span class="simo-code">${esc(provider.config)}</span></div>
    <div class="simo-row">
      <input id="simo-url-config" class="cbi-input-text simo-input" type="text" value="${esc(String(state.urlContent || '').trim())}" placeholder="Subscription or remote config URL" />
      <button class="cbi-button cbi-button-apply" data-config-action="save-url">Save URL</button>
      <button class="cbi-button cbi-button-positive" data-config-action="update-config">Update Config</button>
    </div>
    <textarea id="simo-config-editor" class="simo-editor" spellcheck="false">${esc(state.configContent)}</textarea>
    <div class="simo-row">
      <button class="cbi-button cbi-button-positive" data-config-action="save-config">Save Config</button>
      <button class="cbi-button cbi-button-apply" data-config-action="check-config">Check Config</button>
      <button class="cbi-button cbi-button-reload" data-config-action="reload-config">Reload From Disk</button>
      <button class="cbi-button cbi-button-reload" data-config-action="restart-service">Restart Service</button>
    </div>
  </div>

  <div class="simo-card">
    <h3>Services</h3>
    <div class="simo-row">
      <button class="cbi-button ${state.flags.guard ? 'cbi-button-negative' : 'cbi-button-positive'}" data-guard>${state.flags.guard ? 'Stop' : 'Start'} Guard</button>
      ${SERVICE_FLAGS.map(item => `<button class="cbi-button ${state.flags[item.id] ? 'cbi-button-negative' : 'cbi-button-positive'}" data-helper="${item.id}">${state.flags[item.id] ? 'Stop' : 'Start'} ${esc(item.title)}</button>`).join('')}
    </div>
  </div>

  <div class="simo-card">
    <h3>Logs</h3>
    <div class="simo-row">
      <button class="cbi-button cbi-button-apply" data-log-refresh>Refresh Logs</button>
    </div>
    <pre id="simo-log" class="simo-log"></pre>
  </div>
</div>`;
}

async function refresh(root) {
	const state = await loadState();
	root.innerHTML = renderHtml(state);
	bind(root, state);
}

async function reloadActiveConfig(root, state) {
	const provider = activeProvider(state);
	const editor = root.querySelector('#simo-config-editor');
	const input = root.querySelector('#simo-url-config');
	if (editor) editor.value = await readFile(provider.config, '');
	if (input) input.value = String(await readFile(provider.urlConfig, '')).trim();
}

function collectNetworkSettings(root) {
	return {
		tunStack: normalizeTunStack(root.querySelector('#simo-tun-stack')?.value || 'system'),
		dnsEnabled: !!root.querySelector('#simo-dns-enabled')?.checked,
		dnsMode: normalizeDnsMode(root.querySelector('#simo-dns-mode')?.value || 'fake-ip'),
		remoteDns: String(root.querySelector('#simo-remote-dns')?.value || '').trim() || 'https://dns.google/dns-query',
		directDns: String(root.querySelector('#simo-direct-dns')?.value || '').trim() || '223.5.5.5',
		blockQuic: !!root.querySelector('#simo-block-quic')?.checked,
	};
}

async function saveNetworkSettings(settings) {
	await writeUciMany({
		tun_stack: settings.tunStack,
		dns_enabled: settings.dnsEnabled ? '1' : '0',
		dns_mode: settings.dnsMode,
		remote_dns: settings.remoteDns,
		direct_dns: settings.directDns,
		block_quic: settings.blockQuic ? '1' : '0',
	});
}

function removeTopLevelYamlKeys(content, keys) {
	const keySet = new Set(keys);
	const lines = String(content || '').split(/\r?\n/);
	const out = [];
	let skip = false;
	for (const line of lines) {
		const key = (line.match(/^([A-Za-z0-9_-]+):/) || [])[1];
		if (key && keySet.has(key)) {
			skip = true;
			continue;
		}
		if (skip && (/^\S/.test(line) || line.trim() === '')) skip = false;
		if (!skip) out.push(line);
	}
	return out.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd();
}

function removeManagedBlock(content) {
	return String(content || '')
		.replace(/\n?# Simo managed network settings start[\s\S]*?# Simo managed network settings end\n?/g, '\n')
		.replace(/\n{3,}/g, '\n\n')
		.trimEnd();
}

function buildMihomoNetworkBlock(mode, settings) {
	const block = ['# Simo managed network settings start'];
	if (mode === 'tproxy' || mode === 'mixed') {
		block.push('redir-port: 7892');
		block.push('tproxy-port: 7894');
	}
	if (mode === 'tun' || mode === 'mixed') {
		block.push('tun:');
		block.push('  enable: true');
		block.push('  device: simo-mihomo-tun');
		block.push('  stack: ' + settings.tunStack);
		block.push('  auto-route: false');
		block.push('  auto-detect-interface: false');
	}
	if (settings.dnsEnabled) {
		block.push('dns:');
		block.push('  enable: true');
		block.push('  listen: 0.0.0.0:7874');
		block.push('  enhanced-mode: ' + settings.dnsMode);
		if (settings.dnsMode === 'fake-ip') {
			block.push('  fake-ip-range: 198.18.0.1/16');
			block.push('  fake-ip-filter:');
			block.push('    - "*.lan"');
			block.push('    - localhost.ptlogin2.qq.com');
		}
		block.push('  nameserver:');
		block.push('    - ' + settings.remoteDns);
		block.push('  default-nameserver:');
		block.push('    - ' + settings.directDns);
	}
	block.push('# Simo managed network settings end');
	return block.join('\n');
}

function applyMihomoConfig(content, mode, settings) {
	const clean = removeTopLevelYamlKeys(removeManagedBlock(content), [
		'redir-port',
		'tproxy-port',
		'tun',
		'dns',
	]);
	return buildMihomoNetworkBlock(mode, settings) + '\n\n' + clean + '\n';
}

function singboxDns(settings) {
	if (!settings.dnsEnabled) return null;
	return {
		servers: [
			{ tag: 'remote', address: settings.remoteDns },
			{ tag: 'direct', address: settings.directDns, detour: 'direct' },
		],
		final: 'remote',
		strategy: 'ipv4_only',
	};
}

function applySingboxConfig(content, mode, settings) {
	let config = {};
	const raw = String(content || '').trim();
	try {
		config = raw ? JSON.parse(raw) : {};
	} catch (_) {
		throw new Error('sing-box config is not valid JSON');
	}
	config.log = config.log || { level: 'info' };
	config.outbounds = Array.isArray(config.outbounds) ? config.outbounds : [];
	if (!config.outbounds.some(item => item && item.tag === 'direct'))
		config.outbounds.push({ type: 'direct', tag: 'direct' });
	config.route = config.route || {};
	config.route.final = config.route.final || 'direct';
	config.inbounds = Array.isArray(config.inbounds) ? config.inbounds : [];
	config.inbounds = config.inbounds.filter(item => item && item.tag !== 'simo-tproxy-in' && item.tag !== 'simo-tun-in');
	if (mode === 'tproxy' || mode === 'mixed')
		config.inbounds.push({ type: 'tproxy', tag: 'simo-tproxy-in', listen: '0.0.0.0', listen_port: 2080 });
	if (mode === 'tun' || mode === 'mixed') {
		config.inbounds.push({
			type: 'tun',
			tag: 'simo-tun-in',
			interface_name: 'singtun0',
			address: ['172.19.0.1/30'],
			mtu: 9000,
			auto_route: false,
			strict_route: false,
			stack: settings.tunStack === 'gvisor' ? 'gvisor' : 'system',
		});
	}
	if (settings.dnsEnabled) config.dns = singboxDns(settings);
	else delete config.dns;
	return JSON.stringify(config, null, 2) + '\n';
}

async function writeMihomoProviderSettings(mode, settings, guardEnabled) {
	const path = '/opt/simo/cores/mihomo/settings';
	const raw = await readFile(path, '');
	const map = {};
	String(raw || '').split(/\r?\n/).forEach(line => {
		const idx = line.indexOf('=');
		if (idx > 0) map[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
	});
	map.PROXY_MODE = mode;
	map.TUN_STACK = settings.tunStack;
	map.BLOCK_QUIC = settings.blockQuic ? 'true' : 'false';
	map.INTERNET_ONLY_SIMO = guardEnabled ? 'true' : 'false';
	const body = Object.keys(map).sort().map(key => key + '=' + map[key]).join('\n') + '\n';
	await writeFile(path, body);
}

async function applyProviderConfig(provider, mode, settings, content, guardEnabled) {
	if (provider.id === 'singbox') return applySingboxConfig(content, mode, settings);
	if (provider.id === 'mihomo') {
		await writeMihomoProviderSettings(mode, settings, guardEnabled);
		return applyMihomoConfig(content, mode, settings);
	}
	return content;
}

function actionToMode(action, fallback) {
	if (action === 'enable-tun') return 'tun';
	if (action === 'enable-tproxy') return 'tproxy';
	if (action === 'enable-mixed') return 'mixed';
	return normalizeMode(fallback);
}

async function applyNetworkToEditor(root, state, mode) {
	const provider = activeProvider(state);
	const editor = root.querySelector('#simo-config-editor');
	const settings = collectNetworkSettings(root);
	const nextMode = normalizeMode(mode || state.mode);
	await saveNetworkSettings(settings);
	await writeUci('mode', nextMode);
	const current = editor ? editor.value : await readFile(provider.config, '');
	const updated = await applyProviderConfig(provider, nextMode, settings, current, !!state.flags.guard);
	if (editor) editor.value = updated;
	await writeFile(provider.config, updated);
	return { mode: nextMode, settings };
}

function bind(root, state) {
	const provider = activeProvider(state);
	const selector = root.querySelector('#simo-active-core');
	if (selector) {
		selector.onchange = async () => {
			try {
				await exec('/etc/init.d/simo', ['stop']);
				await writeUci('core', selector.value);
				notify('info', 'Active engine changed to ' + selector.value);
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
				const nextMode = actionToMode(btn.dataset.mode, state.mode);
				if (btn.dataset.mode.indexOf('enable-') === 0)
					await applyNetworkToEditor(root, state, nextMode);
				await exec('/usr/bin/simo/simo-core', [state.activeCore, 'rules', btn.dataset.mode]);
				notify('info', state.activeCore + ' network command completed');
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	});

	const saveNetworkBtn = root.querySelector('[data-network-save]');
	if (saveNetworkBtn) {
		saveNetworkBtn.onclick = async () => {
			try {
				await saveNetworkSettings(collectNetworkSettings(root));
				notify('info', 'Network settings saved');
				await refresh(root);
			} catch (e) {
				notify('error', e.message);
			}
		};
	}

	const applyNetworkBtn = root.querySelector('[data-network-apply]');
	if (applyNetworkBtn) {
		applyNetworkBtn.onclick = async () => {
			try {
				await applyNetworkToEditor(root, state, state.mode);
				notify('info', 'Network settings applied to active config');
			} catch (e) {
				notify('error', e.message);
			}
		};
	}

	root.querySelectorAll('[data-config-action]').forEach(btn => {
		btn.onclick = async () => {
			const action = btn.dataset.configAction;
			const editor = root.querySelector('#simo-config-editor');
			const url = root.querySelector('#simo-url-config');
			try {
				if (action === 'save-config') {
					await writeFile(provider.config, editor ? editor.value : '');
					notify('info', 'Config saved');
				} else if (action === 'save-url') {
					await writeFile(provider.urlConfig, url ? url.value : '');
					notify('info', 'URL saved');
				} else if (action === 'update-config') {
					await writeFile(provider.urlConfig, url ? url.value : '');
					await exec('/usr/bin/simo/simo-core', [state.activeCore, 'update_config']);
					await reloadActiveConfig(root, state);
					notify('info', 'Config updated');
				} else if (action === 'check-config') {
					await writeFile(provider.config, editor ? editor.value : '');
					await exec('/usr/bin/simo/simo-core', [state.activeCore, 'check']);
					notify('info', 'Config is valid');
				} else if (action === 'reload-config') {
					await reloadActiveConfig(root, state);
					notify('info', 'Config reloaded');
				} else if (action === 'restart-service') {
					await writeFile(provider.config, editor ? editor.value : '');
					await exec('/etc/init.d/simo', ['restart']);
					await refresh(root);
				}
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

	const logBtn = root.querySelector('[data-log-refresh]');
	if (logBtn) {
		logBtn.onclick = async () => {
			const log = root.querySelector('#simo-log');
			try {
				if (log) log.textContent = await loadLogs();
			} catch (e) {
				notify('error', e.message);
			}
		};
	}
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
