'use strict';
'require view';
'require form';
'require ui';
'require fs';
'require uci';
'require rpc';

// Translation function - LuCI provides _() globally, fallback to original string
const _ = (typeof window !== 'undefined' && typeof window._ === 'function') 
  ? window._ 
  : ((str) => str);

// === Constants ============================================================

const UCI_CONFIG = 'singbox-ui';
const UCI_SECTION = 'main';
const CONFIG_DIR = '/etc/sing-box';
const BIN_DIR = '/usr/bin/singbox-ui';
const INIT_DIR = '/etc/init.d';
const MAIN_CONFIG = 'config.json';
const TEMP_CONFIG = '/tmp/singbox-config.json';

// === Global variables =====================================================

let editor = null;
const uciState = uci.createState();

// === Helpers ==============================================================

const isValidUrl = url => {
  try { new URL(url); return true; } catch { return false; }
};

const notify = (type, msg) => ui.addNotification(null, msg, type);

const getInputValueByKey = (key) => {
  const id = `widget.cbid.singbox-ui.main.${key}`;
  return document.querySelector(`#${CSS.escape(id)}`)?.value.trim();
};

/**
 * Load file content with error handling
 * @param {string} path - File path
 * @returns {Promise<string>} File content
 */
async function loadFile(path) {
  try {
    const content = await fs.read(path);
    return content || '';
  } catch (e) {
    console.warn(`Failed to read file "${path}":`, e);
    return '';
  }
}

/**
 * Save file content with error handling
 * @param {string} path - File path
 * @param {string} content - Content to write
 * @param {string} successMsg - Success message
 * @returns {Promise<boolean>} Success status
 */
async function saveFile(path, content, successMsg) {
  try {
    await fs.write(path, content);
    if (successMsg) {
      notify('info', successMsg);
    }
    return true;
  } catch (e) {
    notify('error', _('Failed to save file: %s').replace('%s', e.message));
    return false;
  }
}

/**
 * Execute service action
 * @param {string} name - Service name
 * @param {string} action - Action (start, stop, restart, reload, status)
 * @returns {Promise<string>} Service output or status
 */
async function execService(name, action) {
  const servicePath = `${INIT_DIR}/${name}`;
  try {
    const result = await fs.exec(servicePath, [action]);
    const output = result.stdout?.trim() || '';
    if (output) {
      console.log(`[${name}] ${action} output: ${output}`);
    }
    return output || action;
  } catch (err) {
    console.error(`[${name}] Error executing "${action}":`, err);
    return 'error';
  }
}

