#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

operator_image="${1}"
cilium_version="${2}"
use_namespace="${NAMESPACE:-cilium-olm}"

cat > config/operator/instances.json << EOF
{
  "instances": [
    {
      "output": "operator-test.v${cilium_version}.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": true,
        "csv": false,
        "ciliumVersion": "${cilium_version}"
      }
    },
    {
      "output": "operator.v${cilium_version}.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": false,
        "csv": false,
        "ciliumVersion": "${cilium_version}"
      }
    },
    {
      "output": "bundles/cilium.v${cilium_version}/manifests/cilium-olm.csv.yaml",
      "parameters": {
        "namespace": "${use_namespace}",
        "image": "${operator_image}",
        "test": false,
        "csv": true,
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
cp ./config/crd/cilium.io_cilumconfigs.yaml "bundles/cilium.v${cilium_version}/manifests/ciliumconfigs.crd.yaml"

mkdir -p "bundles/cilium.v${cilium_version}/metadata"
cat > "bundles/cilium.v${cilium_version}/metadata/annotations.yaml" << EOF
annotations:
  operators.operatorframework.io.bundle.channel.default.v1: "stable"
  operators.operatorframework.io.bundle.channels.v1: stable
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: cilium-openshift-operator
  operators.operatorframework.io.metrics.builder: operator-sdk-v1.0.1
  operators.operatorframework.io.metrics.mediatype.v1: metrics+v1
  operators.operatorframework.io.metrics.project_layout: helm.sdk.operatorframework.io/v1
  operators.operatorframework.io.test.config.v1: tests/scorecard/
  operators.operatorframework.io.test.mediatype.v1: scorecard+v1
EOF
