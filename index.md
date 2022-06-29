<script>
  function getConfig() {
    var a = document.createElement('a')
    a.href = 'data:text/plain;charset=UTF8,' + encodeURI(configFromPage())
    a.download = 'start_tunnel.sh'
    a.click()
  }

  function configFromPage() {
    var username = sanitise(getInput('username-input'))
    var port     = sanitise(getInput('port-input'))

    if (username && port) {
      return '#! /usr/bin/env bash\n\n' +
             'curl --connect-timeout 90 --retry 5 --location ' +
             'https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | ' +
             'bash -s -- "ramses" "~/.ssh/id_ec" "port" ""'
    }
  }

  function getInput(inputId) {
    return document.getElementById(inputId).value
  }

  function sanitise(str) {
    return str.replace(/[^a-z0-9]+/gi, "_");
  }
</script>

## SSH tunnel portal

Let's go!

<div id="main-section">
 <form>
  <label for="username-input">User name:</label>
  <input type="text" id="username-input" /><br />

  <label for="port-input">Port number:</label>
  <input type="text" id="port-input" /><br />

  <input type="button" onClick="getConfig()" value="Launch tunnel" />
 </form>
</div>

