#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

cilium_version="${2}"

root_dir="$(git rev-parse --show-toplevel)"

case "${cilium_version}" in
  *-rc*)
    operator_image="$(head -1 "${1}")"
    ;;
  *)
    operator_image="registry.connect.redhat.com/isovalent/cilium-olm:$(head -1 "${1}" | cut -d ':' -f 2)"
    ;;
esac

cd "${root_dir}"

rm -rf "manifests/cilium.v${cilium_version}" "bundles/cilium.v${cilium_version}/manifests" "bundles/cilium.v${cilium_version}/metadata" "bundles/cilium.v${cilium_version}/tests"

generate_instaces_cue() {
cat << EOF
package operator

instances: [
  {
    output: "manifests/cilium.v${cilium_version}/cluster-network-06-cilium-%s.yaml"
    parameters: {
      image: "${operator_image}"
      test: false
      onlyCSV: false
      ciliumVersion: "${cilium_version}"
      configVersionSuffix: "${1:-}"
    }
  },
  {
    output: "bundles/cilium.v${cilium_version}/manifests/cilium-olm.csv.yaml"
    parameters: {
      namespace: "placeholder"
      image: "${operator_image}"
      test: false
      onlyCSV: true
      ciliumVersion: "${cilium_version}"
      configVersionSuffix: "${1:-}"
    }
  },
]
EOF
}

combined_hash_sources() {
  generate_instaces_cue
  cat "bundles/cilium.v${cilium_version}/Dockerfile"
  cat "config/operator/operator.cue"
  cat "config/operator/rbac.cue"
  cat "config/operator/olm.cue"
}

config_version_suffix_hash="$(combined_hash_sources | git hash-object --stdin)"

generate_instaces_cue "${config_version_suffix_hash:0:7}" > config/operator/instances.cue

if [ -n "${GOPATH+x}" ] ; then
  export PATH="${PATH}:${GOPATH}/bin"
fi

kg -input-directory ./config/operator -output-directory ./

cp ./config/crd/cilium.io_cilumconfigs.yaml "manifests/cilium.v${cilium_version}/cluster-network-03-cilium-ciliumconfigs-crd.yaml"

case "${cilium_version}" in
  1.8.*)
    ciliumconfig="ciliumconfig.v1.8.yaml"
    ;;
  1.9.*)
    ciliumconfig="ciliumconfig.v1.9.yaml"
    ;;
  1.10.*)
    ciliumconfig="ciliumconfig.v1.10.yaml"
    ;;
  *)
  echo "ciliumconfig example missing for ${cilium_version}"
  exit 1
  ;;
esac

cp "${ciliumconfig}" "manifests/cilium.v${cilium_version}/cluster-network-07-cilium-ciliumconfig.yaml"

cp ./config/crd/cilium.io_cilumconfigs.yaml "bundles/cilium.v${cilium_version}/manifests/ciliumconfigs.crd.yaml"
mkdir -p "bundles/cilium.v${cilium_version}/metadata"
cat > "bundles/cilium.v${cilium_version}/metadata/annotations.yaml" << EOF
annotations:
  operators.operatorframework.io.bundle.channel.default.v1: "stable"
  operators.operatorframework.io.bundle.channels.v1: stable
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: cilium
  operators.operatorframework.io.metrics.builder: operator-sdk-v1.0.1
  operators.operatorframework.io.metrics.mediatype.v1: metrics+v1
  operators.operatorframework.io.metrics.project_layout: helm.sdk.operatorframework.io/v1
  operators.operatorframework.io.test.config.v1: tests/scorecard/
  operators.operatorframework.io.test.mediatype.v1: scorecard+v1
EOF

mkdir -p "bundles/cilium.v${cilium_version}/tests/scorecard"
cp scorecard-config.yaml "bundles/cilium.v${cilium_version}/tests/scorecard/config.yaml"
