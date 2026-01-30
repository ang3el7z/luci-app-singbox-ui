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
const TPROXY_RULES = `define PROXY_FWMARK = 1
define BYPASS_MARK = 2
define RESERVED_IP = {
    0.0.0.0/8,
    10.0.0.0/8,
    100.64.0.0/10,
    127.0.0.0/8,
    169.254.0.0/16,
    172.16.0.0/12,
    192.168.0.0/16,
    192.0.0.0/24,
    192.0.2.0/24,
    198.18.0.0/15,
    198.51.100.0/24,
    203.0.113.0/24,
    224.0.0.0/4,
    240.0.0.0/4,
    255.255.255.255/32
}

table ip singbox {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        ip daddr $RESERVED_IP return
        meta mark $BYPASS_MARK return
        ip protocol tcp tproxy to 127.0.0.1:2080 meta mark set $PROXY_FWMARK
        ip protocol udp tproxy to 127.0.0.1:2080 meta mark set $PROXY_FWMARK
    }
}
`;

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

async function readLogs() {
  const args = ['-e', 'sing-box'];
  try {
    const { stdout } = await fs.exec('/sbin/logread', args);
    return stdout || '';
  } catch {
    try {
      const { stdout } = await fs.exec('logread', args);
      return stdout || '';
    } catch {
      return '';
    }
  }
}

async function execService(name, action) {
  try {
    const { stdout } = await fs.exec(`/etc/init.d/${name}`, [action]);
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

async function runIp(args) {
  try {
    return await fs.exec('/sbin/ip', args);
  } catch (e) {
    return await fs.exec('ip', args);
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

async function writeTproxyRulesFile() {
  try {
    await fs.write(TPROXY_RULE_FILE, TPROXY_RULES);
    return true;
  } catch (e) {
    notify('error', 'Failed to write TPROXY rules: ' + e.message);
    return false;
  }
}

async function setupTproxyRouting() {
  try {
    await runIp(['rule', 'add', 'fwmark', '1', 'table', '100']);
    await runIp(['route', 'add', 'local', '0.0.0.0/0', 'dev', 'lo', 'table', '100']);
  } catch (e) {
    console.warn('[tproxy] Failed to setup routing:', e);
  }
}

async function cleanupTproxyRouting() {
  try {
    await runIp(['rule', 'del', 'fwmark', '1', 'table', '100']);
    await runIp(['route', 'flush', 'table', '100']);
  } catch (e) {
    console.warn('[tproxy] Failed to cleanup routing:', e);
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
    const { stdout } = await fs.exec(path, ['status']);
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
      // Читаем через fs.exec
      const result = await fs.exec('/sbin/uci', ['get', `${config}.${section}.${option}`]);
      return result.stdout.trim() === '1';
    } catch {
      return false;
    }
  }

  if (mode === 'write') {
    try {
      const val = value ? '1' : '0';
      
      // Используем прямую команду uci
      await fs.exec('/sbin/uci', ['set', `${config}.${section}.${option}=${val}`]);
      await fs.exec('/sbin/uci', ['commit', config]);
    } catch (e) {
      notify('error', `Failed to set UCI option "${option}": ${e.message || e.toString()}`);
    }
  }
}

async function getUciValue(option, fallback = '') {
  const config = 'singbox-ui';
  const section = 'main';
  try {
    const result = await fs.exec('/sbin/uci', ['get', `${config}.${section}.${option}`]);
    return result.stdout.trim() || fallback;
  } catch {
    return fallback;
  }
}

async function setUciValue(option, value) {
  const config = 'singbox-ui';
  const section = 'main';
  try {
    await fs.exec('/sbin/uci', ['set', `${config}.${section}.${option}=${value}`]);
    await fs.exec('/sbin/uci', ['commit', config]);
  } catch (e) {
    notify('error', `Failed to set UCI value "${option}": ${e.message || e.toString()}`);
  }
}

async function getUciDump(config) {
  try {
    const { stdout } = await fs.exec('/sbin/uci', ['show', config]);
    return stdout || '';
  } catch {
    return '';
  }
}

function findUciSectionId(dump, type, key, value) {
  const escaped = value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`^firewall\\.@${type}\\[(\\d+)\\]\\.${key}='${escaped}'$`);
  const lines = dump.split('\n');
  for (const line of lines) {
    const match = line.match(re);
    if (match) return match[1];
  }
  return null;
}

async function ensureTunFirewallConfig() {
  const dump = await getUciDump('firewall');
  const zoneId = findUciSectionId(dump, 'zone', 'name', 'proxy');
  if (zoneId === null) {
    await fs.exec('/sbin/uci', ['add', 'firewall', 'zone']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].name=proxy']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].forward=REJECT']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].output=ACCEPT']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].input=ACCEPT']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].masq=1']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].mtu_fix=1']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].device=singtun0']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@zone[-1].family=ipv4']);
    await fs.exec('/sbin/uci', ['add_list', 'firewall.@zone[-1].network=singtun0']);
  }

  const fwdId = findUciSectionId(dump, 'forwarding', 'dest', 'proxy');
  if (fwdId === null) {
    await fs.exec('/sbin/uci', ['add', 'firewall', 'forwarding']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@forwarding[-1].dest=proxy']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@forwarding[-1].src=lan']);
    await fs.exec('/sbin/uci', ['set', 'firewall.@forwarding[-1].family=ipv4']);
  }

  await fs.exec('/sbin/uci', ['commit', 'firewall']);
}

