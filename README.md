# kubernetes-distro

# Requirements

- All nodes should be able to reach each other via hostname

workaround:
```shell
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if ! multipass list | grep workstation; then
  multipass launch -n workstation -c 1 -m 1G -d 10G --cloud-init cloud.cfg
else
  multipass start workstation
fi

cat <<EOF > hosts
127.0.0.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

multipass list | egrep -v "Name|\-\-" | awk '{var=sprintf("%s\t%s.multipass",$3,$1); print var}' >> hosts
multipass transfer hosts workstation:/home/ubuntu/hosts
multipass exec workstation sudo mv hosts /etc/hosts
```

# Related links
- [multipass /etc/hosts](https://github.com/canonical/multipass/issues/853#issuecomment-630097263)
- https://www.youtube.com/playlist?list=PLC6M23w-Wn5mA_bomV6YVB5elNw7IsHt5
