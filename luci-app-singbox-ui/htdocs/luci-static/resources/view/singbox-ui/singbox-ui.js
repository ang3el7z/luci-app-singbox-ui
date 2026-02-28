'use strict';
'require view';
'require form';
'require ui';
'require fs';
'require uci';

// === Global variables =====================================================

let editor = null;

// === Helpers ==============================================================

const isValidUrl = url => {
  try { new URL(url); return true; } catch { return false; }
};

const notify = (type, msg) => ui.addNotification(null, msg, type);

const getInputValueByKey = (key) => {
  const id = `widget.cbid.singbox-ui.main.${key}`;
  return document.querySelector(`#${CSS.escape(id)}`)?.value.trim();
};

const TPROXY_RULE_FILE = '/etc/nftables.d/singbox.nft';
const CARD_STYLE = 'margin-bottom:1rem;padding:1rem 1.25rem;background:var(--card-bg-color, #1e1e1e);border-radius:10px;border:1px solid var(--border-color, #333);box-sizing:border-box;width:100%;';

async function loadFile(path) {
  try { return (await fs.read(path)) || ''; }
  catch { return ''; }
}

async function saveFile(path, val, msg) {
  try {
    await fs.write(path, val);
    notify('info', msg);
  } catch (e) {
    notify('error', 'Error: ' + e.message);
  }
}

async function execService(name, action) {
  try {
    const result = await fs.exec(`/etc/init.d/${name}`, [action]);
    const stdout = (result && result.stdout != null) ? String(result.stdout) : '';
    console.log(`[${name}] ${action} output: ${stdout.trim()}`);
    return stdout.trim();
  } catch (err) {
    console.error(`[${name}] Error executing "${action}":`, err);
    return 'error';
  }
}

async function runNft(args) {
  try {
    return await fs.exec('/usr/sbin/nft', args);
  } catch (e) {
    return await fs.exec('nft', args);
  }
}

async function isTproxyConfigPresent() {
  try {
    await fs.stat(TPROXY_RULE_FILE);
    return true;
  } catch {
    return false;
  }
}

async function isTproxyTablePresent() {
  try {
    await runNft(['list', 'table', 'ip', 'singbox']);
    return true;
  } catch {
    return false;
  }
}

async function disableTproxy() {
  try {
    await runNft(['delete', 'table', 'ip', 'singbox']);
    console.log('[tproxy] nft table deleted');
  } catch (e) {
    console.warn('[tproxy] Failed to delete nft table:', e);
  }
}

async function enableTproxy() {
  try {
    await runNft(['-f', TPROXY_RULE_FILE]);
    console.log('[tproxy] nft rules applied');
  } catch (e) {
    console.warn('[tproxy] Failed to apply nft rules:', e);
  }
}

async function execServiceLifecycle(name, action) {
  const path = `/etc/init.d/${name}`;

  const run = async (cmd) => {
    try {
      console.log(`[${name}] Running: ${cmd}`);
      const { stdout } = await fs.exec(path, [cmd]);
      if (stdout?.trim()) {
        console.log(`[${name}] ${cmd} output: ${stdout.trim()}`);
      }
    } catch (err) {
      console.error(`[${name}] Error running "${cmd}":`, err);
    }
  };

  switch (action) {
    case 'stop':
      await run('stop');
      await run('disable');
      break;
    case 'start':
      await run('enable');
      await run('start');
      break;
    default:
      await execService(name, action);
      break;
  }

  try {
    const result = await fs.exec(path, ['status']);
    const stdout = (result && result.stdout != null) ? String(result.stdout) : '';
    console.log(`[${name}] Final status: ${stdout.trim()}`);
  } catch (err) {
    console.error(`[${name}] Failed to get final status:`, err);
  }
}

async function isValidConfigFile(content) {
  const tmpPath = '/tmp/singbox-config.json';
  let result = false;

  try {
    await fs.write(tmpPath, content);
  } catch (e) {
    notify('error', 'Failed to write temp config: ' + e.message);
    return false;
  }

  try {
    const checkConfig = await fs.exec("/usr/bin/sing-box", ["check", "-c", tmpPath]);
    if (checkConfig.code === 0) {
      result = true;
    } else {
      let errorMsg = checkConfig.stderr.trim();
      if (errorMsg.includes(tmpPath)) {
        errorMsg = errorMsg.substring(errorMsg.indexOf(tmpPath) + tmpPath.length + 1).trim();
      }
      notify('error', 'Config error: ' + errorMsg);
    }
  } catch (e) {
    notify('error', 'Error: ' + e.message);
  }

  try {
    await fs.remove(tmpPath);
  } catch (e) {
    notify('error', 'Failed to remove temp config: ' + e.message);
  }

  return result;
}

