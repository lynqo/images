#!/bin/sh
exec >/dev/console 2>&1
set -eux
trap poweroff EXIT

cloud-init status --wait || true

case $1 in
debian)
  export DEBIAN_FRONTEND=noninteractive
  apt="apt-get -y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confold"
  $apt update
  $apt dist-upgrade
  $apt install qemu-guest-agent
  $apt clean
  rm -rf /var/lib/apt/lists/*
  ;;
rhel)
  dnf -y upgrade
  dnf -y install qemu-guest-agent policycoreutils-python-utils
  dnf clean all
  ;;
esac
systemctl enable qemu-guest-agent

cloud-init clean --logs
rm -rf /etc/ssh/ssh_host_* /etc/netplan/50-cloud-init.yaml /etc/NetworkManager/system-connections/* \
  /var/lib/systemd/random-seed /root/.bash_history /tmp/* /var/tmp/*
truncate -s 0 /etc/machine-id
fstrim -av || true
sync

echo IMAGE_READY
