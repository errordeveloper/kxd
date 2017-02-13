#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

volumes=(
  /var/lib/docker:/var/lib/docker:rw
  /:/rootfs:ro
  /sys:/sys:ro
  /dev:/dev:rw
  /var/run:/var/run:rw
)

#"/var/lib/kubelet:/var/lib/kubelet:rw,rshared"
#"/var/log/containers:/var/log/containers:rw"
#"/etc/kubernetes:/etc/kubernetes:rw"

args=(
  --rm --interactive --tty 
  --privileged --net=host --pid=host
)

for v in "${volumes[@]}" ; do args+=("--volume=${v}") ; done

docker run "${args[@]}" kdx
