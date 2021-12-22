#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

cilium_version="${1}"
operator_tag="image-cilium-olm-v${cilium_version}.tag"

root_dir="$(git rev-parse --show-toplevel)"

case "${cilium_version}" in
  *-rc*)
    operator_image="$(head -1 "${operator_tag}")"
    ;;
  *)
    operator_image="registry.connect.redhat.com/isovalent/cilium-olm:$(head -1 "${operator_tag}" | cut -d ':' -f 2)"
    ;;
esac

cd "${root_dir}"

rm -rf "manifests/cilium.v${cilium_version}" "bundles/cilium.v${cilium_version}/manifests" "bundles/cilium.v${cilium_version}/metadata" "bundles/cilium.v${cilium_version}/tests"


# Modify operator and bundle for offline deployment
function get_image() {
    local image="$1"
    local tag="$2"
    docker pull "$image:$tag" > /dev/null
    echo "$image""@$(docker inspect "$image:$tag" | jq -r '.[0].RepoDigests[0]' | cut -d'@' -f2)"
}

values_file="operator/cilium.v${cilium_version}/cilium/values.yaml"

cilium_image="$(yq e '.image.repository' "$values_file")@$(yq e '.image.digest' "$values_file")"
hubble_relay_image="$(yq e '.hubble.relay.image.repository' "$values_file")@$(yq e '.hubble.relay.image.digest' "$values_file")"
operator_image="$(yq e '.operator.image.repository' "$values_file")@$(yq e '.operator.image.genericDigest' "$values_file")"
preflight_image="$(yq e '.preflight.image.repository' "$values_file")@$(yq e '.preflight.image.digest' "$values_file")"
clustermesh_image="$(yq e '.clustermesh.apiserver.image.repository' "$values_file")@$(yq e '.clustermesh.apiserver.image.digest' "$values_file")"

# These images don't have their digests in the values file, we need to retrieve them
certgen_image="$(get_image "$(yq e '.certgen.image.repository' "$values_file")" "$(yq e '.certgen.image.tag' "$values_file")")"
hubble_ui_be_image="$(get_image "$(yq e '.hubble.ui.backend.image.repository' "$values_file")" "$(yq e '.hubble.ui.backend.image.tag' "$values_file")")"
hubble_ui_fe_image="$(get_image "$(yq e '.hubble.ui.frontend.image.repository' "$values_file")" "$(yq e '.hubble.ui.frontend.image.tag' "$values_file")")"
hubble_ui_proxy_image="$(get_image "$(yq e '.hubble.ui.proxy.image.repository' "$values_file")" "$(yq e '.hubble.ui.proxy.image.tag' "$values_file")")"
etcd_operator_image="$(get_image "$(yq e '.etcd.image.repository' "$values_file")" "$(yq e '.etcd.image.tag' "$values_file")")"
nodeinit_image="$(get_image "$(yq e '.nodeinit.image.repository' "$values_file")" "$(yq e '.nodeinit.image.tag' "$values_file")")"
clustermesh_etcd_image="$(get_image "$(yq e '.clustermesh.apiserver.etcd.image.repository' "$values_file")" "$(yq e '.clustermesh.apiserver.etcd.image.tag' "$values_file")")"

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
      configVersionSuffix: "${operator_tag:-}"
      ciliumVersion: "${cilium_version}"
      ciliumImage: "${cilium_image}"
      hubbleRelayImage: "${hubble_relay_image}"
      operatorImage: "${operator_image}"
      preflightImage: "${preflight_image}"
      clustermeshImage: "${clustermesh_image}"
      certgenImage: "${certgen_image}"
      hubbleUIBackendImage: "${hubble_ui_be_image}"
      hubbleUIFrontendImage: "${hubble_ui_fe_image}"
      hubbleUIProxyImage: "${hubble_ui_proxy_image}"
      etcdOperatorImage: "${etcd_operator_image}"
      nodeInitImage: "${nodeinit_image}"
      clustermeshEtcdImage: "${clustermesh_etcd_image}"
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
      configVersionSuffix: "${operator_tag:-}"
      ciliumImage: "${cilium_image}"
      hubbleRelayImage: "${hubble_relay_image}"
      operatorImage: "${operator_image}"
      preflightImage: "${preflight_image}"
      clustermeshImage: "${clustermesh_image}"
      certgenImage: "${certgen_image}"
      hubbleUIBackendImage: "${hubble_ui_be_image}"
      hubbleUIFrontendImage: "${hubble_ui_fe_image}"
      hubbleUIProxyImage: "${hubble_ui_proxy_image}"
      etcdOperatorImage: "${etcd_operator_image}"
      nodeInitImage: "${nodeinit_image}"
      clustermeshEtcdImage: "${clustermesh_etcd_image}"
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

kuegen -input-directory ./config/operator -output-directory ./

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
  1.11.*)
    ciliumconfig="ciliumconfig.v1.11.yaml"
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
