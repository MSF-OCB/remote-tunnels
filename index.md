<script>
  function downloadScript() {
    var a = document.createElement('a')

    var username = sanitise(getInput('username-input'))
    var port     = sanitise(getInput('target-selector'))

    if (username && port) {
      script = generateScript(username, port)
      a.href = 'data:text/plain;charset=UTF8,' + encodeURIComponent(script)
      a.download = 'start_tunnel.sh'
      a.click()
    }
  }

  function generateScript(username, port) {
    var url = 'https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh'

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

  function quote(str) {
    return '"' + str + '"'
  }

  function getInput(inputId) {
    return document.getElementById(inputId).value
  }

  function sanitise(str) {
    return str.replace(/[^a-z0-9]+/gi, "_");
  }

  targets = [
    {
      "name": "Country1 Project1 Server1",
      "port" : "1234"
    },
    {
      "name": "Country2 Project1 Server1",
      "port": "2345"
    }
    {
      "name": "Country2 Project1 Server2",
      "port": "2345"
    }
    {
      "name": "Country2 Project2 Server1",
      "port": "2345"
    }
  ]

  function populateTargets() {
    var select = document.getElementById('target-selector')
    targets.map((target) => {
      option = document.createElement('option');
      option.setAttribute('value', target.port);
      option.appendChild(document.createTextNode(target.name));
      select.appendChild(option);
    })
  }

  window.addEventListener('load', populateTargets);

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
   <label for="target-selector">Target server:</label>
  </div>
  <div class="column" id="input-column">
   <input type="text" id="username-input" />
   <select id="target-selector" onSelect="targetSelected"></select>
  </div>
  <div class="clear">
   <input type="button" onClick="downloadScript" value="Download script" />
  </div>
 </fieldset>
</div>
</div>