async function execServiceLifecycle(name, action) {
  const servicePath = `${INIT_DIR}/${name}`;

  const run = async (cmd) => {
    try {
      console.log(`[${name}] Running: ${cmd}`);
      const { stdout } = await fs.exec(servicePath, [cmd]);
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
    const { stdout } = await fs.exec(servicePath, ['status']);
    console.log(`[${name}] Final status: ${stdout.trim()}`);
  } catch (err) {
    console.error(`[${name}] Failed to get final status:`, err);
  }
}

/**
 * Validate Sing-Box configuration file
 * @param {string} content - JSON configuration content
 * @returns {Promise<boolean>} True if valid
 */
async function isValidConfigFile(content) {
  if (!content || !content.trim()) {
    notify('error', _('Configuration is empty'));
    return false;
  }

  try {
    await fs.write(TEMP_CONFIG, content);
  } catch (e) {
    notify('error', _('Failed to write temp config: %s').replace('%s', e.message));
    return false;
  }

  try {
    const result = await fs.exec('/usr/bin/sing-box', ['check', '-c', TEMP_CONFIG]);
    if (result.code === 0) {
      return true;
    } else {
      let errorMsg = result.stderr?.trim() || result.stdout?.trim() || _('Unknown error');
      // Remove temp path from error message for cleaner output
      if (errorMsg.includes(TEMP_CONFIG)) {
        errorMsg = errorMsg.substring(errorMsg.indexOf(TEMP_CONFIG) + TEMP_CONFIG.length + 1).trim();
      }
      notify('error', _('Config validation error: %s').replace('%s', errorMsg));
      return false;
    }
  } catch (e) {
    notify('error', _('Validation failed: %s').replace('%s', e.message));
    return false;
  } finally {
    try {
      await fs.remove(TEMP_CONFIG);
    } catch (e) {
      console.warn(`Failed to remove temp config: ${e.message}`);
    }
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

/**
 * Read UCI option value using LuCI UCI API
 * @param {string} option - Option name
 * @returns {Promise<boolean>} Option value as boolean
 */
async function getUciOption(option) {
  try {
    await uciState.load();
    const value = uciState.get(UCI_CONFIG, UCI_SECTION, option);
    return value === '1' || value === 'true' || value === true;
  } catch (e) {
    console.warn(`Failed to read UCI option "${option}":`, e);
    return false;
  }
}

/**
 * Write UCI option value using LuCI UCI API
 * @param {string} option - Option name
 * @param {boolean} value - Value to set
 * @returns {Promise<void>}
 */
async function setUciOption(option, value) {
  try {
    await uciState.load();
    uciState.set(UCI_CONFIG, UCI_SECTION, option, value ? '1' : '0');
    await uciState.save();
    await uciState.apply();
  } catch (e) {
    notify('error', _('Failed to set UCI option "%s": %s').replace('%s', option).replace('%s', e.message || e.toString()));
    throw e;
  }
}

function reloadPage(delay = 1000) {
  setTimeout(() => location.reload(), delay);
}

// === Controls =============================================================

async function isServiceActive(name) {
    const servicePath = `${INIT_DIR}/${name}`;
    console.log(`Checking if service "${name}" exists...`);
    try {
      await fs.stat(servicePath);
      console.log(`Service "${name}" found.`);
    } catch {
      console.log(`Service "${name}" not found.`);
      return false;
    }
  
    try {
      console.log(`Checking status of service "${name}"...`);
      const { stdout } = await fs.exec(servicePath, ['status']);
      const running = stdout.trim().includes('running');
      console.log(`Service "${name}" status output: "${stdout.trim()}"`);
      console.log(`Service "${name}" is ${running ? 'running' : 'not running'}.`);
      return running;
    } catch (e) {
      console.log(`Error while checking status of service "${name}":`, e);
      return false;
    }
}

async function createServiceButton(section, singboxManagmentTab, singboxStatus) {
    const configPath = `${CONFIG_DIR}/${MAIN_CONFIG}`;
    const configContent = (await loadFile(configPath)).trim();
    const isInitialConfigValid = await isValidConfigFile(configContent);
  
    const singboxRunning = (singboxStatus === 'running');
    const healthAutoupdaterServiceTempFlag = await getUciOption('health_autoupdater_service_state');
    const autoupdaterServiceTempFlag = await getUciOption('autoupdater_service_state');
  
    function getServiceNames() {
      const names = [_('Sing‑Box')];
  
      if (healthAutoupdaterServiceTempFlag) {
        names.push(_('Health Autoupdater'));
      } else if (autoupdaterServiceTempFlag) {
        names.push(_('Autoupdater'));
      }
  
      return names.join(_(' and '));
    }
  
    const label = singboxRunning 
      ? `${_('Stop')} ${getServiceNames()}`.trim()
      : `${_('Start')} ${getServiceNames()}`.trim();
  
    const btn = section.taboption(singboxManagmentTab, form.Button, 'svc_toggle_all', label);
  
    btn.inputstyle = singboxRunning ? 'remove' : 'apply';
    btn.readonly = !isInitialConfigValid;
    btn.title = label;
    btn.inputtitle = label;
  
    const action = singboxRunning ? 'stop' : 'start';
  
    btn.onclick = async () => {
      try {
        if (action === 'stop') {
          const stoppedServices = [];
  
          if (singboxRunning) {
            await execService('sing-box', 'stop');
            stoppedServices.push(_('Sing‑Box'));
          }
  
          if (autoupdaterServiceTempFlag ) {
            await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
            stoppedServices.push(_('Autoupdater'));
          } else if (healthAutoupdaterServiceTempFlag) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
            stoppedServices.push(_('Health Autoupdater'));
          }
  
          notify('info', `${stoppedServices.join(_(' and '))} ${_('stopped')}`);
        } else {
          const startedServices = [];
  
          await execService('sing-box', 'start');
          startedServices.push(_('Sing‑Box'));
  
          if (autoupdaterServiceTempFlag ) {
            await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
            startedServices.push(_('Autoupdater'));
          } else if (healthAutoupdaterServiceTempFlag) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
            startedServices.push(_('Health Autoupdater'));
          }
  
          notify('info', `${startedServices.join(_(' and '))} ${_('started')}`);
        }
      } catch (e) {
        notify('error', _('Operation failed: %s').replace('%s', e.message));
      } finally {
        reloadPage();
      }
    };
  
    if (singboxRunning) {
      const restartBtn = section.taboption(singboxManagmentTab, form.Button, 'svc_restart', _('Restart'));
  
      const restartServicesNames = [_('Sing‑Box')];
      if (healthAutoupdaterServiceTempFlag) restartServicesNames.push(_('Health Autoupdater'));
      else if (autoupdaterServiceTempFlag) restartServicesNames.push(_('Autoupdater'));
  
      restartBtn.inputstyle = 'reload';
      restartBtn.readonly = !isInitialConfigValid;
      restartBtn.title = `${_('Restart')} ${restartServicesNames.join(_(' and '))}`;
      restartBtn.inputtitle = `${_('Restart')} ${restartServicesNames.join(_(' and '))}`;
  
      restartBtn.onclick = async () => {
        try {
          const restartedServices = [];
  
          await execService('sing-box', 'restart');
          restartedServices.push(_('Sing‑Box'));
  
          if (autoupdaterServiceTempFlag ) {
            await execServiceLifecycle('singbox-ui-autoupdater-service', 'restart');
            restartedServices.push(_('Autoupdater'));
          } else if (healthAutoupdaterServiceTempFlag) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart');
            restartedServices.push(_('Health Autoupdater'));
          }
  
          notify('info', `${restartedServices.join(_(' and '))} ${_('restarted')}`);
        } catch (e) {
          notify('error', _('Restart failed: %s').replace('%s', e.message));
        } finally {
          reloadPage()
        }
      };
    }
}