async function removeTunFirewallConfig() {
  const dump = await getUciDump('firewall');
  const zoneId = findUciSectionId(dump, 'zone', 'name', 'proxy');
  if (zoneId !== null) {
    await fs.exec('/sbin/uci', ['delete', `firewall.@zone[${zoneId}]`]);
  }
  const fwdId = findUciSectionId(dump, 'forwarding', 'dest', 'proxy');
  if (fwdId !== null) {
    await fs.exec('/sbin/uci', ['delete', `firewall.@forwarding[${fwdId}]`]);
  }
  await fs.exec('/sbin/uci', ['commit', 'firewall']);
}

async function ensureTproxyFirewallInclude() {
  const section = 'singbox_tproxy';
  await fs.exec('/sbin/uci', ['set', `firewall.${section}=include`]);
  await fs.exec('/sbin/uci', ['set', `firewall.${section}.type=nftables`]);
  await fs.exec('/sbin/uci', ['set', `firewall.${section}.path=${TPROXY_RULE_FILE}`]);
  await fs.exec('/sbin/uci', ['set', `firewall.${section}.enabled=1`]);
  await fs.exec('/sbin/uci', ['commit', 'firewall']);
}

async function removeTproxyFirewallInclude() {
  const section = 'singbox_tproxy';
  await fs.exec('/sbin/uci', ['-q', 'delete', `firewall.${section}`]);
  await fs.exec('/sbin/uci', ['commit', 'firewall']);
}

async function enableTunMode() {
  await fs.exec('/sbin/uci', ['set', 'network.proxy=interface']);
  await fs.exec('/sbin/uci', ['set', 'network.proxy.proto=none']);
  await fs.exec('/sbin/uci', ['set', 'network.proxy.device=singtun0']);
  await fs.exec('/sbin/uci', ['set', 'network.proxy.defaultroute=0']);
  await fs.exec('/sbin/uci', ['set', 'network.proxy.delegate=0']);
  await fs.exec('/sbin/uci', ['set', 'network.proxy.peerdns=0']);
  await fs.exec('/sbin/uci', ['set', 'network.proxy.auto=1']);
  await fs.exec('/sbin/uci', ['commit', 'network']);
  await ensureTunFirewallConfig();
  await execService('firewall', 'reload');
  await execService('network', 'reload');
}

async function disableTunMode() {
  await fs.exec('/sbin/uci', ['-q', 'delete', 'network.proxy']);
  await fs.exec('/sbin/uci', ['commit', 'network']);
  await removeTunFirewallConfig();
  await execService('firewall', 'reload');
  await execService('network', 'reload');
}

async function enableTproxyMode() {
  if (!(await isTproxyConfigPresent())) {
    const ok = await writeTproxyRulesFile();
    if (!ok) return;
  }
  await setupTproxyRouting();
  await enableTproxy();
  await ensureTproxyFirewallInclude();
  await execService('firewall', 'reload');
}

async function disableTproxyMode() {
  await removeTproxyFirewallInclude();
  await disableTproxy();
  await cleanupTproxyRouting();
  await execService('firewall', 'reload');
}

async function getActiveProxyMode() {
  const val = await getUciValue('proxy_mode', 'tun');
  return val === 'tproxy' ? 'tproxy' : 'tun';
}