/** Format config via sing-box format -c (write temp file, format -w, read back). */
async function formatConfigWithSingBox(content) {
  const tmpPath = '/tmp/singbox-format.json';
  if (!content || !content.trim()) return null;
  try {
    await fs.write(tmpPath, content);
  } catch (e) {
    notify('error', 'Failed to write temp config: ' + e.message);
    return null;
  }
  try {
    const formatResult = await fs.exec('/usr/bin/sing-box', ['format', '-w', '-c', tmpPath]);
    if (formatResult.code !== 0) {
      let err = (formatResult.stderr || formatResult.stdout || '').trim();
      if (err.includes(tmpPath)) err = err.substring(err.indexOf(tmpPath) + tmpPath.length + 1).trim();
      notify('error', 'Format failed: ' + (err || 'Unknown error'));
      return null;
    }
    return await loadFile(tmpPath);
  } catch (e) {
    notify('error', 'Format error: ' + e.message);
    return null;
  } finally {
    try { await fs.remove(tmpPath); } catch (_) {}
  }
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = src;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
  });
}

async function setUciOption(option, mode, value = null) {
  const config = 'singbox-ui';
  const section = 'main';
  
  if (mode === 'read') {
    try {
      // Р§РёС‚Р°РµРј С‡РµСЂРµР· fs.exec
      const result = await fs.exec('/sbin/uci', ['get', `${config}.${section}.${option}`]);
      const out = (result && result.stdout != null) ? String(result.stdout) : '';
      return out.trim() === '1';
    } catch {
      return false;
    }
  }

  if (mode === 'write') {
    try {
      const val = value ? '1' : '0';
      
      // РСЃРїРѕР»СЊР·СѓРµРј РїСЂСЏРјСѓСЋ РєРѕРјР°РЅРґСѓ uci
      await fs.exec('/sbin/uci', ['set', `${config}.${section}.${option}=${val}`]);
      await fs.exec('/sbin/uci', ['commit', config]);
    } catch (e) {
      notify('error', `Failed to set UCI option "${option}": ${e.message || e.toString()}`);
    }
  }
}

function reloadPage(delay = 1000) {
  setTimeout(() => location.reload(), delay);
}

// === Controls =============================================================

async function isServiceActive(name) {
    console.log(`Checking if service "${name}" exists...`);
    try {
      await fs.stat(`/etc/init.d/${name}`);
      console.log(`Service "${name}" found.`);
    } catch {
      console.log(`Service "${name}" not found.`);
      return false;
    }
  
    try {
      console.log(`Checking status of service "${name}"...`);
      const result = await fs.exec(`/etc/init.d/${name}`, ['status']);
      const stdout = (result && result.stdout != null) ? String(result.stdout) : '';
      const running = stdout.trim().includes('running');
      console.log(`Service "${name}" status output: "${stdout.trim()}"`);
      console.log(`Service "${name}" is ${running ? 'running' : 'not running'}.`);
      return running;
    } catch (e) {
      console.log(`Error while checking status of service "${name}":`, e);
      return false;
    }
}

/** Get versions from packages: opkg/apk for luci-app-singbox-ui, sing-box version for binary. */
async function getPackageVersions() {
  let singboxUi = 'вЂ”';
  let singbox = 'вЂ”';
  try {
    const { stdout: sbOut } = await fs.exec('/usr/bin/sing-box', ['version']);
    const m = sbOut && sbOut.match(/(\d+\.\d+\.\d+(?:-\S+)?)/);
    if (m) singbox = m[1];
  } catch (_) {}
  try {
    const { stdout: opkgOut } = await fs.exec('/bin/opkg', ['list-installed', 'luci-app-singbox-ui']);
    const v = opkgOut && opkgOut.match(/luci-app-singbox-ui[^\d]*([\d.]+(?:-\d+)?)/);
    if (v) singboxUi = v[1];
  } catch (_) {
    try {
      const { stdout: apkOut } = await fs.exec('/usr/bin/apk', ['info', '-e', 'luci-app-singbox-ui']);
      const v = apkOut && apkOut.match(/luci-app-singbox-ui-([\d.]+(?:-r\d+)?)/);
      if (v) singboxUi = v[1];
    } catch (_) {}
  }
  return { singboxUi, singbox };
}

