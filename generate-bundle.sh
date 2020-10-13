#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

operator_image="${1}"
cilium_release="${2}"
cilium_version="${3}"
use_namespace="${NAMESPACE:-cilium-olm}"

cat > config/operator/instances.json << EOF
{
  "instances": [
    {
      "output": "operator-test-v${cilium_release}.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": true,
        "csv": false,
        "ciliumRelease": "${cilium_release}",
        "ciliumVersion": "${cilium_version}"
      }
    },
    {
      "output": "operator-v${cilium_release}.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": false,
        "csv": false,
        "ciliumRelease": "${cilium_release}",
        "ciliumVersion": "${cilium_version}"
      }
    },
    {
      "output": "bundles/cilium-v${cilium_release}/manifests/cilium-olm.csv.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": false,
        "csv": true,
        "ciliumRelease": "${cilium_release}",
        "ciliumVersion": "${cilium_version}"
      }
    }
  ]
}
EOF


if [ -n "${GOPATH+x}" ] ; then
  export PATH="${PATH}:${GOPATH}/bin"
fi

kg -input-directory ./config/operator -output-directory ./
cp ./config/crd/cilium.io_cilumconfigs.yaml "bundles/cilium-v${cilium_release}/manifests/ciliumconfigs.crd.yaml"
