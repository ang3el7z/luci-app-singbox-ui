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

async function getServiceIsEnabled(name) {
  try {
    await fs.stat(`/etc/init.d/${name}`);
  } catch {
    // службы нет — считаем выключенной
    return false;
  }

  // Проверка включена ли служба
  try {
    const { stdout } = await fs.exec(`/etc/init.d/${name}`, ['enabled']);
    return stdout.trim() === 'enabled';
  } catch {
    return false;
  }
}

async function createServiceButton(section, singboxManagmentTab, sbStatus, healthAutoupdaterServiceEnabled, autoupdaterServiceEnabled) {
  const configPath = `/etc/sing-box/config.json`;
  const configContent = (await loadFile(configPath)).trim();
  const isInitialConfigValid = await isValidConfigFile(configContent);

  const sbRunning = (sbStatus === 'running');

  // Формируем текст на кнопке в зависимости от того, что запущено
  function getRunningServicesNames() {
    const names = [];
    if (sbRunning) names.push('Sing‑Box');
    if (healthAutoupdaterServiceEnabled) names.push('Health Updater');
    if (autoupdaterServiceEnabled) names.push('Autoupdater');
    return names.join(' and ');
  }

  const runningServicesNames = getRunningServicesNames();

  const label = sbRunning 
    ? `Stop ${runningServicesNames || ''}`.trim()
    : `Start ${runningServicesNames || 'Sing‑Box and Autoupdater'}`.trim();

  const btn = section.taboption(
    singboxManagmentTab, form.Button,
    'svc_toggle_all',
    label
  );

  btn.inputstyle = sbRunning ? 'remove' : 'apply';
  btn.readonly = !isInitialConfigValid;
  btn.title = sbRunning 
    ? `Stop ${runningServicesNames || 'Sing‑Box and Updaters'}` 
    : `Start Sing‑Box and Autoupdater`;
  btn.inputtitle = label;

  const action = sbRunning ? 'stop' : 'start';

  btn.onclick = async () => {
    try {
      if (action === 'stop') {
        const stoppedServices = [];

        if (sbRunning) {
          await execService('sing-box', 'stop');
          stoppedServices.push('Sing‑Box');
        }

        if (healthAutoupdaterServiceEnabled) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
          stoppedServices.push('Health Updater');
        }

        if (autoupdaterServiceEnabled) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
          stoppedServices.push('Autoupdater');
        }

        notify('info', `${stoppedServices.join(' and ')} stopped`);

      } else {
        // Стартуем sing-box всегда
        await execService('sing-box', 'start');
        const startedServices = ['Sing‑Box'];

        // При старте — включаем и запускаем только autoupdater (health не стартуем)
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'enable');
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
        startedServices.push('Autoupdater');

        notify('info', `${startedServices.join(' and ')} started`);
      }
    } catch (e) {
      notify('error', 'Operation failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 700);
    }
  };

  if (sbRunning) {
    const restartBtn = section.taboption(
      singboxManagmentTab, form.Button,
      'svc_restart',
      'Restart'
    );

    // Если запущены updater-ы — добавим в название
    const restartServicesNames = [];
    restartServicesNames.push('Sing‑Box');
    if (healthAutoupdaterServiceEnabled) restartServicesNames.push('Health Updater');
    if (autoupdaterServiceEnabled) restartServicesNames.push('Autoupdater');

    restartBtn.inputstyle = 'reload';
    restartBtn.readonly = !isInitialConfigValid;
    restartBtn.title = `Restart ${restartServicesNames.join(' and ')}`;
    restartBtn.inputtitle = `Restart ${restartServicesNames.join(' and ')}`;

    restartBtn.onclick = async () => {
      try {
        const restartedServices = [];

        await execService('sing-box', 'restart');
        restartedServices.push('Sing‑Box');

        if (healthAutoupdaterServiceEnabled) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart');
          restartedServices.push('Health Updater');
        }

        if (autoupdaterServiceEnabled) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'restart');
          restartedServices.push('Autoupdater');
        }

        notify('info', `${restartedServices.join(' and ')} restarted`);
      } catch (e) {
        notify('error', 'Restart failed: ' + e.message);
      } finally {
        setTimeout(() => location.reload(), 500);
      }
    };
  }
}