// === UI: Pure HTML rendering (no LuCI form system) ========================

function buildPageCss() {
  return `<style>
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
.sbox-dot-running { background: #2ecc71; box-shadow: 0 0 6px rgba(46,204,113,0.5); }
.sbox-dot-inactive { background: #e67e22; }
.sbox-dot-error { background: #e74c3c; }
.sbox-color-running { color: #2ecc71; }
.sbox-color-inactive { color: #e67e22; }
.sbox-color-error { color: #e74c3c; }
.sbox-cfg-top {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.55rem;
  margin-bottom: 0.65rem;
}
.sbox-label {
  font-size: 0.82em;
  color: var(--muted, #aaa);
  white-space: nowrap;
  font-weight: 500;
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
</style>`;
}

function buildPageHtml(state, configs) {
  const v = state.versions;
  const dot = '\u00B7';
  const proxyMode = state.tproxyConfigPresent ? 'tproxy mode' : 'tun mode';
  const sk = state.singboxStatus === 'running' ? 'running' : state.singboxStatus === 'error' ? 'error' : 'inactive';
  const statusLabel = sk === 'running' ? 'Running' : sk === 'error' ? 'Error' : 'Inactive';
  const b = (cls, action, label, title) =>
    `<button type="button" class="cbi-button cbi-button-${cls}" data-action="${action}"${title ? ` title="${title}"` : ''}>${label}</button>`;
  const cb = (cls, action, label) =>
    `<button type="button" class="cbi-button cbi-button-${cls}" data-config-action="${action}">${label}</button>`;

  const svcNames = () => {
    const n = ['Sing\u2011Box'];
    if (state.healthAutoupdaterServiceTempFlag) n.push('Health Autoupdater');
    else if (state.autoupdaterServiceTempFlag) n.push('Autoupdater');
    return n.join(' & ');
  };

  const ctrlBtns = [
    state.isInitialConfigValid
      ? b(state.singboxRunning ? 'remove' : 'apply', 'startStop',
          state.singboxRunning ? 'Stop' : 'Start',
          (state.singboxRunning ? 'Stop ' : 'Start ') + svcNames())
      : '',
    state.singboxRunning && state.isInitialConfigValid
      ? b('reload', 'restart', 'Restart') : '',
    state.singboxRunning ? b('apply', 'dashboard', 'Dashboard') : ''
  ].filter(Boolean).join('');

  const svcBtns = [
    state.mainConfigHasUrl && !state.healthAutoupdaterEnabled
      ? b(state.autoupdaterEnabled ? 'negative' : 'positive', 'toggleAutoupdater',
          state.autoupdaterEnabled ? 'Stop Autoupdater' : 'Autoupdater',
          state.autoupdaterEnabled ? 'Stop periodic config update from subscription URL' : 'Start periodic config update from subscription URL') : '',
    state.mainConfigHasUrl && !state.autoupdaterEnabled
      ? b(state.healthAutoupdaterEnabled ? 'negative' : 'positive', 'toggleHealthAutoupdater',
          state.healthAutoupdaterEnabled ? 'Stop Health Autoupdater' : 'Health Autoupdater',
          state.healthAutoupdaterEnabled ? 'Stop config update on outbound health failure' : 'Start config update when outbound health check fails') : '',
    b(state.memdocEnabled ? 'negative' : 'positive', 'toggleMemdoc',
      state.memdocEnabled ? 'Stop Memdoc' : 'Memdoc',
      state.memdocEnabled ? 'Stop memory monitor (restart sing-box on low RAM)' : 'Start memory monitor: restart sing-box when free RAM is low')
  ].filter(Boolean).join('');

  const opts = configs.map(c => `<option value="${c.name}">${c.label}</option>`).join('');

  return `
<div class="sbox-card" id="sbox-control">
  <div class="sbox-version">singbox-ui ${v.singboxUi} ${dot} sing-box ${v.singbox} ${dot} ${proxyMode}</div>
  <div class="sbox-card-title">Control</div>
  <div class="sbox-row">
    <span class="sbox-status sbox-color-${sk}">
      <span class="sbox-dot sbox-dot-${sk}"></span>${statusLabel}
    </span>
    ${ctrlBtns}
  </div>
</div>
<div class="sbox-card" id="sbox-services">
  <div class="sbox-card-title">Services</div>
  <div class="sbox-row">${svcBtns}</div>
</div>
<div class="sbox-card" id="sbox-config">
  <div class="sbox-card-title">Config</div>
  <div class="sbox-cfg-top">
    <select id="singbox-ui-config-select" class="sbox-select">${opts}</select>
    <input type="url" id="singbox-ui-url" class="sbox-input" placeholder="Subscription URL: https://subscribe-url" />
    ${cb('positive', 'saveUrl', 'Save URL')}
    ${cb('reload', 'update', 'Update')}
  </div>
  <div id="singbox-ui-ace" class="sbox-editor"></div>
  <div class="sbox-actions">
    ${cb('apply', 'format', 'Format')}
    ${cb('positive', 'save', 'Save')}
    <button type="button" class="cbi-button cbi-button-apply" data-config-action="setAsMain" id="singbox-ui-set-main-btn" style="display:none">Set as Main</button>
    ${cb('negative', 'clear', 'Clear All')}
  </div>
</div>`;
}

