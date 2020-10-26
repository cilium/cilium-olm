#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

operator_image="${1}"
cilium_version="${2}"

rm -rf "manifests/cilium.v${cilium_version}" "bundles/cilium.v${cilium_version}"

cat > config/operator/instances.json << EOF
{
  "instances": [
    {
      "output": "manifests/cilium.v${cilium_version}/cluster-network-06-cilium-%s.yaml",
      "parameters": {
        "image": "${operator_image}",
        "test": false,
        "csv": false,
        "ciliumVersion": "${cilium_version}"
      }
    },
    {
      "output": "bundles/cilium.v${cilium_version}/manifests/cilium-olm.csv.yaml",
      "parameters": {
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

cp ./config/crd/cilium.io_cilumconfigs.yaml "manifests/cilium.v${cilium_version}/cluster-network-03-cilium-ciliumconfigs-crd.yaml"

cat > "manifests/cilium.v${cilium_version}/cluster-network-04-cilium-namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cilium
  annotations:
    # node selector is required to make cilium-operator run on control plane nodes
    openshift.io/node-selector: ""
  labels:
    name: cilium
    # run level sets priority for Cilium to be deployed prior to other components
    openshift.io/run-level: "0"
    # enable cluster logging for Cilium namespace
    openshift.io/cluster-logging: "true"
    # enable cluster monitoring for Cilium namespace
    openshift.io/cluster-monitoring: "true"
EOF

case "${cilium_version}" in
  1.8.*)
    ciliumconfig="ciliumconfig.v1.8.yaml"
    ;;
  1.9.*)
    ciliumconfig="ciliumconfig.v1.9.yaml"
    ;;
  *)
  echo "ciliumconfig example missing for ${cilium_version}"
  exit 1
  ;;
esac

cp "${ciliumconfig}" "manifests/cilium.v${cilium_version}/cluster-network-05-cilium-ciliumconfig.yaml"

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
