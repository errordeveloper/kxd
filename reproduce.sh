#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

export shell_image_tag="shell@sha256:6a1e8744fbb3afb627a07cde58151718606011deef008f09f6e5d50ee142bff4"
export kubelet_image_tag="kubelet@sha256:005e4e8e4bd4071ce803c173c4cf8536046578a415e63533247f748917555f3b"

./start.sh --only-reset
./start.sh

cat sockshop.yaml | docker exec --interactive kxd-kubelet kubectl create --filename -
