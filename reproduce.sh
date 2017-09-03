#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

./start.sh --only-reset
./start.sh

cat sockshop.yaml | docker exec --interactive kxd-kubelet kubectl create --filename -
