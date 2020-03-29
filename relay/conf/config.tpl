Host *
#StrictHostKeyChecking no
#UserKnownHostsFile /dev/null
ServerAliveInterval 240
IdentityFile ~/.ssh/${sshkey}

Host msfrelay2
#15.188.17.148
HostName sshrelay2.msf.be
User tunneller
ForwardAgent yes

Host msfrelay1
#185.199.180.11
HostName sshrelay1.msf.be
User tunneller
ForwardAgent yes

Host ${location} ${location}2
HostName localhost
Port $port_location
User ${userlogin}
ProxyJump msfrelay2
IdentitiesOnly yes
DynamicForward 9006

Host ${location}1 
HostName localhost
Port $port_location
User User ${userlogin}
ProxyJump msfrelay1
IdentitiesOnly yes
DynamicForward 9006




