## SSH tunnel portal

Let's go!

<div id="main-section">
  <input type="text" id="username-input" />
  <input type="button" onClick="downloadScript()" value="Launch tunnel" />
</div>

<script>
  function getConfig() {
    var a = document.createElement('a')
    a.href = 'data:text/plain;charset=UTF8,' + encodeURI(configFromPage())
    a.download = 'start_tunnel.sh'
    a.click()
  }

  function configFromPage() {
    var username = document.getElementById('username-input').value
    return 'curl --connect-timeout 90 --retry 5 --location ' +
           'https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | ' +
           'bash -s -- "ramses" "~/.ssh/id_ec" "6012" ""'
  }
</script>