async function createToggleAutoupdaterServiceButton(section, serviceManagementTab, config, autoupdaterEnabled, healthAutoupdaterEnabled) {
  if (healthAutoupdaterEnabled) return;

  const urlPath = `/etc/sing-box/url_${config.name}`;
  const urlContent = (await loadFile(urlPath)).trim();
  if (!isValidUrl(urlContent)) return;

  const btn = section.taboption(
    serviceManagementTab, form.Button,
    'toggle_autoupdater_service',
    'Autoupdater Service'
  );
  btn.inputstyle = autoupdaterEnabled ? 'negative' : 'positive';
  btn.title = 'Autoupdater Service';
  btn.description = 'Automatically updates the main config every 60 minutes and reloads Sing‑Box if changes are detected.';
  btn.inputtitle = autoupdaterEnabled ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (autoupdaterEnabled) {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        notify('info', 'Autoupdater service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
        notify('info', 'Autoupdater service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };
}

async function createToggleHealthAutoupdaterServiceButton(section, serviceManagementTab, config, healthAutoupdaterEnabled, autoupdaterEnabled) {
  if (autoupdaterEnabled) return;

  const urlPath = `/etc/sing-box/url_${config.name}`;
  const urlContent = (await loadFile(urlPath)).trim();
  if (!isValidUrl(urlContent)) return;

  const btn = section.taboption(
    serviceManagementTab, form.Button,
    'toggle_health_autoupdater_service',
    'Health Autoupdater Service'
  );
  btn.inputstyle = healthAutoupdaterEnabled ? 'negative' : 'positive';
  btn.title = 'Health Autoupdater Service';
  btn.description = 'Checks server health every 90 seconds. After 60 successful checks, updates config and reloads Sing‑Box. If the server goes down, stops Sing‑Box; when back online, restores config and restarts the service.';
  btn.inputtitle = healthAutoupdaterEnabled ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (healthAutoupdaterEnabled) {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        notify('info', 'Health Autoupdater service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
        notify('info', 'Health Autoupdater service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };
}

async function createToggleMemdocServiceButton(section, serviceManagementTab, memdocEnabled) {
  const btn = section.taboption(
    serviceManagementTab, form.Button,
    'toggle_memdoc_service',
    'Memdoc Service'
  );
  btn.inputstyle = memdocEnabled ? 'negative' : 'positive';
  btn.title = 'Memory leak Service';
  btn.description = 'Checks memory usage every 10 seconds. If memory usage exceeds 15 MB, restarts Sing‑Box.';
  btn.inputtitle = memdocEnabled ? 'Stop Service' : 'Start Service';

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (memdocEnabled) {
        await execServiceLifecycle('singbox-ui-memdoc-service', 'stop');
        notify('info', 'Memory leak service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-memdoc-service', 'start');
        notify('info', 'Memory leak service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      setTimeout(() => location.reload(), 500);
    }
  };  
}

function createDashboardButton(section, singboxManagmentTab, status) {
  if (status !== 'running') return;

  const btn = section.taboption(singboxManagmentTab, form.Button, 'dashboard', 'Dashboard');
  btn.inputstyle = 'apply';
  btn.title = 'Open Sing‑Box Web UI';
  btn.inputtitle = 'Dashboard';

  btn.onclick = () => window.open('http://192.168.1.1:9090/ui/', '_blank');
}

function createServiceStatusDisplay(section,singboxManagmentTab, status) {
  const dv = section.taboption(singboxManagmentTab, form.DummyValue, 'service_status', 'Service Status');
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

// === Components ============================================

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

function createSubscribeEditor(section, configTab, config) {
  const key = `url_${config.name}`;
  const fi = section.taboption(configTab, form.Value, key, 'Subscription URL');
  fi.datatype = 'url';
  fi.placeholder = 'https://example.com/subscribe';
  fi.description = 'Valid subscription URL for auto-updates';
  fi.rmempty = false;
  fi.cfgvalue = () => loadFile(`/etc/sing-box/url_${config.name}`);
}

function createSaveUrlButton(section, configTab, config) {
  const key = `url_${config.name}`;
  const btn = section.taboption(configTab, form.Button, `save_url_${config.name}`, 'Save URL');
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

async function createUpdateConfigButton(section, configTab, config) {
    const urlPath = `/etc/sing-box/url_${config.name}`;
    const urlContent = (await loadFile(urlPath)).trim();
    if (!isValidUrl(urlContent)) return;
  
    const btn = section.taboption(configTab, form.Button, `update_cfg_${config.name}`, 'Update Config');
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

function createSetAsMainConfigButton(section, configTab, config) {
  if (config.name === 'config.json') return;

  const btn = section.taboption(configTab, form.Button, `set_main_${config.name}`, 'Set as Main');
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

function createClearConfigButton(section, configTab, config) {
  const btn = section.taboption(configTab, form.Button, `clear_config_${config.name}`, 'Clear All');
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

// === Components view ============================================================

async function createHolderConfigEditorViews(section, configTab, config) {
    const editorKey = `editor_${config.name}`;
    await createConfigEditor(section, configTab, config, editorKey);
    createSaveConfigButton(section, configTab, config, editorKey);
}

// === Main View ============================================================

return view.extend({
  handleSave: null,
  handleSaveApply: null,
  handleReset: null,

  async render() {
    const map = new form.Map('singbox-ui', 'Sing‑Box UI Configuration');
    const section = map.section(form.TypedSection, 'main', 'ㅤ');
    section.anonymous = true;

    // getServiceStatus
    const sbStatus = await getServiceStatus('sing-box');

    // getServiceIsEnabled
    const healthAutoupdaterServiceEnabled = await getServiceIsEnabled('singbox-ui-health-autoupdater-service');
    const autoupdaterServiceEnabled = await getServiceIsEnabled('singbox-ui-autoupdater-service');
    const memdocServiceEnabled = await getServiceIsEnabled('singbox-ui-memdoc-service');
    
    //Singbox Management Tab
    const singboxManagmentTab = 'singbox-management'
    section.tab(singboxManagmentTab, 'Singbox');

    createServiceStatusDisplay(section, singboxManagmentTab,sbStatus);
    createDashboardButton(section, singboxManagmentTab, sbStatus);
    await createServiceButton(section, singboxManagmentTab, sbStatus, healthAutoupdaterServiceEnabled, autoupdaterServiceEnabled);
 
    //Configs Management Tab
    const configs = [
      { name: 'config.json', label: 'Main Config' },
      { name: 'config2.json', label: 'Backup Config #1' },
      { name: 'config3.json', label: 'Backup Config #2' }
    ];

    for (const config of configs) {
        const configTab = config.name === 'config.json' ? 'main_config' : `config_${config.name}`;
        section.tab(configTab, config.label);

        createSubscribeEditor(section, configTab, config);
        createSaveUrlButton(section, configTab, config);
        await createUpdateConfigButton(section, configTab, config);
        await createHolderConfigEditorViews(section, configTab, config);
        createSetAsMainConfigButton(section, configTab, config);
        createClearConfigButton(section, configTab, config);
    }

    //Service Management Tab
    const serviceManagementTab = 'service-management'
    section.tab(serviceManagementTab, 'Service');

    await createToggleAutoupdaterServiceButton(section, serviceManagementTab, configs[0], autoupdaterServiceEnabled, healthAutoupdaterServiceEnabled);
    await createToggleHealthAutoupdaterServiceButton(section, serviceManagementTab, configs[0], healthAutoupdaterServiceEnabled, autoupdaterServiceEnabled);
    await createToggleMemdocServiceButton(section, serviceManagementTab, memdocServiceEnabled);
    
    return map.render();
  }
});