async function createToggleAutoupdaterServiceButton(section, serviceManagementTab, config, autoupdaterEnabled, healthAutoupdaterEnabled) {
  if (healthAutoupdaterEnabled) return;

  const urlPath = `${CONFIG_DIR}/url_${config.name}`;
  const urlContent = (await loadFile(urlPath)).trim();
  if (!isValidUrl(urlContent)) return;

  const btn = section.taboption(
    serviceManagementTab, form.Button,
    'toggle_autoupdater_service',
    _('Autoupdater Service')
  );
  btn.inputstyle = autoupdaterEnabled ? 'negative' : 'positive';
  btn.title = _('Autoupdater Service');
  btn.description = _('Automatically updates the main config every 60 minutes and reloads Sing‑Box if changes are detected.');
  btn.inputtitle = autoupdaterEnabled ? _('Stop Service') : _('Start Service');

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (autoupdaterEnabled) {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        await setUciOption('autoupdater_service_state', false);
        notify('info', _('Autoupdater service stopped'));
      } else {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        await setUciOption('health_autoupdater_service_state', false);

        await setUciOption('autoupdater_service_state', true);
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');

        notify('info', _('Autoupdater service started'));
      }
    } catch (e) {
      notify('error', _('Toggle failed: %s').replace('%s', e.message));
    } finally {
      reloadPage()
    }
  };
}

