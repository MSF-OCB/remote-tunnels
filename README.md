## Generation of a batch of relay keys with passphrases per location
### Installation
1. Install the latest version of Python (at the time of writing, that is [version 3.8.2](https://www.python.org/ftp/python/3.8.2/python-3.8.2-amd64-webinstall.exe))
2. Download the file `keygen.sh` from this repo and put it on your local hard disk with the same name.
3. From within Git Bash, go to the directory in which you put the `keygen.sh` file (using the `cd` command) and run `chmod +x keygen.sh` to make the file executable
4. Add your public ssh key to your github profile by clicking on your profile picture in the top right corner, choosing settings, going to "SSH and GPG keys", and using the green button that says "New SSH key"
5. Add the following entry to your `.ssh/config` file to be able to connect to github using ssh:
```
Host github.com
  HostName ssh.github.com
  User git
  Port 443
```

Please test the connection to github before proceeding with the script below. To do so, run `ssh -T github.com`, and you should get a message saying
```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

### Running the script
Example usage, from within the directory containing `keygen.sh`:
```
./keygen.sh -l be_bruxelles -s benuc002 -n 3
```

Full usage information:
```
usage: keygen.sh [-h] -l MSF_LOCATION -s HOST [-n AMOUNT] [-u USER] [--dry-run]

Generate keys and launch script for SSH tunnels.

optional arguments:
  -h, --help            show this help message and exit
  -l MSF_LOCATION, --location MSF_LOCATION The location of the MSF project, e.g. be_bruxelles
  -s HOST, --server HOST                   The remote server to which this key will give access, e.g. benuc002
  -n AMOUNT, --num AMOUNT                  The amount of keys to generate, defaults to 5
  -u USER, --user USER                     The user that will be used to connect, defaults to "uf_<location>"
  --dry-run                                Run the script without making any changes to github
```

# Information below needs to be updated

A batch is a folder that contains:
 - *batch_karachi_1585400011_index.csv* : a CSV file with (initial) generated passphrase. This file is to be converted to.xlsx and shared online with the key dispatchers. 1 key = 1 user
 - *pub_keys_to_add_to_unifield* : a list of public keys to be added to an authorized relay user. Once added, the relay(s) and the related nuc or reverse tunnel providers should be updated
- *relay_karachi_key_1585400012.zip ...* a list of zip folders that contains the configuration to be deployed on end user machine (see article) 
- *key_pairs.tgz* : an archived zip folder that contains all key pairs

All these files should be added to a keeper record.
### Setup

#### Main advantages of this approach:

-   This is way more secured (and cleaner) that the nat-forwarding - the connection goes encrypted through  **our**  relay servers.
-   We can place the relays wherever we want in the world (right now we have one at HQ , and the other on amazon aws in Paris - but why not putting one in Azure South Africa for instance?)
-   No need for a public or fixed IP - (you can even reach an android phone as we did in the FICT))
-   There is no need to configure a VPN at the router/firewall level (and no fragile double nating for instance)  
    
-   We can quickly disable a compromised access (by removing its key on the server)
-   It acts as a vpn with access to local DNS so the whole LAN is reachable - see below (i would have prefered to restrict access to UF machine only but it's not that simple)
-   No need to change the host file of the user's machine
-   All connections are ssh encrypted by default (like a VPN)
-   access control via key is (relatively) easy to handle (it is easy for our nucs and our users on linux environnements, but way more boring for windows)
-   It is free and based on open source tools (open ssh)  
    
-   it is similar but simpler than openvpn (it is not a VPN in the sense that it only touches OSI layer 7 (app) and not the lower level layers - but who cares?)
-   No need to be admin to do the setup

#### Drawbacks : (there are mainly cosmetics)

-   since we are dealing with windows user machines, there is a need to install a light linux layer to use ssh - It is possible to use putty to establish the tunnel but i gave up (there is a need to do a proxyjump (a first connection to the relay with a unprivileged account, then from the relay a second connection to the unifield credential, trivial with ssh, way too complex for putty)
-   I managed to make the usage simple. The tunnel is established by simply double clicking a bash script, and entering a password. (there is a double protection here : an ssh key + a passphrase - the passphrase is important in case the user's laptop would be stolen - in this case, if we are aware of it, we simply remove the key from the relay to disable the account)
-   Once the tunnel is established, a socks5 proxy should be configured in the browser. I recommend to do that in firefox. This is just a setup do do once, and then enable /disable when needed

### installation on end-user windows machine
-   On the user machine (yours for this demo) , fetch and install [Git for windows](https://github.com/git-for-windows/git/releases/download/v2.26.0.windows.1/Git-2.26.0-64-bit.exe "https://github.com/git-for-windows/git/releases/download/v2.26.0.windows.1/Git-2.26.0-64-bit.exe") (44Mb) wherever you want -

-   On the first install screen make sure that "_Window Explorer Integration/Git  **Bash**  here_ "and "_Associate .sh files to be run with bash"_ options are checked
- For conveniency , uncheck  _Window Explorer Integration/Git  **GUI**  here_  ")
-   Just keep all other options to their default values
-   Unzip the attached file "_relay.zip_" to your desktop - Open the folder and double click on tunnel.sh
-   The password associated to teh key will be asked twice (be careful Ctrl+V will not work in the Git bash window, use right click + paste instead)  
    Why Twice? one for the relay, and one for the server  (remember there is a jump) - Note that we use the same key for both hops but we could actually use 2 different keys for higher security.  
    After the second password entry, the terminal will "freeze", (I know this is a bit unusual) there are no indications that you are connected, but if you did not get any error message the tunnel is actually established !
-   Open Firefox : 
    
-   1.  Click the menu button and select  Preferences.
    2.  In the  General  panel, go to the  **Network Settings**  section.
    3.  Click  Settings…. The  **Connection Settings**  dialog will open
    4.  Select manual proxy config and fill in the option as in the screenshot below (look at the yellow marks)
   ![firefox setup](/images/firefox.png)
        
That's it - Firefox acts  now as if you were in the capeTown local network.

To close the connection just close the terminal window (or press Ctrl+C inside)

if you want to bring firefox back to normal you should go back to its network settings and select the No Proxy option. (next time you activate the tunnel, you simply have to select the manual proxy configuration , the parameters don't need to be entered again. Note that in this setup only firefox is affected, chrome is not.

To reconnect manually :
Close or Ctrl+C the Git bash window - Do not change anything in firefox, keep the proxy enabled. Right click on the desktop and chose "Git Bash here" to open a new terminal.
Simply type the following command related to your location e.g. 

    ssh -N karachi

The password will be asked twice as before (this can be improved by using an ssh-agent)
