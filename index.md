<script>
  function getConfig() {
    var a = document.createElement('a')
    a.href = 'data:text/plain;charset=UTF8,' +
             encodeURIComponent(configFromPage())
    a.download = 'start_tunnel.sh'
    a.click()
  }

  function configFromPage() {
    var username = sanitise(getInput('username-input'))
    var port     = sanitise(getInput('port-input'))

    var url = 'https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh'

    if (username && port) {
      return [ '#! /usr/bin/env bash'
             , ""
             , [ 'curl --connect-timeout 90 --retry 5 --location'
               , url
               , '|'
               , 'bash -s --'
               , quote(username)
               , quote('~/.ssh/id_ed25519')
               , quote(port)
               ].join(" ")
             ].join("\n")
    }
  }

  function quote(str) {
    return '"' + str + '"'
  }

  function getInput(inputId) {
    return document.getElementById(inputId).value
  }

  function sanitise(str) {
    return str.replace(/[^a-z0-9]+/gi, "_");
  }
</script>

<style>
  label {
    display: block;
  }
  input {
    display:block;
  }
  .column {
    float:left;
  }
  .clear {
    margin-top: 10px;
    clear: both;
  }
  #input-column {
    margin-left:10px;
    padding-left:10px;
  }
</style>

## SSH tunnel portal

<div id="main-section">
<div id="form-section" class="form-class">
 <fieldset>
  <div class="column">
   <label for="username-input">User name:</label>
   <label for="port-input">Port number:</label>
  </div>
  <div class="column" id="input-column">
   <input type="text" id="username-input" />
   <input type="text" id="port-input" />
  </div>
  <div class="clear">
   <input type="button" onClick="getConfig()" value="Launch tunnel" />
  </div>
 </fieldset>
</div>
</div>