async function createToggleHealthAutoupdaterServiceButton(section, serviceManagementTab, config, healthAutoupdaterEnabled, autoupdaterEnabled) {
  if (autoupdaterEnabled) return;

  const urlPath = `${CONFIG_DIR}/url_${config.name}`;
  const urlContent = (await loadFile(urlPath)).trim();
  if (!isValidUrl(urlContent)) return;

  const btn = section.taboption(
    serviceManagementTab, form.Button,
    'toggle_health_autoupdater_service',
    _('Health Autoupdater Service')
  );
  btn.inputstyle = healthAutoupdaterEnabled ? 'negative' : 'positive';
  btn.title = _('Health Autoupdater Service');
  btn.description = _('Checks server health every 90 seconds. After 60 successful checks, updates config and reloads Sing‑Box. If the server goes down, stops Sing‑Box; when back online, restores config and restarts the service.');
  btn.inputtitle = healthAutoupdaterEnabled ? _('Stop Service') : _('Start Service');

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (healthAutoupdaterEnabled) {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        await setUciOption('health_autoupdater_service_state', false);
        notify('info', _('Health Autoupdater service stopped'));
      } else {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        await setUciOption('autoupdater_service_state', false);
 
        await setUciOption('health_autoupdater_service_state', true);
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');

        notify('info', _('Health Autoupdater service started'));
      }
    } catch (e) {
      notify('error', _('Toggle failed: %s').replace('%s', e.message));
    } finally {
      reloadPage()
    }
  };
}

async function createToggleMemdocServiceButton(section, serviceManagementTab, memdocEnabled) {
  const btn = section.taboption(
    serviceManagementTab, form.Button,
    'toggle_memdoc_service',
    _('Memdoc Service')
  );
  btn.inputstyle = memdocEnabled ? 'negative' : 'positive';
  btn.title = _('Memory leak Service');
  btn.description = _('Checks memory usage every 10 seconds. If memory usage exceeds 15 MB, restarts Sing‑Box.');
  btn.inputtitle = memdocEnabled ? _('Stop Service') : _('Start Service');

  btn.onclick = async () => {
    btn.inputstyle = 'loading';
    try {
      if (memdocEnabled) {
        await execServiceLifecycle('singbox-ui-memdoc-service', 'stop');
        notify('info', _('Memory leak service stopped'));
      } else {
        await execServiceLifecycle('singbox-ui-memdoc-service', 'start');
        notify('info', _('Memory leak service started'));
      }
    } catch (e) {
      notify('error', _('Toggle failed: %s').replace('%s', e.message));
    } finally {
      reloadPage()
    }
  };  
}

function createDashboardButton(section, singboxManagmentTab, singboxStatus) {
  if (singboxStatus !== 'running') return;

  const btn = section.taboption(singboxManagmentTab, form.Button, 'dashboard', _('Dashboard'));
  btn.inputstyle = 'apply';
  btn.title = _('Open Sing‑Box Web UI');
  btn.inputtitle = _('Dashboard');

  btn.onclick = () => {
    const routerHost = window.location.hostname;
    const dashboardUrl = `http://${routerHost}:9090/ui/`;
    window.open(dashboardUrl, '_blank');
  };
}