async function initPage(page, state, configs, mainContent, mainUrl) {
  const barActions = {
    async startStop() {
      try {
        if (state.singboxRunning) {
          if (state.tproxyActive) await disableTproxy();
          await execService('sing-box', 'stop');
          const stopped = ['Sing\u2011Box'];
          if (state.autoupdaterServiceTempFlag) { await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop'); stopped.push('Autoupdater'); }
          else if (state.healthAutoupdaterServiceTempFlag) { await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop'); stopped.push('Health Autoupdater'); }
          notify('info', stopped.join(' & ') + ' stopped');
        } else {
          await execService('sing-box', 'start');
          if (state.tproxyConfigPresent) await enableTproxy();
          const started = ['Sing\u2011Box'];
          if (state.autoupdaterServiceTempFlag) { await execServiceLifecycle('singbox-ui-autoupdater-service', 'start'); started.push('Autoupdater'); }
          else if (state.healthAutoupdaterServiceTempFlag) { await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start'); started.push('Health Autoupdater'); }
          notify('info', started.join(' & ') + ' started');
        }
      } catch (e) { notify('error', 'Operation failed: ' + e.message); }
      finally { reloadPage(); }
    },
    async restart() {
      try {
        await execService('sing-box', 'restart');
        const restarted = ['Sing\u2011Box'];
        if (state.autoupdaterServiceTempFlag) { await execServiceLifecycle('singbox-ui-autoupdater-service', 'restart'); restarted.push('Autoupdater'); }
        else if (state.healthAutoupdaterServiceTempFlag) { await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart'); restarted.push('Health Autoupdater'); }
        notify('info', restarted.join(' & ') + ' restarted');
      } catch (e) { notify('error', 'Restart failed: ' + e.message); }
      finally { reloadPage(); }
    },
    dashboard() { window.open('http://' + window.location.hostname + ':9090/ui/', '_blank'); },
    async toggleAutoupdater() {
      try {
        if (state.autoupdaterEnabled) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
          await setUciOption('autoupdater_service_state', 'write', false);
          notify('info', 'Autoupdater stopped');
        } else {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
          await setUciOption('health_autoupdater_service_state', 'write', false);
          await setUciOption('autoupdater_service_state', 'write', true);
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
          notify('info', 'Autoupdater started');
        }
      } catch (e) { notify('error', 'Toggle failed: ' + e.message); }
      finally { reloadPage(); }
    },
    async toggleHealthAutoupdater() {
      try {
        if (state.healthAutoupdaterEnabled) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
          await setUciOption('health_autoupdater_service_state', 'write', false);
          notify('info', 'Health Autoupdater stopped');
        } else {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
          await setUciOption('autoupdater_service_state', 'write', false);
          await setUciOption('health_autoupdater_service_state', 'write', true);
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
          notify('info', 'Health Autoupdater started');
        }
      } catch (e) { notify('error', 'Toggle failed: ' + e.message); }
      finally { reloadPage(); }
    },
    async toggleMemdoc() {
      try {
        if (state.memdocEnabled) { await execServiceLifecycle('singbox-ui-memdoc-service', 'stop'); notify('info', 'Memdoc stopped'); }
        else { await execServiceLifecycle('singbox-ui-memdoc-service', 'start'); notify('info', 'Memdoc started'); }
      } catch (e) { notify('error', 'Toggle failed: ' + e.message); }
      finally { reloadPage(); }
    }
  };

  page.querySelectorAll('button[data-action]').forEach(btn => {
    const fn = barActions[btn.getAttribute('data-action')];
    if (fn) btn.onclick = () => { if (fn.constructor.name === 'AsyncFunction') fn().catch(() => {}); else fn(); };
  });

  let currentConfig = configs[0];
  const urlEl = page.querySelector('#singbox-ui-url');
  const selectEl = page.querySelector('#singbox-ui-config-select');
  const setMainBtn = page.querySelector('#singbox-ui-set-main-btn');
  if (urlEl) urlEl.value = mainUrl || '';

  const configActions = {
    saveUrl: async () => {
      const url = (urlEl && urlEl.value || '').trim();
      if (!url) return notify('error', 'URL empty');
      if (!isValidUrl(url)) return notify('error', 'Invalid URL');
      await saveFile('/etc/sing-box/url_' + currentConfig.name, url, 'URL saved');
      try {
        const r = await fs.exec('/usr/bin/singbox-ui/singbox-ui-updater',
          ['/etc/sing-box/url_' + currentConfig.name, '/etc/sing-box/' + currentConfig.name]);
        if (r.code === 2) notify('info', 'No changes detected');
        else if (r.code !== 0) notify('error', r.stderr || r.stdout || 'Unknown');
        else {
          if (currentConfig.name === 'config.json') await execService('sing-box', 'reload');
          notify('info', currentConfig.name === 'config.json' ? 'Main config reloaded' : 'Updated ' + currentConfig.label);
        }
      } catch (e) { notify('error', 'Update failed: ' + e.message); }
      reloadPage();
    },
    update: async () => {
      try {
        const r = await fs.exec('/usr/bin/singbox-ui/singbox-ui-updater',
          ['/etc/sing-box/url_' + currentConfig.name, '/etc/sing-box/' + currentConfig.name]);
        if (r.code === 2) return notify('info', 'No changes detected');
        if (r.code !== 0) return notify('error', r.stderr || r.stdout || 'Unknown');
        if (currentConfig.name === 'config.json') await execService('sing-box', 'reload');
        notify('info', currentConfig.name === 'config.json' ? 'Main config reloaded' : 'Updated ' + currentConfig.label);
      } catch (e) { notify('error', 'Update failed: ' + e.message); }
      finally { reloadPage(); }
    },
    format: async () => {
      const ed = window.singboxEditor;
      if (!ed) return notify('error', 'Editor not ready');
      const val = ed.getValue();
      if (!val || !val.trim()) return notify('info', 'Nothing to format');
      const formatted = await formatConfigWithSingBox(val);
      if (formatted != null) { ed.setValue(formatted, -1); ed.clearSelection(); notify('info', 'Formatted'); }
    },
    save: async () => {
      const ed = window.singboxEditor;
      if (!ed) return;
      const val = ed.getValue();
      if (!val) return notify('error', 'Config is empty');
      if (!(await isValidConfigFile(val))) return;
      await saveFile('/etc/sing-box/' + currentConfig.name, val, 'Config saved');
      if (currentConfig.name === 'config.json') { await execService('sing-box', 'reload'); notify('info', 'Sing\u2011Box reloaded'); }
      reloadPage();
    },
    setAsMain: async () => {
      if (currentConfig.name === 'config.json') return;
      try {
        const [nc, no, nu, ou] = await Promise.all([
          loadFile('/etc/sing-box/' + currentConfig.name), loadFile('/etc/sing-box/config.json'),
          loadFile('/etc/sing-box/url_' + currentConfig.name), loadFile('/etc/sing-box/url_config.json')
        ]);
        await saveFile('/etc/sing-box/config.json', nc, 'Main config set');
        await saveFile('/etc/sing-box/' + currentConfig.name, no, 'Backup config updated');
        await saveFile('/etc/sing-box/url_config.json', nu, 'Main URL set');
        await saveFile('/etc/sing-box/url_' + currentConfig.name, ou, 'Backup URL set');
        await execService('sing-box', 'reload');
        notify('info', currentConfig.label + ' is now main');
      } catch (e) { notify('error', 'Failed to set main: ' + e.message); }
      finally { reloadPage(); }
    },
    clear: async () => {
      try {
        await saveFile('/etc/sing-box/' + currentConfig.name, '{}', 'Config cleared');
        await saveFile('/etc/sing-box/url_' + currentConfig.name, '', 'URL cleared');
        if (currentConfig.name === 'config.json') {
          if (await isTproxyTablePresent()) await disableTproxy();
          await execService('sing-box', 'stop');
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
          notify('info', 'Services stopped');
        }
      } catch (e) { notify('error', 'Clear failed: ' + e.message); }
      finally { reloadPage(); }
    }
  };

  page.querySelectorAll('button[data-config-action]').forEach(btn => {
    const fn = configActions[btn.getAttribute('data-config-action')];
    if (fn) btn.onclick = () => { if (fn.constructor.name === 'AsyncFunction') fn().catch(() => {}); else fn(); };
  });

  if (selectEl) selectEl.addEventListener('change', async () => {
    const config = configs.find(c => c.name === selectEl.value);
    if (!config) return;
    currentConfig = config;
    const [content, url] = await Promise.all([
      loadFile('/etc/sing-box/' + config.name),
      loadFile('/etc/sing-box/url_' + config.name)
    ]);
    if (window.singboxEditor) { window.singboxEditor.setValue(content || '', -1); window.singboxEditor.clearSelection(); }
    if (urlEl) urlEl.value = url || '';
    if (setMainBtn) setMainBtn.style.display = config.name === 'config.json' ? 'none' : 'inline-block';
  });

  const aceEl = page.querySelector('#singbox-ui-ace');
  if (!aceEl) return;
  await loadScript('/luci-static/resources/view/singbox-ui/ace/ace.js');
  await loadScript('/luci-static/resources/view/singbox-ui/ace/ext-language_tools.js');
  ace.config.set('basePath', '/luci-static/resources/view/singbox-ui/ace/');
  ace.config.set('workerPath', '/luci-static/resources/view/singbox-ui/ace/');
  editor = ace.edit(aceEl);
  editor.setTheme('ace/theme/tomorrow_night_bright');
  editor.session.setMode('ace/mode/json5');
  editor.setValue(mainContent || '', -1);
  editor.clearSelection();
  editor.session.setUseWorker(true);
  editor.setOptions({ fontSize: '13px', showPrintMargin: false, wrap: true, highlightActiveLine: true, behavioursEnabled: true, showFoldWidgets: true, foldStyle: 'markbegin', enableBasicAutocompletion: true, enableLiveAutocompletion: true, enableSnippets: false });
  window.singboxEditor = editor;
}

// === Main View ============================================================

return view.extend({
  handleSave: null,
  handleSaveApply: null,
  handleReset: null,

  async render() {
    const configs = [
      { name: 'config.json', label: 'Main Config' },
      { name: 'config2.json', label: 'Backup Config #1' },
      { name: 'config3.json', label: 'Backup Config #2' }
    ];

    const [
      singboxStatus,
      healthAutoupdaterServiceEnabled,
      autoupdaterServiceEnabled,
      memdocServiceEnabled,
      versions,
      configContent,
      healthAutoupdaterServiceTempFlag,
      autoupdaterServiceTempFlag,
      tproxyConfigPresent,
      mainConfigUrl,
      mainContent,
      mainUrl
    ] = await Promise.all([
      execService('sing-box', 'status'),
      isServiceActive('singbox-ui-health-autoupdater-service'),
      isServiceActive('singbox-ui-autoupdater-service'),
      isServiceActive('singbox-ui-memdoc-service'),
      getPackageVersions(),
      loadFile('/etc/sing-box/config.json'),
      setUciOption('health_autoupdater_service_state', 'read', 'state'),
      setUciOption('autoupdater_service_state', 'read', 'state'),
      isTproxyConfigPresent(),
      loadFile('/etc/sing-box/url_config.json'),
      loadFile('/etc/sing-box/config.json'),
      loadFile('/etc/sing-box/url_config.json')
    ]);

    const tproxyActive = tproxyConfigPresent || await isTproxyTablePresent();
    const isInitialConfigValid = await isValidConfigFile(configContent.trim());

    const state = {
      versions,
      singboxStatus,
      singboxRunning: singboxStatus === 'running',
      isInitialConfigValid,
      tproxyConfigPresent,
      tproxyActive,
      mainConfigHasUrl: isValidUrl(mainConfigUrl.trim()),
      healthAutoupdaterServiceTempFlag,
      autoupdaterServiceTempFlag,
      autoupdaterEnabled: autoupdaterServiceEnabled,
      healthAutoupdaterEnabled: healthAutoupdaterServiceEnabled,
      memdocEnabled: memdocServiceEnabled
    };

    const page = document.createElement('div');
    page.className = 'sbox-page';
    page.innerHTML = buildPageCss() + buildPageHtml(state, configs);

    setTimeout(() => initPage(page, state, configs, mainContent, mainUrl).catch(e => {
      console.error('[singbox-ui] initPage error:', e);
    }), 50);

    return page;
  }
});
