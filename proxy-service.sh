#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

readonly image_name="errordeveloper/kxd"

readonly svc="$(kubectl get service "$@" -o json)"

test "$(echo "${svc}" | jq -r '.kind')" = "Service" || exit 1

readonly cmd=" \
  /rootfs/usr/bin/slirp-proxy \
  -i -no-local-ip \
  -host-ip 0.0.0.0 \
  "$(echo "${svc}" | jq -r '.spec | "-proto \(.ports[0].protocol | ascii_downcase) -host-port \(.ports[0].port) -container-ip \(.clusterIP) -container-port \(.ports[0].port)"')" \
"

readonly sys_volumes=(
  "/:/rootfs:ro"
  "/port:/port:rw"
  "/lib/ld-musl-x86_64.so.1:/lib/ld-musl-x86_64.so.1:ro"
  "/lib/libc.musl-x86_64.so.1:/lib/libc.musl-x86_64.so.1:ro"
)

args=(
  --label="kxd.k8s.io/infra=true"
  --detach
  --privileged --net=host --pid=host
)

for v in "${sys_volumes[@]}" ; do args+=("--volume=${v}") ; done

docker run "${args[@]}" "${image_name}:shell" "${cmd}"