async function applyProxyMode(mode) {
  const nextMode = mode === 'tproxy' ? 'tproxy' : 'tun';
  await setUciValue('proxy_mode', nextMode);
  if (nextMode === 'tproxy') {
    await disableTunMode();
    await enableTproxyMode();
  } else {
    await disableTproxyMode();
    await enableTunMode();
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
      const { stdout } = await fs.exec(`/etc/init.d/${name}`, ['status']);
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
    const configPath = `/etc/sing-box/config.json`;
    const configContent = (await loadFile(configPath)).trim();
    const isInitialConfigValid = await isValidConfigFile(configContent);
  
    const singboxRunning = (singboxStatus === 'running');
    const healthAutoupdaterServiceTempFlag = await setUciOption('health_autoupdater_service_state', 'read', 'state');
    const autoupdaterServiceTempFlag = await setUciOption('autoupdater_service_state', 'read', 'state');
    const activeProxyMode = await getActiveProxyMode();
    const tproxyActive = activeProxyMode === 'tproxy';
  
    function getServiceNames() {
      const names = ['Sing‑Box'];
  
      if (healthAutoupdaterServiceTempFlag) {
        names.push('Health Autoupdater');
      } else if (autoupdaterServiceTempFlag) {
        names.push('Autoupdater');
      }
  
      return names.join(' and ');
    }
  
    const label = singboxRunning 
      ? `Stop ${getServiceNames()}`.trim()
      : `Start ${getServiceNames()}`.trim();
  
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
            if (tproxyActive) {
              await disableTproxyMode();
            }
            await execService('sing-box', 'stop');
            stoppedServices.push('Sing‑Box');
          }
  
          if (autoupdaterServiceTempFlag ) {
            await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
            stoppedServices.push('Autoupdater');
          } else if (healthAutoupdaterServiceTempFlag) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
            stoppedServices.push('Health Autoupdater');
          }
  
          notify('info', `${stoppedServices.join(' and ')} stopped`);
        } else {
          const startedServices = [];
  
          if (tproxyActive) {
            await enableTproxyMode();
          } else {
            await enableTunMode();
          }
          await execService('sing-box', 'start');
          startedServices.push('Sing‑Box');
  
          if (autoupdaterServiceTempFlag ) {
            await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
            startedServices.push('Autoupdater');
          } else if (healthAutoupdaterServiceTempFlag) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
            startedServices.push('Health Autoupdater');
          }
  
          notify('info', `${startedServices.join(' and ')} started`);
        }
      } catch (e) {
        notify('error', 'Operation failed: ' + e.message);
      } finally {
        reloadPage();
      }
    };
  
    if (singboxRunning) {
      const restartBtn = section.taboption(singboxManagmentTab, form.Button, 'svc_restart', 'Restart');
  
      const restartServicesNames = ['Sing‑Box'];
      if (healthAutoupdaterServiceTempFlag) restartServicesNames.push('Health Autoupdater');
      else if (autoupdaterServiceTempFlag) restartServicesNames.push('Autoupdater');
  
      restartBtn.inputstyle = 'reload';
      restartBtn.readonly = !isInitialConfigValid;
      restartBtn.title = `Restart ${restartServicesNames.join(' and ')}`;
      restartBtn.inputtitle = `Restart ${restartServicesNames.join(' and ')}`;
  
      restartBtn.onclick = async () => {
        try {
          const restartedServices = [];
  
          await execService('sing-box', 'restart');
          restartedServices.push('Sing‑Box');
  
          if (autoupdaterServiceTempFlag ) {
            await execServiceLifecycle('singbox-ui-autoupdater-service', 'restart');
            restartedServices.push('Autoupdater');
          } else if (healthAutoupdaterServiceTempFlag) {
            await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart');
            restartedServices.push('Health Autoupdater');
          }
  
          notify('info', `${restartedServices.join(' and ')} restarted`);
        } catch (e) {
          notify('error', 'Restart failed: ' + e.message);
        } finally {
          reloadPage()
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
        await setUciOption('autoupdater_service_state', 'write', false);
        notify('info', 'Autoupdater service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        await setUciOption('health_autoupdater_service_state', 'write', false);

        await setUciOption('autoupdater_service_state', 'write', true);
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');

        notify('info', 'Autoupdater service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      reloadPage()
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
        await setUciOption('health_autoupdater_service_state', 'write', false);
        notify('info', 'Health Autoupdater service stopped');
      } else {
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        await setUciOption('autoupdater_service_state', 'write', false);
 
        await setUciOption('health_autoupdater_service_state', 'write', true);
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');

        notify('info', 'Health Autoupdater service started');
      }
    } catch (e) {
      notify('error', 'Toggle failed: ' + e.message);
    } finally {
      reloadPage()
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
      reloadPage()
    }
  };  
}

function createDashboardButton(section, singboxManagmentTab, singboxStatus) {
  if (singboxStatus !== 'running') return;

  const btn = section.taboption(singboxManagmentTab, form.Button, 'dashboard', 'Dashboard');
  btn.inputstyle = 'apply';
  btn.title = 'Open Sing‑Box Web UI';
  btn.inputtitle = 'Dashboard';

  btn.onclick = () => {
    const routerHost = window.location.hostname;
    const dashboardUrl = `http://${routerHost}:9090/ui/`;
    window.open(dashboardUrl, '_blank');
  };
}

function normalizeServiceStatus(raw) {
  const val = (raw || '').trim();
  if (!val) return 'unknown';
  if (val.includes('running')) return 'running';
  if (val.includes('stopped') || val.includes('inactive')) return 'inactive';
  if (val.includes('error')) return 'error';
  return val;
}

async function getServiceTempFlags() {
  const healthAutoupdaterServiceTempFlag = await setUciOption('health_autoupdater_service_state', 'read', 'state');
  const autoupdaterServiceTempFlag = await setUciOption('autoupdater_service_state', 'read', 'state');
  return { healthAutoupdaterServiceTempFlag, autoupdaterServiceTempFlag };
}

function buildButton(label, style, onclick, disabled = false) {
  return E('button', {
    class: `cbi-button cbi-button-${style}`,
    disabled: disabled ? 'disabled' : null,
    onclick
  }, [label]);
}

function buildCard(title, body) {
  return E('div', {
    style: 'border:1px solid #e5e5e5;border-radius:6px;padding:12px;margin:0 0 12px;background:#fff;'
  }, [
    E('div', { style: 'font-weight:600;margin:0 0 8px;' }, [title]),
    body
  ]);
}

function buildRow(children) {
  return E('div', { style: 'display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:6px 0;' }, children);
}

function buildField(label, input) {
  return E('div', { style: 'display:flex;flex-direction:column;gap:4px;min-width:240px;flex:1;' }, [
    E('label', { style: 'font-size:12px;color:#666;' }, [label]),
    input
  ]);
}

async function buildConfigEditorBlock(config, editorId) {
  const content = await loadFile(`/etc/sing-box/${config.name}`);
  const container = E('div', { style: 'width:100%;' }, [
    E('div', { id: editorId, style: 'height:520px;width:100%;border:1px solid #ccc;' })
  ]);
  await initializeAceEditor(content, editorId);
  return container;
}

async function renderServiceControls(singboxStatus, isInitialConfigValid) {
  const status = normalizeServiceStatus(singboxStatus);
  const { healthAutoupdaterServiceTempFlag, autoupdaterServiceTempFlag } = await getServiceTempFlags();
  const activeProxyMode = await getActiveProxyMode();
  const tproxyActive = activeProxyMode === 'tproxy';

  const serviceName = () => {
    const names = ['Sing‑Box'];
    if (healthAutoupdaterServiceTempFlag) names.push('Health Autoupdater');
    else if (autoupdaterServiceTempFlag) names.push('Autoupdater');
    return names.join(' and ');
  };

  const handleAction = async (action) => {
    try {
      if (action === 'stop') {
        if (status === 'running') {
          if (tproxyActive) await disableTproxyMode();
          await execService('sing-box', 'stop');
        }

        if (autoupdaterServiceTempFlag) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        } else if (healthAutoupdaterServiceTempFlag) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        }
        notify('info', `${serviceName()} stopped`);
      }

      if (action === 'start') {
        if (tproxyActive) await enableTproxyMode();
        else await enableTunMode();

        await execService('sing-box', 'start');
        if (autoupdaterServiceTempFlag) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
        } else if (healthAutoupdaterServiceTempFlag) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
        }
        notify('info', `${serviceName()} started`);
      }

      if (action === 'restart') {
        await execService('sing-box', 'restart');
        if (autoupdaterServiceTempFlag) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'restart');
        } else if (healthAutoupdaterServiceTempFlag) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'restart');
        }
        notify('info', `${serviceName()} restarted`);
      }
    } catch (e) {
      notify('error', 'Operation failed: ' + e.message);
    } finally {
      reloadPage();
    }
  };

  const statusColors = { running: 'green', inactive: 'orange', error: 'red' };
  const statusBadge = E('span', {
    style: `color:${statusColors[status] || 'orange'};font-weight:700;`
  }, [status.toUpperCase()]);

  return buildCard('Service Status', E('div', {}, [
    buildRow([E('span', { style: 'font-size:12px;color:#666;' }, ['Current status:']), statusBadge]),
    buildRow([
      buildButton(status === 'running' ? 'Stop' : 'Start', status === 'running' ? 'negative' : 'apply', () => handleAction(status === 'running' ? 'stop' : 'start'), !isInitialConfigValid),
      status === 'running' ? buildButton('Restart', 'reload', () => handleAction('restart'), !isInitialConfigValid) : null,
      status === 'running' ? buildButton('Dashboard', 'apply', () => {
        const routerHost = window.location.hostname;
        window.open(`http://${routerHost}:9090/ui/`, '_blank');
      }) : null
    ].filter(Boolean))
  ]));
}

