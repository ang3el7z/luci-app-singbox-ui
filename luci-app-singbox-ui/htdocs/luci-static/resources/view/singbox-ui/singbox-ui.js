'use strict';
'require view';
'require form';
'require ui';
'require fs';

// === Helpers ==============================================================

const isValidUrl = url => {
  try { new URL(url); return true; } catch { return false; }
};

const isValidJson = str => {
  try {
    JSON.parse(str);
    return !str.trim().startsWith('{}');
  } catch { return false; }
};

const notify = (type, msg) => ui.addNotification(null, msg, type);

const getValue = key => {
  const el = document.querySelector(`#${CSS.escape(key)}`);
  return el ? el.value.trim() : '';
};

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
  return fs.exec(`/etc/init.d/${name}`, [action]);
}

// === Service Status & Controls ============================================

async function getServiceStatus(name) {
  try {
    const r = await execService(name, 'status');
    return r.stdout.trim().toLowerCase();
  } catch {
    return 'error';
  }
}

function createServiceButton(section, action, status) {
  const shouldShow = (action === 'start' && status !== 'running') ||
    (['stop', 'restart'].includes(action) && status === 'running');
  if (!shouldShow) return;

  const btn = section.taboption(
    'service', form.Button,
    `svc_${action}`, action.charAt(0).toUpperCase() + action.slice(1)
  );
  btn.inputstyle = action === 'stop' ? 'remove'
                   : action === 'start' ? 'positive'
                   : 'apply';
  btn.title = `${action.charAt(0).toUpperCase() + action.slice(1)} Sing‑Box Service`;
  btn.inputtitle = action.charAt(0).toUpperCase() + action.slice(1);

  btn.onclick = async () => {
    try {
      await execService('sing-box', action);
      notify('info', `${action} successful`);
    } catch (e) {
      notify('error', `${action} failed: ${e.message}`);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };
}

function createServiceWithHealthUpdaterButton(section, sbStatus) {
    const running = (sbStatus === 'running');
  
    const btn = section.taboption(
      'service', form.Button,
      'svc_toggle_all',
      running ? 'Stop All' : 'Start All'
    );
  
    btn.inputstyle = running ? 'remove' : 'apply';
    btn.title = running 
      ? 'Stop Sing‑Box and Health Updater services' 
      : 'Start Sing‑Box and Health Updater services';
    btn.inputtitle = running ? 'Stop All' : 'Start All';
  
    btn.onclick = async () => {
      try {
        if (running) {
          await execService('sing-box', 'stop');
          await execService('singbox-ui-autoupdater', 'stop');
          await execService('singbox-ui-autoupdater', 'disable');
          notify('info', 'Both services stopped');
        } else {
          await execService('sing-box', 'start');
          await execService('singbox-ui-autoupdater', 'enable');
          await execService('singbox-ui-autoupdater', 'start');
          notify('info', 'Both services started');
        }
      } catch (e) {
        notify('error', 'Operation failed: ' + e.message);
      } finally {
        setTimeout(() => location.reload(), 700);
      }
    };
}

function createToggleHealthUpdaterButton(section, tab, huStatus, config) {
  if (config.name !== 'config.json') return;

  const btn = section.taboption(
    tab, form.Button,
    'toggle_health_updater',
    'Health Updater'
  );
  btn.inputstyle = huStatus === 'running' ? 'negative' : 'positive';
  btn.title = 'Control Health Updater service';
  btn.inputtitle = huStatus === 'running' ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (huStatus === 'running') {
        await execService('singbox-ui-autoupdater', 'disable');
        await execService('singbox-ui-autoupdater', 'stop');
        notify('info', 'Health Updater stopped');
      } else {
        await execService('singbox-ui-autoupdater', 'enable');
        await execService('singbox-ui-autoupdater', 'start');
        notify('info', 'Health Updater started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };
}

function createDashboardButton(section, status) {
  if (status !== 'running') return;

  const btn = section.taboption('service', form.Button, 'dashboard', 'Dashboard');
  btn.inputstyle = 'apply';
  btn.title = 'Open Sing‑Box Web UI';
  btn.inputtitle = 'Dashboard';

  btn.onclick = () => window.open('http://192.168.1.1:9090/ui/', '_blank');
}

function createServiceStatusDisplay(section, status) {
  const dv = section.taboption('service', form.DummyValue, 'service_status', 'Service Status');
  dv.rawhtml = true;
  dv.cfgvalue = () => {
    const col = { running: 'green', inactive: 'orange', error: 'red' };
    const txt = status === 'running' ? 'Running'
              : status === 'inactive' ? 'Inactive'
              : status === 'error' ? 'Error'
              : status;
    return `<span style="color:${col[status]||'orange'};font-weight:bold">${txt}</span>`;
  };
}

// === Config Editors & Buttons ============================================

function createConfigEditor(section, tab, config) {
  const key = `content_${config.name}`;
  const tv = section.taboption(tab, form.TextValue, key, config.label);
  tv.rows = 25;
  tv.wrap = 'off';
  tv.description = 'Paste JSON configuration here';
  tv.cfgvalue = () => loadFile(`/etc/sing-box/${config.name}`);
}

function createSaveConfigButton(section, tab, config) {
  const key = `content_${config.name}`;
  const btn = section.taboption(tab, form.Button, `save_config_${config.name}`, 'Save Config');
  btn.inputstyle = 'positive';
  btn.title = `Save config`;
  btn.inputtitle = 'Save';

  btn.onclick = async () => {
    const val = getValue(key);
    if (!val) return notify('error', 'Config is empty');
    if (!isValidJson(val)) return notify('error', 'Invalid JSON');
    await saveFile(`/etc/sing-box/${config.name}`, val, 'Config saved');
    if (config.name === 'config.json') {
      await execService('sing-box', 'reload');
      notify('info', 'Sing‑Box reloaded');
    }
    setTimeout(() => location.reload(), 800);
  };
}

function createSubscribeEditor(section, tab, config) {
  const key = `url_${config.name}`;
  const fi = section.taboption(tab, form.Value, key, 'Subscription URL');
  fi.datatype = 'url';
  fi.placeholder = 'https://example.com/subscribe';
  fi.description = 'Valid subscription URL for auto-updates';
  fi.rmempty = false;
  fi.cfgvalue = () => loadFile(`/etc/sing-box/url_${config.name}`);
}

function createSaveUrlButton(section, tab, config) {
  const key = `url_${config.name}`;
  const btn = section.taboption(tab, form.Button, `save_url_${config.name}`, 'Save URL');
  btn.inputstyle = 'positive';
  btn.title = `Save subscription URL`;
  btn.inputtitle = 'Save URL';

  btn.onclick = async () => {
    const url = getValue(key);
    if (!url) return notify('error', 'URL empty');
    if (!isValidUrl(url)) return notify('error', 'Invalid URL');
    await saveFile(`/etc/sing-box/url_${config.name}`, url, 'URL saved');
  };
}

function createUpdateConfigButton(section, tab, config) {
  const btn = section.taboption(tab, form.Button, `update_cfg_${config.name}`, 'Update Config');
  btn.inputstyle = 'reload';
  btn.title = `Fetch & update from URL`;
  btn.inputtitle = 'Update';

  btn.onclick = async () => {
    try {
      const url = (await loadFile(`/etc/sing-box/url_${config.name}`)).trim();
      if (!url) throw Error('URL is empty');
      const r = await fs.exec(
        '/usr/bin/singbox-ui/singbox-ui-updater',
        [`/etc/sing-box/url_${config.name}`, `/etc/sing-box/${config.name}`]
      );
      if (r.code === 2) return notify('info', 'No changes detected');
      if (r.code !== 0) throw new Error(r.stderr || r.stdout || 'Unknown');
      if (config.name === 'config.json') {
        await execService('sing-box', 'reload');
        notify('info', 'Main config reloaded');
      } else {
        notify('info', `Updated ${config.label}`);
      }
    } catch (e) {
      notify('error', 'Update failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 800);
    }
  };
}

function createSetAsMainConfigButton(section, tab, config) {
  if (config.name === 'config.json') return;

  const btn = section.taboption(tab, form.Button, `set_main_${config.name}`, 'Set as Main');
  btn.inputstyle = 'apply';
  btn.title = `Switch: ${config.label} to main config`;
  btn.inputtitle = 'Set as Main';

  btn.onclick = async () => {
    try {
      const [nc, no, nu, ou] = await Promise.all([
        loadFile(`/etc/sing-box/${config.name}`),
        loadFile('/etc/sing-box/config.json'),
        loadFile(`/etc/sing-box/url_${config.name}`),
        loadFile('/etc/sing-box/url_config.json')
      ]);
      await saveFile('/etc/sing-box/config.json', nc, 'Main config set');
      await saveFile(`/etc/sing-box/${config.name}`, no, 'Backup config updated');
      await saveFile('/etc/sing-box/url_config.json', nu, 'Main URL set');
      await saveFile(`/etc/sing-box/url_${config.name}`, ou, 'Backup URL set');
      await execService('sing-box', 'reload');
      notify('info', `${config.label} is now main`);
    } catch (e) {
      notify('error', `Failed to set main: ${e.message}`);
    } finally {
      setTimeout(() => location.reload(), 700);
    }
  };
}

function createClearConfigButton(section, tab, config) {
  const btn = section.taboption(tab, form.Button, `clear_config_${config.name}`, 'Clear All');
  btn.inputstyle = 'negative';
  btn.title = `Clear config and URL`;
  btn.inputtitle = 'Clear All';

  btn.onclick = async () => {
    try {
      await saveFile(`/etc/sing-box/${config.name}`, '{}', 'Config cleared');
      await saveFile(`/etc/sing-box/url_${config.name}`, '', 'URL cleared');
      if (config.name === 'config.json') {
        await execService('sing-box', 'stop');
        notify('info', 'Sing‑Box stopped');
      }
    } catch (e) {
      notify('error', `Clear failed: ${e.message}`);
    } finally {
      setTimeout(() => location.reload(), 700);
    }
  };
}

// === Main View ============================================================

return view.extend({
  handleSave: null,
  handleSaveApply: null,
  handleReset: null,

  async render() {
    const m = new form.Map('singbox-ui', 'Sing‑Box UI Configuration');
    const s = m.section(form.TypedSection, 'main', 'Control Panel');
    s.anonymous = true;
    s.tab('service', 'Service Management');

    const sbStatus = await getServiceStatus('sing-box');
    createServiceStatusDisplay(s, sbStatus);
    
    createDashboardButton(s, sbStatus);
    
    const healthUpdaterStatus = await getServiceStatus('singbox-ui-autoupdater');
    createServiceWithHealthUpdaterButton(s, sbStatus);

    ['start','stop','restart'].forEach(a => createServiceButton(s, a, sbStatus));

    const configs = [
      { name: 'config.json', label: 'Main Config' },
      { name: 'config2.json', label: 'Backup Config #1' },
      { name: 'config3.json', label: 'Backup Config #2' }
    ];

    configs.forEach(cfg => {
      const tab = cfg.name === 'config.json' ? 'main_config' : `config_${cfg.name}`;
      s.tab(tab, cfg.label);
      createSubscribeEditor(s, tab, cfg);
      createSaveUrlButton(s, tab, cfg);
      createUpdateConfigButton(s, tab, cfg);
      createToggleHealthUpdaterButton(s, tab, healthUpdaterStatus, cfg);
      createConfigEditor(s, tab, cfg);
      createSaveConfigButton(s, tab, cfg);
      createSetAsMainConfigButton(s, tab, cfg);
      createClearConfigButton(s, tab, cfg);
    });

    return m.render();
  }
});
