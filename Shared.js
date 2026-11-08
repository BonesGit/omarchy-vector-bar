.pragma library

// Shared across every monitor's BarWidget instance (same Quickshell process).
// Lets IPC escape() close the settings card even when the first IpcHandler
// is not the instance that opened it.

var _settingsHost = null

function claimSettings(host) {
  _settingsHost = host
}

function releaseSettings(host) {
  if (_settingsHost === host)
    _settingsHost = null
}

function closeSettings() {
  if (!_settingsHost)
    return false
  var host = _settingsHost
  _settingsHost = null
  if (host.settingsOpen) {
    host.settingsOpen = false
    return true
  }
  return false
}
