#!/bin/bash -x

## Using new Python client would be nice, there is a lot of dancing around already
## and we will have more and more of it... Otherwise we can do it in Go.

set -o errexit
set -o pipefail
set -o nounset

readonly image_name="errordeveloper/kxd"

## TODO rootfs should be mounted read-only, this is because of CNI hack...
sys_volumes=(
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
rootfs_vol="--volume=/:/rootfs:rw"

## TODO this will fail on the first run for numerous reasons
# - directories missing in /, so Docker for Mac will refuse mounts
# - does kubeadm reset fail miserably?
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "mkdir -p /rootfs/etc/kubernetes"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "mkdir -p /rootfs/var/lib/kubelet"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "mkdir -p /rootfs/var/log/containers"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "mkdir -p /rootfs/etc/cni"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "mkdir -p /rootfs/opt/cni"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "cp -r /opt/cni/bin /rootfs/opt/cni"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "nsenter --mount=/proc/1/ns/mnt -- mount --bind /var/lib/kubelet /var/lib/kubelet"
docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "nsenter --mount=/proc/1/ns/mnt -- mount --make-rshared /var/lib/kubelet"

for v in "${kxd_volumes[@]}" ; do args+=("--volume=${v}") ; done
rootfs_vol="--volume=/:/rootfs:ro"

docker run "${args[@]}" "${rootfs_vol}" --rm "${image_name}:shell" "kubeadm reset"

docker run "${args[@]}" "${rootfs_vol}" --name=kxd --detach "${image_name}:kubelet"

## TODO it is possible Docker for Mac VM gets a different address on eth0
readonly primary_address=192.168.65.2
docker exec --tty --interactive kxd kubeadm init --skip-preflight-checks --api-advertise-addresses="${primary_address}" --api-advertise-addresses=127.0.0.1
docker exec --tty --interactive kxd kubectl create --filename /etc/weave-daemonset.yaml

readonly proxy_port=8443
docker run --detach --tty --interactive --publish="${proxy_port}:${proxy_port}" "${image_name}:shell" "socat TCP-LISTEN:${proxy_port},fork TCP:${primary_address}:6443"

docker cp kxd:/etc/kubernetes/admin.conf kubeconfig
export KUBECONFIG=kubeconfig
kubectl config set-cluster kubernetes --server="https://127.0.0.1:${proxy_port}"
kubectl taint node moby dedicated:NoSchedule-
kubectl get nodes