function renderProxyModeCard(activeProxyMode) {
  const selectId = 'singbox_proxy_mode_select';
  const select = E('select', { id: selectId, class: 'cbi-input-select' }, [
    E('option', { value: 'tun', selected: activeProxyMode === 'tun' ? 'selected' : null }, ['TUN']),
    E('option', { value: 'tproxy', selected: activeProxyMode === 'tproxy' ? 'selected' : null }, ['TPROXY'])
  ]);

  const applyBtn = buildButton('Apply Mode', 'apply', async () => {
    const value = document.getElementById(selectId)?.value;
    if (!value) return notify('error', 'Select a mode first');
    try {
      await applyProxyMode(value);
      notify('info', `Mode switched to ${value.toUpperCase()}`);
    } catch (e) {
      notify('error', 'Mode switch failed: ' + e.message);
    } finally {
      reloadPage();
    }
  });

  return buildCard('Proxy Mode', E('div', {}, [
    buildRow([
      buildField('Active mode', select),
      applyBtn
    ])
  ]));
}

async function renderLogsCard() {
  const logs = (await readLogs()).trim();
  const content = logs || 'No logs found.';
  return buildCard('Logs', E('div', {}, [
    E('textarea', {
      style: 'width:100%;height:220px;font-family:monospace;resize:vertical;',
      readonly: 'readonly'
    }, [content]),
    buildRow([buildButton('Refresh', 'reload', () => reloadPage())])
  ]));
}

