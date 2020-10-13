#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

operator_image="${1}"
use_namespace="${NAMESPACE:-cilium-olm}"

cat > config/operator/instances.json << EOF
{
  "instances": [
    {
      "output": "operator-test.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": true
      }
    },
    {
      "output": "operator.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": false
      }
    }
  ]
}
EOF


if [ -n "${GOPATH+x}" ] ; then
  export PATH="${PATH}:${GOPATH}/bin"
fi

kg -input-directory ./config/operator -output-directory ./config/operator
