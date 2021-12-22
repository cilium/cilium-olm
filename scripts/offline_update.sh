#! /bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 2 ] ; then
  echo "$0 supports exactly 2 arguments"
  echo "example: '$0 ./operator/cilium.v1.10.4 ./bundles/cilium.v1.10.4'"
  exit 1
fi

if ! command -v yq &> /dev/null ; then
    echo "\"yq\" must be installed to create an offline \
    deployment. https://github.com/mikefarah/yq/releases"
fi

if ! command -v jq &> /dev/null ; then
    echo "\"jq\" must be installed to create an offline \
    deployment."
fi

function get_image() {
    local image="$1"
    local tag="$2"
    docker pull "$image:$tag" > /dev/null
    echo "$image""@$(docker inspect "$image:$tag" | jq -r '.[0].RepoDigests[0]' | cut -d'@' -f2)"
}

operator_dir="${1}"
bundle_dir="${2}"
values_file="${operator_dir}/cilium/values.yaml"

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

# update values file
yq e -i '.image.image = "'"${cilium_image}"'" |
   .hubble.relay.image.image = "'"${hubble_relay_image}"'" |
   .operator.image.image = "'"${operator_image}"'" |
   .preflight.image.image = "'"${preflight_image}"'" |
   .clustermesh.apiserver.image.image = "'"${clustermesh_image}"'" |
   .certgen.image.image = "'"${certgen_image}"'" |
   .hubble.ui.backend.image.image = "'"${hubble_ui_be_image}"'" |
   .hubble.ui.frontend.image.image = "'"${hubble_ui_fe_image}"'" |
   .hubble.ui.proxy.image.image = "'"${hubble_ui_proxy_image}"'" |
   .etcd.image.image = "'"${etcd_operator_image}"'" |
   .nodeinit.image.image = "'"${nodeinit_image}"'" |
   .clustermesh.apiserver.etcd.image.image = "'"${clustermesh_etcd_image}"'"' "$values_file"

template_dir="${operator_dir}/cilium/templates"

# certgen
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.certgen.image.image }}"|' "${template_dir}/_clustermesh-apiserver-generate-certs-job-spec.tpl"
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.certgen.image.image }}"|' "${template_dir}/_hubble-generate-certs-job-spec.tpl"

# cilium
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.image.image }}"|' "${template_dir}/cilium-agent-daemonset.yaml"

# etcd-operator
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.etcd.image.image }}"|' "${template_dir}/cilium-etcd-operator-deployment.yaml"

# nodeinit
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.nodeinit.image.image }}"|' "${template_dir}/cilium-nodeinit-daemonset.yaml"

# operator
# IMPORTANT: For now we are replacing all possible image values with the generic
# operator. This assumes that no one will want to do an offline deployment in one
# of the public clouds, which makes sense, but could be potentially a problem for
# hybrid clouds in the future (e.g. Anthos, etc).
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.operator.image.image }}"|' "${template_dir}/cilium-operator-deployment.yaml"

# preflight
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.preflight.image.image }}"|' "${template_dir}/cilium-preflight-daemonset.yaml"
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.preflight.image.image }}"|' "${template_dir}/cilium-preflight-deployment.yaml"

# clustermesh
sed -i 's|^\([[:blank:]]*\)image: {{ \.Values\.clustermesh\.apiserver\.etcd.*$|\1image: "{{ .Values.clustermesh.apiserver.etcd.image.image }}"|' "${template_dir}/clustermesh-apiserver-deployment.yaml"
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.clustermesh\.apiserver\.image.*$|\1image: "{{ .Values.clustermesh.apiserver.image.image }}"|' "${template_dir}/clustermesh-apiserver-deployment.yaml"

# hubble-relay
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.hubble.relay.image.image }}"|' "${template_dir}/hubble-relay-deployment.yaml"

# hubble-ui
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.frontend.*$|\1image: "{{ .Values.hubble.ui.frontend.image.image }}"|' "${template_dir}/hubble-ui-deployment.yaml"
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.backend.*$|\1image: "{{ .Values.hubble.ui.backend.image.image }}"|' "${template_dir}/hubble-ui-deployment.yaml"
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.proxy.*$|\1image: "{{ .Values.hubble.ui.proxy.image.image }}"|' "${template_dir}/hubble-ui-deployment.yaml"

# update watches file
cat <<EOF >> "${operator_dir}/watches.yaml"
overrideValues:
  image.image: \$RELATED_IMAGE_CILIUM
  hubble.relay.image.image = \$RELATED_IMAGE_HUBBLE_RELAY
  operator.image.image = \$RELATED_IMAGE_OPERATOR
  preflight.image.image = \$RELATED_IMAGE_PREFLIGHT
  clustermesh.apiserver.image.image = \$RELATED_IMAGE_CLUSTERMESH
  certgen.image.image = \$RELATED_IMAGE_CERTGEN
  hubble.ui.backend.image.image = \$RELATED_IMAGE_HUBBLE_UI_BE
  hubble.ui.frontend.image.image = \$RELATED_IMAGE_HUBBLE_UI_FE
  hubble.ui.proxy.image.image = \$RELATED_IMAGE_HUBBLE_UI_PROXY
  etcd.image.image = \$RELATED_IMAGE_ETCD_OPERATOR
  nodeinit.image.image = \$RELATED_IMAGE_NODEINIT
  clustermesh.apiserver.etcd.image.image = \$RELATED_IMAGE_CLUSTERMESH_ETCD
EOF

# modify bundle
yq e -i '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[1].name = "RELATED_IMAGE_CILIUM" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[1].value = "'"${cilium_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[2].name = "RELATED_IMAGE_HUBBLE_RELAY" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[2].value = "'"${hubble_relay_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[3].name = "RELATED_IMAGE_OPERATOR" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[3].value = "'"${operator_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[4].name = "RELATED_IMAGE_PREFLIGHT" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[4].value = "'"${preflight_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[5].name = "RELATED_IMAGE_CLUSTERMESH" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[5].value = "'"${clustermesh_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[6].name = "RELATED_IMAGE_CERTGEN" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[6].value = "'"${certgen_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[7].name = "RELATED_IMAGE_HUBBLE_UI_BE" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[7].value = "'"${hubble_ui_be_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[8].name = "RELATED_IMAGE_HUBBLE_UI_FE" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[8].value = "'"${hubble_ui_fe_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[9].name = "RELATED_IMAGE_HUBBLE_UI_PROXY" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[9].value = "'"${hubble_ui_proxy_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[10].name = "RELATED_IMAGE_ETCD_OPERATOR" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[10].value = "'"${etcd_operator_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[11].name = "RELATED_IMAGE_NODEINIT" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[11].value = "'"${nodeinit_image}"'" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[11].name = "RELATED_IMAGE_CLUSTERMESH_ETCD" |
   .spec.install.spec.deployments[0].spec.template.spec.containers[0].env[11].value = "'"${clustermesh_etcd_image}"'"' "${bundle_dir}/manifests/cilium-olm.csv.yaml"