async function renderMainConfigCard(config) {
  const urlInputId = `singbox_url_${config.name}`;
  const urlValue = await loadFile(`/etc/sing-box/url_${config.name}`);
  const urlInput = E('input', { id: urlInputId, class: 'cbi-input-text', value: urlValue.trim() });

  const editorId = `editor_${config.name}`;
  const editorBlock = await buildConfigEditorBlock(config, editorId);

  const saveUrlBtn = buildButton('Save URL', 'positive', async () => {
    const url = document.getElementById(urlInputId)?.value.trim();
    if (!url) return notify('error', 'URL empty');
    if (!isValidUrl(url)) return notify('error', 'Invalid URL');
    await saveFile(`/etc/sing-box/url_${config.name}`, url, 'URL saved');
    reloadPage();
  });

  const updateBtn = buildButton('Update Config', 'reload', async () => {
    const url = (await loadFile(`/etc/sing-box/url_${config.name}`)).trim();
    if (!isValidUrl(url)) return notify('error', 'Invalid URL');
    try {
      const r = await fs.exec('/usr/bin/singbox-ui/singbox-ui-updater', [`/etc/sing-box/url_${config.name}`, `/etc/sing-box/${config.name}`]);
      if (r.code === 2) return notify('info', 'No changes detected');
      if (r.code !== 0) return notify('error', r.stderr || r.stdout || 'Unknown');
      await execService('sing-box', 'reload');
      notify('info', 'Main config reloaded');
    } catch (e) {
      notify('error', 'Update failed: ' + e.message);
    } finally {
      reloadPage();
    }
  });

  const saveConfigBtn = buildButton('Save Config', 'positive', async () => {
    let aceEditor = null;
    try {
      aceEditor = ace.edit(editorId);
    } catch {
      notify('error', 'Editor is not initialized');
      return;
    }
    const val = aceEditor.getValue();
    if (!val) return notify('error', 'Config is empty');
    if (!(await isValidConfigFile(val))) return;
    await saveFile(`/etc/sing-box/${config.name}`, val, 'Config saved');
    await execService('sing-box', 'reload');
    notify('info', 'Sing‑Box reloaded');
    reloadPage();
  });

  const clearBtn = buildButton('Clear All', 'negative', async () => {
    try {
      await saveFile(`/etc/sing-box/${config.name}`, '{}', 'Config cleared');
      await saveFile(`/etc/sing-box/url_${config.name}`, '', 'URL cleared');
      if (await isTproxyTablePresent()) await disableTproxy();
      await execService('sing-box', 'stop');
      await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
      await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
      notify('info', 'Services stopped');
    } catch (e) {
      notify('error', `Clear failed: ${e.message}`);
    } finally {
      reloadPage();
    }
  });

  return buildCard('Main Configuration', E('div', {}, [
    buildRow([buildField('Subscription URL', urlInput), saveUrlBtn, updateBtn]),
    editorBlock,
    buildRow([saveConfigBtn, clearBtn])
  ]));
}

