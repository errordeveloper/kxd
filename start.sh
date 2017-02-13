#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

volumes=(
  /:/rootfs:ro
  /sys:/sys:ro
  /dev:/dev:rw
  /var/run:/var/run:rw
  /var/lib:/var/lib:rw
  /etc/kubernetes:/etc/kubernetes:rw
)

#"/var/log/containers:/var/log/containers:rw"

kill_list=($(docker ps --all --quiet))

test "${#kill_list}" -gt 0 && docker rm --volumes --force "${kill_list[@]}"

commond_args=(
  --privileged --net=host --pid=host
)

for v in "${volumes[@]}" ; do commond_args+=("--volume=${v}") ; done

## TODO this will fail on the first run for numerous reasons
# - directories missing in /, so Docker for Mac will refuse mounts
# - does kubeadm reset fail miserably?
docker run --rm "${commond_args[@]}" kxd:shell "kubeadm reset"
docker run --rm "${commond_args[@]}" kxd:shell "mkdir -p /var/lib/kubelet"
docker run --rm "${commond_args[@]}" kxd:shell "nsenter --mount=/proc/1/ns/mnt -- mount --bind /var/lib/kubelet /var/lib/kubelet"
docker run --rm "${commond_args[@]}" kxd:shell "nsenter --mount=/proc/1/ns/mnt -- mount --make-rshared /var/lib/kubelet"

docker run --name=kxd --detach --volume=/var/lib/kubelet:/var/lib/kubelet:rw,rshared "${commond_args[@]}" kxd:kubelet

docker exec --tty --interactive kxd kubeadm init --skip-preflight-checks
docker exec --tty --interactive kxd kubectl create -f /etc/weave-daemonset.yaml
