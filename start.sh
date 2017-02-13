#!/bin/bash -x

## Using new Python client would be nice, there is a lot of dancing around already
## and we will have more and more of it... Otherwise we can do it in Go.

set -o errexit
set -o pipefail
set -o nounset

## TODO rootfs should be mounted read-only, this is because of CNI hack...
sys_volumes=(
  /:/rootfs:rw
  /sys:/sys:ro
  /dev:/dev:rw
  /var/run:/var/run:rw
  /var/lib:/var/lib:rw
)

kxd_volumes=(
  /opt/cni:/opt/cni:ro
  /etc/cni:/etc/cni:ro
  /etc/kubernetes:/etc/kubernetes:rw
  /var/lib/kubelet:/var/lib/kubelet:rw,rshared
  /var/log/containers:/var/log/containers:rw
)

kill_list=($(docker ps --all --quiet))

test "${#kill_list}" -gt 0 && docker rm --volumes --force "${kill_list[@]}"

args=(
  --privileged --net=host --pid=host
)

for v in "${sys_volumes[@]}" ; do args+=("--volume=${v}") ; done

## TODO this will fail on the first run for numerous reasons
# - directories missing in /, so Docker for Mac will refuse mounts
# - does kubeadm reset fail miserably?
docker run "${args[@]}" --rm kxd:shell "mkdir -p /rootfs/var/lib/kubelet"
docker run "${args[@]}" --rm kxd:shell "mkdir -p /rootfs/var/log/containers"
docker run "${args[@]}" --rm kxd:shell "mkdir -p /rootfs/opt/cni"
docker run "${args[@]}" --rm kxd:shell "cp -r /opt/cni/bin /rootfs/opt/cni"
docker run "${args[@]}" --rm kxd:shell "nsenter --mount=/proc/1/ns/mnt -- mount --bind /var/lib/kubelet /var/lib/kubelet"
docker run "${args[@]}" --rm kxd:shell "nsenter --mount=/proc/1/ns/mnt -- mount --make-rshared /var/lib/kubelet"

for v in "${kxd_volumes[@]}" ; do args+=("--volume=${v}") ; done

docker run "${args[@]}" --rm kxd:shell "kubeadm reset"

docker run "${args[@]}" --name=kxd --detach kxd:kubelet

docker exec --tty --interactive kxd kubeadm init --skip-preflight-checks
docker exec --tty --interactive kxd kubectl create -f /etc/weave-daemonset.yaml