async function renderBackupConfigsCard(configs) {
  const blocks = await Promise.all(configs.map(async (config) => {
    const urlInputId = `singbox_url_${config.name}`;
    const urlValue = await loadFile(`/etc/sing-box/url_${config.name}`);
    const urlInput = E('input', { id: urlInputId, class: 'cbi-input-text', value: urlValue.trim() });

    const editorId = `editor_${config.name}`;
    const editorBlock = await buildConfigEditorBlock(config, editorId);

    const saveUrlBtn = buildButton('Save URL', 'positive', async () => {
      const url = document.getElementById(urlInputId)?.value.trim();
      if (!url) return notify('error', 'URL empty');
      if (!isValidUrl(url)) return notify('error', 'Invalid URL');
      await saveFile(`/etc/sing-box/url_${config.name}`, url, 'URL saved');
      reloadPage();
    });

    const updateBtn = buildButton('Update Config', 'reload', async () => {
      const url = (await loadFile(`/etc/sing-box/url_${config.name}`)).trim();
      if (!isValidUrl(url)) return notify('error', 'Invalid URL');
      try {
        const r = await fs.exec('/usr/bin/singbox-ui/singbox-ui-updater', [`/etc/sing-box/url_${config.name}`, `/etc/sing-box/${config.name}`]);
        if (r.code === 2) return notify('info', 'No changes detected');
        if (r.code !== 0) return notify('error', r.stderr || r.stdout || 'Unknown');
        notify('info', `Updated ${config.label}`);
      } catch (e) {
        notify('error', 'Update failed: ' + e.message);
      } finally {
        reloadPage();
      }
    });

    const setMainBtn = buildButton('Set as Main', 'apply', async () => {
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
        reloadPage();
      }
    });

    const clearBtn = buildButton('Clear All', 'negative', async () => {
      try {
        await saveFile(`/etc/sing-box/${config.name}`, '{}', 'Config cleared');
        await saveFile(`/etc/sing-box/url_${config.name}`, '', 'URL cleared');
      } catch (e) {
        notify('error', `Clear failed: ${e.message}`);
      } finally {
        reloadPage();
      }
    });

    return E('details', { style: 'margin:8px 0;' }, [
      E('summary', { style: 'cursor:pointer;font-weight:600;' }, [config.label]),
      buildRow([buildField('Subscription URL', urlInput), saveUrlBtn, updateBtn]),
      editorBlock,
      buildRow([setMainBtn, clearBtn])
    ]);
  }));

  return buildCard('Backup Configurations', E('div', {}, blocks));
}

