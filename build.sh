#!/bin/bash
set -euxo pipefail
cd "$(dirname "$0")"

name=$1
image=$(jq --arg name "$name" '.[] | select(.name == $name)' images.json)
family=$(jq -r .family <<<"$image")
url=$(jq -r .url <<<"$image")

seed() {
  rm -rf seed && mkdir seed
  echo "{\"instance-id\": \"$1\"}" >seed/meta-data
  printf '#cloud-config\n%s\n' "$2" >seed/user-data
  genisoimage -quiet -output seed.iso -volid cidata -joliet -rock seed
}

boot() {
  timeout 40m qemu-system-x86_64 -enable-kvm -machine pc -smp 2 -m 2048 -display none -vga std \
    -nic user,model=virtio-net-pci -cdrom seed.iso "$@"
}

curl -fsSL -o upstream.qcow2 "$url"
qemu-img resize upstream.qcow2 10G

seed build "$(jq -n --rawfile script guest.sh --arg family "$family" '{
  users: [],
  write_files: [{path: "/run/guest.sh", content: $script}],
  runcmd: ["systemd-run --no-block sh /run/guest.sh \($family)"]
}')"
boot -cpu host -serial file:build.log -drive file=upstream.qcow2,if=virtio,discard=unmap || true
cat build.log
grep -q IMAGE_READY build.log
qemu-img convert -c -O qcow2 upstream.qcow2 "$name.qcow2"

seed test '{"users": []}'
boot -cpu SandyBridge -serial file:test.log -drive "file=$name.qcow2,if=virtio,snapshot=on" \
  -device virtio-serial -chardev socket,path=agent.sock,server=on,wait=off,id=agent \
  -device virtserialport,chardev=agent,name=org.qemu.guest_agent.0 -pidfile test.pid &
trap 'kill "$(cat test.pid)"' EXIT
python3 wait-agent.py agent.sock || { cat test.log; exit 1; }

sha256=$(sha256sum "$name.qcow2" | cut -d' ' -f1)
jq --arg sha256 "$sha256" '{os, version, family, file: "\(.name).qcow2", sha256: $sha256}' <<<"$image" >"$name.json"