function createServiceStatusDisplay(section,singboxManagmentTab, singboxStatus) {
  const dv = section.taboption(singboxManagmentTab, form.DummyValue, 'service_status', _('Service Status'));
  dv.rawhtml = true;
  dv.cfgvalue = () => {
    const col = { running: 'green', inactive: 'orange', error: 'red' };
    const txt = singboxStatus === 'running' ? _('Running')
              : singboxStatus === 'inactive' ? _('Inactive')
              : singboxStatus === 'error' ? _('Error')
              : singboxStatus;
    return `<span style="color:${col[singboxStatus]||'orange'};font-weight:bold">${txt}</span>`;
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
  editor.session.setMode("ace/mode/json5");
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
  option.description = _('Edit JSON configuration below');

  option.render = async function () {
    const container = E('div', { style: 'width: 100%; margin-bottom: 1em;' }, [
      E('div', {
        id: key,
        style: 'height: 600px; width: 100%; border: 1px solid #ccc;',
      }),
    ]);
    const configPath = `${CONFIG_DIR}/${config.name}`;
    initializeAceEditor(await loadFile(configPath), key);
    return container;
  };
}

function createSaveConfigButton(section, tab, config, key) {
  const btn = section.taboption(tab, form.Button, `save_config_${config.name}`, _('Save Config'));

  btn.inputstyle = 'positive';
  btn.title = _('Save config');
  btn.inputtitle = _('Save');

  btn.onclick = async () => {
    let editor = null;
    try {
      editor = ace.edit(key);
    } catch {
      notify('error', _('Editor is not initialized'));
      return;
    }
    const val = editor.getValue();

    if (!val || !val.trim()) {
      notify('error', _('Configuration is empty'));
      return;
    }
    
    if (!(await isValidConfigFile(val))) {
      return;
    }

    const configPath = `${CONFIG_DIR}/${config.name}`;
    if (await saveFile(configPath, val, _('Config saved'))) {
      if (config.name === MAIN_CONFIG) {
        await execService('sing-box', 'reload');
        notify('info', _('Sing‑Box reloaded'));
      }
      reloadPage();
    }
  };
}

function createSubscribeEditor(section, configTab, config) {
  const key = `url_${config.name}`;
  const urlPath = `${CONFIG_DIR}/url_${config.name}`;
  const fi = section.taboption(configTab, form.Value, key, _('Subscription URL'));
  fi.datatype = 'url';
  fi.placeholder = 'https://example.com/subscribe';
  fi.description = _('Valid subscription URL for auto-updates');
  fi.rmempty = false;
  fi.cfgvalue = () => loadFile(urlPath);
}

function createSaveUrlButton(section, configTab, config) {
  const key = `url_${config.name}`;
  const btn = section.taboption(configTab, form.Button, `save_url_${config.name}`, _('Save URL'));
  btn.inputstyle = 'positive';
  btn.title = _('Save subscription URL');
  btn.inputtitle = _('Save URL');

  btn.onclick = async () => {
    const url = getInputValueByKey(key);
    if (!url) {
      notify('error', _('URL is empty'));
      return;
    }
    if (!isValidUrl(url)) {
      notify('error', _('Invalid URL format'));
      return;
    }
    const urlPath = `${CONFIG_DIR}/url_${config.name}`;
    if (await saveFile(urlPath, url, _('URL saved'))) {
      reloadPage();
    }
  };
}

async function createUpdateConfigButton(section, configTab, config) {
    const urlPath = `${CONFIG_DIR}/url_${config.name}`;
    const urlContent = (await loadFile(urlPath)).trim();
    if (!isValidUrl(urlContent)) return;
  
    const btn = section.taboption(configTab, form.Button, `update_cfg_${config.name}`, _('Update Config'));
    btn.inputstyle = 'reload';
    btn.title = _('Fetch & update from URL');
    btn.inputtitle = _('Update');
  
    btn.onclick = async () => {
      try {
        const targetPath = `${CONFIG_DIR}/${config.name}`;
        const result = await fs.exec(
          `${BIN_DIR}/singbox-ui-updater`,
          [urlPath, targetPath]
        );
        
        if (result.code === 2) {
          notify('info', _('No changes detected'));
          reloadPage();
          return;
        }
        
        if (result.code !== 0) {
          const errorMsg = result.stderr?.trim() || result.stdout?.trim() || _('Unknown error');
          notify('error', _('Update failed: %s').replace('%s', errorMsg));
          reloadPage();
          return;
        }
        
        if (config.name === MAIN_CONFIG) {
          await execService('sing-box', 'reload');
          notify('info', _('Main config updated and reloaded'));
        } else {
          notify('info', _('%s updated').replace('%s', config.label));
        }
      } catch (e) {
        notify('error', _('Update failed: %s').replace('%s', e.message));
      } finally {
        reloadPage();
      }
    };
}

function createSetAsMainConfigButton(section, configTab, config) {
  if (config.name === MAIN_CONFIG) return;

  const btn = section.taboption(configTab, form.Button, `set_main_${config.name}`, _('Set as Main'));
  btn.inputstyle = 'apply';
  btn.title = _('Switch: %s to main config').replace('%s', config.label);
  btn.inputtitle = _('Set as Main');

  btn.onclick = async () => {
    try {
      const newConfigPath = `${CONFIG_DIR}/${config.name}`;
      const mainConfigPath = `${CONFIG_DIR}/${MAIN_CONFIG}`;
      const newUrlPath = `${CONFIG_DIR}/url_${config.name}`;
      const mainUrlPath = `${CONFIG_DIR}/url_${MAIN_CONFIG}`;
      
      const [newConfig, oldConfig, newUrl, oldUrl] = await Promise.all([
        loadFile(newConfigPath),
        loadFile(mainConfigPath),
        loadFile(newUrlPath),
        loadFile(mainUrlPath)
      ]);
      
      // Validate new config before switching
      if (!(await isValidConfigFile(newConfig))) {
        return;
      }
      
      await Promise.all([
        saveFile(mainConfigPath, newConfig, _('Main config set')),
        saveFile(newConfigPath, oldConfig, _('Backup config updated')),
        saveFile(mainUrlPath, newUrl, _('Main URL set')),
        saveFile(newUrlPath, oldUrl, _('Backup URL set'))
      ]);
      
      await execService('sing-box', 'reload');
      notify('info', _('%s is now main').replace('%s', config.label));
    } catch (e) {
      notify('error', _('Failed to set main: %s').replace('%s', e.message));
    } finally {
      reloadPage();
    }
  };
}

function createClearConfigButton(section, configTab, config) {
  const btn = section.taboption(configTab, form.Button, `clear_config_${config.name}`, _('Clear All'));
  btn.inputstyle = 'negative';
  btn.title = _('Clear config and URL');
  btn.inputtitle = _('Clear All');

  btn.onclick = async () => {
    try {
      const configPath = `${CONFIG_DIR}/${config.name}`;
      const urlPath = `${CONFIG_DIR}/url_${config.name}`;
      
      await Promise.all([
        saveFile(configPath, '{}', _('Config cleared')),
        saveFile(urlPath, '', _('URL cleared'))
      ]);
      
      if (config.name === MAIN_CONFIG) {
        await Promise.all([
          execService('sing-box', 'stop'),
          execServiceLifecycle('singbox-ui-autoupdater-service', 'stop'),
          execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop')
        ]);
        notify('info', _('Services stopped'));
      }
    } catch (e) {
      notify('error', _('Clear failed: %s').replace('%s', e.message));
    } finally {
      reloadPage();
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
    const map = new form.Map('singbox-ui', _('Sing‑Box UI Configuration'));
    const section = map.section(form.TypedSection, 'main', 'ㅤ');
    section.anonymous = true;

    // getServiceStatus
    const singboxStatus = await execService('sing-box', 'status');

    // isServiceActive
    const healthAutoupdaterServiceEnabled = await isServiceActive('singbox-ui-health-autoupdater-service');
    const autoupdaterServiceEnabled = await isServiceActive('singbox-ui-autoupdater-service');
    const memdocServiceEnabled = await isServiceActive('singbox-ui-memdoc-service');
    
    //Singbox Management Tab
    const singboxManagmentTab = 'singbox-management'
    section.tab(singboxManagmentTab, _('Singbox'));

    createServiceStatusDisplay(section, singboxManagmentTab,singboxStatus);
    createDashboardButton(section, singboxManagmentTab, singboxStatus);
    await createServiceButton(section, singboxManagmentTab, singboxStatus);
 
    //Configs Management Tab
    const configs = [
      { name: MAIN_CONFIG, label: _('Main Config') },
      { name: 'config2.json', label: _('Backup Config #1') },
      { name: 'config3.json', label: _('Backup Config #2') }
    ];

    for (const config of configs) {
        const configTab = config.name === MAIN_CONFIG ? 'main_config' : `config_${config.name}`;
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
    section.tab(serviceManagementTab, _('Services'));

    await createToggleAutoupdaterServiceButton(section, serviceManagementTab, configs[0], autoupdaterServiceEnabled, healthAutoupdaterServiceEnabled);
    await createToggleHealthAutoupdaterServiceButton(section, serviceManagementTab, configs[0], healthAutoupdaterServiceEnabled, autoupdaterServiceEnabled);
    await createToggleMemdocServiceButton(section, serviceManagementTab, memdocServiceEnabled);
    
    return map.render();
  }
});