async function renderServicesCard(autoupdaterEnabled, healthAutoupdaterEnabled, memdocEnabled) {
  const buildServiceRow = (title, description, enabled, onClick) => {
    return E('div', { style: 'margin:6px 0;' }, [
      E('div', { style: 'font-weight:600;' }, [title]),
      E('div', { style: 'font-size:12px;color:#666;margin:2px 0 6px;' }, [description]),
      buildButton(enabled ? 'Stop' : 'Start', enabled ? 'negative' : 'positive', onClick)
    ]);
  };

  const autoupdaterRow = buildServiceRow(
    'Autoupdater Service',
    'Automatically updates the main config every 60 minutes and reloads Sing‑Box if changes are detected.',
    autoupdaterEnabled,
    async () => {
      try {
        if (autoupdaterEnabled) {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
          await setUciOption('autoupdater_service_state', 'write', false);
          notify('info', 'Autoupdater service stopped');
        } else {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
          await setUciOption('health_autoupdater_service_state', 'write', false);
          await setUciOption('autoupdater_service_state', 'write', true);
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'start');
          notify('info', 'Autoupdater service started');
        }
      } catch (e) {
        notify('error', 'Toggle failed: ' + e.message);
      } finally {
        reloadPage();
      }
    }
  );

  const healthRow = buildServiceRow(
    'Health Autoupdater Service',
    'Checks server health every 90 seconds. After 60 successful checks, updates config and reloads Sing‑Box. If the server goes down, stops Sing‑Box; when back online, restores config and restarts the service.',
    healthAutoupdaterEnabled,
    async () => {
      try {
        if (healthAutoupdaterEnabled) {
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
          await setUciOption('health_autoupdater_service_state', 'write', false);
          notify('info', 'Health Autoupdater service stopped');
        } else {
          await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
          await setUciOption('autoupdater_service_state', 'write', false);
          await setUciOption('health_autoupdater_service_state', 'write', true);
          await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'start');
          notify('info', 'Health Autoupdater service started');
        }
      } catch (e) {
        notify('error', 'Toggle failed: ' + e.message);
      } finally {
        reloadPage();
      }
    }
  );

  const memdocRow = buildServiceRow(
    'Memdoc Service',
    'Checks memory usage every 10 seconds. If memory usage exceeds 15 MB, restarts Sing‑Box.',
    memdocEnabled,
    async () => {
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
        reloadPage();
      }
    }
  );

  return buildCard('Services', E('div', {}, [
    autoupdaterRow,
    healthRow,
    memdocRow
  ]));
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
    reloadPage()
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
    reloadPage()
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
        if (r.code !== 0) return notify('error', r.stderr || r.stdout || 'Unknown');
        if (config.name === 'config.json') {
          await execService('sing-box', 'reload');
          notify('info', 'Main config reloaded');
        } else {
          notify('info', `Updated ${config.label}`);
        }
      } catch (e) {
        notify('error', 'Update failed: ' + e.message);
      } finally {
        reloadPage()
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
      reloadPage()
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
        if (await isTproxyTablePresent()) {
          await disableTproxy();
        }
        await execService('sing-box', 'stop');
        await execServiceLifecycle('singbox-ui-autoupdater-service', 'stop');
        await execServiceLifecycle('singbox-ui-health-autoupdater-service', 'stop');
        notify('info', 'Services stopped');
      }
    } catch (e) {
      notify('error', `Clear failed: ${e.message}`);
    } finally {
      reloadPage()
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
    const singboxStatus = await execService('sing-box', 'status');
    const healthAutoupdaterServiceEnabled = await isServiceActive('singbox-ui-health-autoupdater-service');
    const autoupdaterServiceEnabled = await isServiceActive('singbox-ui-autoupdater-service');
    const memdocServiceEnabled = await isServiceActive('singbox-ui-memdoc-service');

    const mainConfig = { name: 'config.json', label: 'Main Config' };
    const backupConfigs = [
      { name: 'config2.json', label: 'Backup Config #1' },
      { name: 'config3.json', label: 'Backup Config #2' }
    ];

    const configContent = (await loadFile('/etc/sing-box/config.json')).trim();
    const isInitialConfigValid = await isValidConfigFile(configContent);
    const activeProxyMode = await getActiveProxyMode();

    const container = E('div', { style: 'max-width:1200px;' }, [
      E('h2', { style: 'margin:0 0 12px;' }, ['VPN: Proxy Suite: Sing‑Box']),
      await renderServiceControls(singboxStatus, isInitialConfigValid),
      renderProxyModeCard(activeProxyMode),
      await renderMainConfigCard(mainConfig),
      await renderLogsCard(),
      await renderBackupConfigsCard(backupConfigs),
      await renderServicesCard(autoupdaterServiceEnabled, healthAutoupdaterServiceEnabled, memdocServiceEnabled)
    ]);

    return container;
  }
});
