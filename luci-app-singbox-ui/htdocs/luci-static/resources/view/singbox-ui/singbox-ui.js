'use strict';
'require view';
'require form';
'require ui';
'require fs';

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

async function execServiceLifecycle(name, action) {
  if (action === 'stop') {
    fs.exec(`/etc/init.d/${name}`, 'disable');
    fs.exec(`/etc/init.d/${name}`, 'stop');
  } else if (action === 'start') {
    fs.exec(`/etc/init.d/${name}`, 'enable');
    fs.exec(`/etc/init.d/${name}`, 'start');
  } else if (action === 'restart') {
    fs.exec(`/etc/init.d/${name}`, 'restart');
    fs.exec(`/etc/init.d/${name}`, 'enable');
  }
}

async function isValidConfigFile(content) {
  const tmpPath = '/tmp/singbox-config.json';
  try {
    await fs.write(tmpPath, content);
  } catch (e) {
    notify('error', 'Failed to write temp config: ' + e.message);
    return false;
  }
  var result = false;
  try {
    const r = await fs.exec("/usr/bin/sing-box", ["check", "-c", tmpPath]);
    if (r.code === 0) {
      result = true;
    } else {
      var errorMsg = r.stderr.trim();
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

function loadScript(src) {
  return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = src;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
  });
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

async function getAutoupdaterServiceEnabled() {
  try {
    await fs.stat('/tmp/singbox-ui-autoupdater-service-enabled');
    return true;
  } catch {
    return false;
  }
}

async function setAutoupdaterServiceEnabled(enabled) {
  try {
    if (enabled) {
      await fs.write('/tmp/singbox-ui-autoupdater-service-enabled', '1');
    } else {
      try {
        await fs.remove('/tmp/singbox-ui-autoupdater-service-enabled');
      } catch (e) {
        if (e.name !== 'NotFoundError') {
          throw e;
        }
      }
    }
  } catch (e) {
    notify('error', 'Failed to update autoupdater enabled state: ' + (e.message || e.toString()));
  }
}

async function getHealthAutoupdaterServiceEnabled() {
    try {
      await fs.stat('/tmp/singbox-ui-health-autoupdater-service-enabled');
      return true;
    } catch {
      return false;
    }
}
  
async function setHealthAutoupdaterServiceEnabled(enabled) {
    try {
      if (enabled) {
        await fs.write('/tmp/singbox-ui-health-autoupdater-service-enabled', '1');
      } else {
        try {
          await fs.remove('/tmp/singbox-ui-health-autoupdater-service-enabled');
        } catch (e) {
          if (e.name !== 'NotFoundError') {
            throw e;
          }
        }
      }
    } catch (e) {
      notify('error', 'Failed to update health autoupdater enabled state: ' + (e.message || e.toString()));
    }
}

async function createServiceButton(section, sbStatus) {
    const configPath = `/etc/sing-box/config.json`;
    const configContent = (await loadFile(configPath)).trim();
    const isInitialConfigValid = await isValidConfigFile(configContent);
    const healthAutoupdaterServiceEnabled = await getHealthAutoupdaterServiceEnabled();
    const sbRunning = (sbStatus === 'running');
 
    const label = sbRunning 
      ? `Stop${healthAutoupdaterServiceEnabled ? ' All' : ''}` 
      : `Start${healthAutoupdaterServiceEnabled ? ' All' : ''}`;
  
    const btn = section.taboption(
      'service', form.Button,
      'svc_toggle_all',
      label
    );
  
    btn.inputstyle = sbRunning ? 'remove' : 'apply';
    btn.readonly = !isInitialConfigValid;
    btn.title = sbRunning 
      ? `Stop Sing‑Box${healthAutoupdaterServiceEnabled ? ' and Health Updater' : ''}` 
      : `Start Sing‑Box${healthAutoupdaterServiceEnabled ? ' and Health Updater' : ''}`;
    btn.inputtitle = label;

    const action = sbRunning ? 'stop' : 'start';
    
    btn.onclick = async () => {
      try {
          if (action === 'stop') {
            await execService('sing-box', 'stop');
            if (healthAutoupdaterServiceEnabled) {
              await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
            }
            notify('info', healthAutoupdaterServiceEnabled ? 'Sing‑Box and Health Autoupdater services stopped' : 'Sing‑Box stopped');
          } else {
            await execService('sing-box', 'start');
            if (healthAutoupdaterServiceEnabled) {
              await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
            }
            notify('info', healthAutoupdaterServiceEnabled ? 'Sing‑Box and Health Autoupdater services started' : 'Sing‑Box started');
          }
      } catch (e) {
          notify('error', 'Operation failed: ' + e.message);
      } finally {
          setTimeout(() => location.reload(), 700);
      }
    };

    if (sbRunning) {
      const restartBtn = section.taboption(
        'service', form.Button,
        'svc_restart',
        healthAutoupdaterServiceEnabled ? 'Restart All' : 'Restart'
      );
      restartBtn.inputstyle = 'reload';
      restartBtn.readonly = !isInitialConfigValid;
      restartBtn.title = healthAutoupdaterServiceEnabled 
        ? 'Restart Sing‑Box and Health Autoupdater services'
        : 'Restart Sing‑Box Service';
      restartBtn.inputtitle = healthAutoupdaterServiceEnabled ? 'Restart All' : 'Restart';
  
      restartBtn.onclick = async () => {
        try {
          await execService('sing-box', 'restart');
          if (healthAutoupdaterServiceEnabled) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart');
          }
          notify('info', healthAutoupdaterServiceEnabled ? 'Sing‑Box and Health Autoupdater services restarted' : 'Sing‑Box restarted');
        } catch (e) {
          notify('error', 'Restart failed: ' + e.message);
        } finally {
          setTimeout(() => location.reload(), 500);
        }
      };
    }
}

async function createToggleAutoupdaterServiceButton(section, tab, config) {
  if (config.name !== 'config.json') return;

  const autoupdaterStatus = await getServiceStatus('singbox-ui-autoupdater-service');

  const urlPath = `/etc/sing-box/url_${config.name}`;
  const urlContent = (await loadFile(urlPath)).trim();
  if (!isValidUrl(urlContent)) return;

  const btn = section.taboption(
    tab, form.Button,
    'toggle_autoupdater_service',
    'Autoupdater Service'
  );
  btn.inputstyle = autoupdaterStatus === 'running' ? 'negative' : 'positive';
  btn.title = 'Autoupdater Service';
  btn.inputtitle = autoupdaterStatus === 'running' ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (autoupdaterStatus === 'running') {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        await setAutoupdaterEnabled(false);
        notify('info', 'Autoupdater service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
        await setAutoupdaterEnabled(true);
        notify('info', 'Autoupdater service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };
}

async function createToggleHealthAutoupdaterServiceButton(section, tab, config) {
  if (config.name !== 'config.json') return;

  const healthAutoupdaterStatus = await getServiceStatus('singbox-ui-health-autoupdater-service');

  const urlPath = `/etc/sing-box/url_${config.name}`;
  const urlContent = (await loadFile(urlPath)).trim();
  if (!isValidUrl(urlContent)) return;

  const btn = section.taboption(
    tab, form.Button,
    'toggle_health_autoupdater_service',
    'Health Autoupdater Service'
  );
  btn.inputstyle = healthAutoupdaterStatus === 'running' ? 'negative' : 'positive';
  btn.title = 'Health Autoupdater Service';
  btn.inputtitle = healthAutoupdaterStatus === 'running' ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (healthAutoupdaterStatus === 'running') {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        await setHealthAutoupdaterEnabled(false);
        notify('info', 'Health Autoupdater service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
        await setHealthAutoupdaterEnabled(true);
        notify('info', 'Health Autoupdater service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };
}

async function createToggleMemdocServiceButton(section, tab) {
  const memdocStatus = await getServiceStatus('singbox-ui-memdoc-service'); 

  const btn = section.taboption(
    tab, form.Button,
    'toggle_memdoc_service',
    'Memdoc Service'
  );
  btn.inputstyle = memdocStatus === 'running' ? 'negative' : 'positive';
  btn.title = 'Memory leak Service';
  btn.inputtitle = memdocStatus === 'running' ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (memdocStatus === 'running') {
        await execServiceLifecycle('singbox-ui-memdoc-service', 'stop');
        await setMemdocEnabled(false);
        notify('info', 'Memory leak service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-memdoc-service', 'start');
        await setMemdocEnabled(true);
        notify('info', 'Memory leak service started');
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

async function initializeAceEditor(content, key) {
  await loadScript('/luci-static/resources/view/singbox-ui/ace/ace.js');

  await loadScript('/luci-static/resources/view/singbox-ui/ace/ext-language_tools.js');

ace.config.set('basePath', '/luci-static/resources/view/singbox-ui/ace/');
ace.config.set('workerPath', '/luci-static/resources/view/singbox-ui/ace/');

editor = ace.edit(key);

editor.setTheme("ace/theme/tomorrow_night_bright");
editor.session.setMode("ace/mode/json");
editor.setValue(content, -1);
editor.clearSelection();
editor.session.setUseWorker(true);

editor.setOptions({
    fontSize: "12px",
    showPrintMargin: false,
    wrap: true,
    highlightActiveLine: true,
    behavioursEnabled: true,
    showFoldWidgets: true,
    foldStyle: 'markbegin',
    enableBasicAutocompletion: true,
    enableLiveAutocompletion: true,
    enableSnippets: false
  });
}

async function createConfigEditor(section, tab, config, key) {
  const option = section.taboption(tab, form.DummyValue, key, config.label);
  option.description = 'Edit JSON configuration below';

  option.render = async function () {
    const container = E('div', { style: 'width: 100%; margin-bottom: 1em;' }, [
      E('div', {
        id: key,
        style: 'height: 600px; width: 100%; border: 1px solid #ccc;',
      }),
    ]);    

    initializeAceEditor(await loadFile(`/etc/sing-box/${config.name}`), key);
    
    return container;
  };
}

function createSaveConfigButton(section, tab, config, key) {
  const btn = section.taboption(tab, form.Button, `save_config_${config.name}`, 'Save Config');

  btn.inputstyle = 'positive';
  btn.title = `Save config`;
  btn.inputtitle = 'Save';

  btn.onclick = async () => {
    let editor = null;
    try {
      editor = ace.edit(key);
    } catch {
      notify('error', 'Editor is not initialized');
      return;
    }
    const val = editor.getValue();

    if (!val) return notify('error', 'Config is empty');
    if (!(await isValidConfigFile(val))) return;

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
    const url = getInputValueByKey(key);
    if (!url) return notify('error', 'URL empty');
    if (!isValidUrl(url)) return notify('error', 'Invalid URL');
    await saveFile(`/etc/sing-box/url_${config.name}`, url, 'URL saved');
    setTimeout(() => location.reload(), 800);
  };
}

async function createUpdateConfigButton(section, tab, config) {
    const urlPath = `/etc/sing-box/url_${config.name}`;
    const urlContent = (await loadFile(urlPath)).trim();
    if (!isValidUrl(urlContent)) return;
  
    const btn = section.taboption(tab, form.Button, `update_cfg_${config.name}`, 'Update Config');
    btn.inputstyle = 'reload';
    btn.title = `Fetch & update from URL`;
    btn.inputtitle = 'Update';
  
    btn.onclick = async () => {
      try {
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
        await execService('singbox-ui-autoupdater', 'disable');
        await execService('singbox-ui-autoupdater', 'stop');
        await setHuEnabled(false);
        notify('info', 'Health Updater stopped');
      }
    } catch (e) {
      notify('error', `Clear failed: ${e.message}`);
    } finally {
      setTimeout(() => location.reload(), 700);
    }
  };
}

async function createHolderConfigEditor(section, tab, config) {
  const editorKey = `editor_${config.name}`;
  await createConfigEditor(section, tab, config, editorKey);
  createSaveConfigButton(section, tab, config, editorKey);
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
    
    await createServiceButton(s, sbStatus);

    
 
    const configs = [
      { name: 'config.json', label: 'Main Config' },
      { name: 'config2.json', label: 'Backup Config #1' },
      { name: 'config3.json', label: 'Backup Config #2' }
    ];

    for (const cfg of configs) {
        const tab = cfg.name === 'config.json' ? 'main_config' : `config_${cfg.name}`;
        s.tab(tab, cfg.label);
        createSubscribeEditor(s, tab, cfg);
        createSaveUrlButton(s, tab, cfg);
        await createUpdateConfigButton(s, tab, cfg);
        await createToggleAutoupdaterServiceButton(s, tab, healthAutoupdaterStatus, cfg);
        await createToggleHealthAutoupdaterServiceButton(s, tab, healthAutoupdaterStatus, cfg);
        await createToggleMemdocServiceButton(s, tab);
        await createHolderConfigEditor(s, tab, cfg);
        createSetAsMainConfigButton(s, tab, cfg);
        createClearConfigButton(s, tab, cfg);
    }

    return m.render();
  }
});
