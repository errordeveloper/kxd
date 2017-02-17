#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

readonly image_name="errordeveloper/kxd"

readonly svc="$(kubectl get service "$@" -o json)"

test "$(echo "${svc}" | jq -r '.kind')" = "Service" || exit 1

readonly darwin_ifconfig_cmd=" \
  sudo ifconfig lo0 alias \
    "$(echo "${svc}" | jq -r '.spec | "\(.clusterIP) netmask 255.240.0.0"')"\
"

readonly docker_slirp_proxy_cmd=" \
  /rootfs/usr/bin/slirp-proxy -i -no-local-ip \
    "$(echo "${svc}" | jq -r '.spec | "-proto \(.ports[0].protocol | ascii_downcase) -host-ip \(.clusterIP) -host-port \(.ports[0].port) -container-ip \(.clusterIP) -container-port \(.ports[0].port)"')" \
"
readonly docker_container_name="$(echo "${svc}" \
  | jq -r '"kxd-svc-\(.metadata.namespace)-\(.metadata.name)-\(.spec.clusterIP)-\(.spec.ports[0].port)-\(.spec.ports[0].protocol | ascii_downcase)"')\
"

readonly sys_volumes=(
  "/:/rootfs:ro"
  "/port:/port:rw"
  "/lib/ld-musl-x86_64.so.1:/lib/ld-musl-x86_64.so.1:ro"
  "/lib/libc.musl-x86_64.so.1:/lib/libc.musl-x86_64.so.1:ro"
)

args=(
  --detach
  --net=host
  --name=${docker_container_name}
)

labels=(
  "kxd.k8s.io/infra=true"
  "kxd.k8s.io/svc-proxy-for=\"$*\""
)

for v in "${sys_volumes[@]}" ; do args+=("--volume=${v}") ; done
for l in "${labels[@]}" ; do args+=("--label=${l}") ; done

printf "Will run the following command that requires root privileges, please enter your password below\n%s\n" "${darwin_ifconfig_cmd}"
${darwin_ifconfig_cmd}

docker run "${args[@]}" "${image_name}:shell" "${docker_slirp_proxy_cmd}"
