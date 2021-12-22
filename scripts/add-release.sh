#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset
set -x

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 1.9.1'"
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

cilium_version="${1}"

chart_url="https://github.com/cilium/charts/raw/master/cilium-${cilium_version}.tgz"
operator_dir="operator/cilium.v${cilium_version}"
bundle_dir="bundles/cilium.v${cilium_version}"

root_dir="$(git rev-parse --show-toplevel)"

cd "${root_dir}"

if ! mkdir "${operator_dir}" 2> /dev/null ; then
  echo "version ${cilium_version} has already been added"
  echo "if you want to re-add it, you can to run 'rm -rf ${operator_dir}' and edit 'Makefile.releases'"
  exit 3
fi

curl --silent --fail --show-error --location "${chart_url}" --output /tmp/cilium-chart.tgz

tar -xf /tmp/cilium-chart.tgz -C "${operator_dir}"

rm -f /tmp/cilium-chart.tgz

cp LICENSE "${operator_dir}/LICENSE"

cat > "${operator_dir}/watches.yaml" << EOF
# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

- group: cilium.io
  version: v1alpha1
  kind: CiliumConfig
  chart: helm-charts/cilium
EOF

cat > "${operator_dir}/Dockerfile" << EOF
# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

FROM quay.io/operator-framework/helm-operator:v1.5.0

# This make the build time-variant, but there is not easy
# way around this yet, as the helm-operator image does
# often have outdatated packages
# (For a potneial solution see https://github.com/errordeveloper/imagine/issues/27)
USER root
RUN microdnf update

# Required Licenses
COPY LICENSE /licenses/LICENSE.cilium-olm

# Required OpenShift Labels
LABEL name="Cilium" \\
      version="v${cilium_version}" \\
      vendor="Isovalent" \\
      release="1" \\
      summary="Cilium OLM operator" \\
      description="This operator mamaged Cilium installation and it is OLM-compliant"

USER helm
ENV HOME=/opt/helm
COPY watches.yaml \${HOME}/watches.yaml
WORKDIR \${HOME}

COPY cilium \${HOME}/helm-charts/cilium
EOF

mkdir -p "${bundle_dir}"
cat > "${bundle_dir}/Dockerfile" << EOF
# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

FROM scratch

LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=cilium
LABEL operators.operatorframework.io.bundle.channels.v1=stable
LABEL operators.operatorframework.io.bundle.channel.default.v1=stable
LABEL operators.operatorframework.io.metrics.builder=operator-sdk-v1.0.1
LABEL operators.operatorframework.io.metrics.mediatype.v1=metrics+v1
LABEL operators.operatorframework.io.metrics.project_layout=helm.sdk.operatorframework.io/v1

# NB: setting "v4.5" here implies that versions 4.5 and above are supported,
# it's possible to use "=v4.5" syntax to specify exactly one version, and
# it's also possible to say "v4.5-v4.7" to specify a range of version;
# for the timebeing it's assumed that all versions should be supportable,
# if that proves wrong using range syntax maybe desirable.
LABEL com.redhat.openshift.versions="v4.5"
LABEL com.redhat.delivery.operator.bundle=true
LABEL com.redhat.delivery.backport=true

COPY /manifests /manifests
COPY /metadata /metadata
COPY /tests /tests
EOF

cat >> Makefile.releases << EOF

# Cilium v${cilium_version}

images.all: images.operator.v${cilium_version} images.operator-bundle.v${cilium_version}

images.operator.all: images.operator.v${cilium_version}
images.operator-bundle.all: images.operator-bundle.v${cilium_version}
generate.configs.all: generate.configs.v${cilium_version}

images.operator.v${cilium_version} images.operator-bundle.v${cilium_version} generate.configs.v${cilium_version} validate.bundles.v${cilium_version}: cilium_version=${cilium_version}

images.operator-bundle.v${cilium_version}: generate.configs.v${cilium_version}
validate.bundles.v${cilium_version}: images.operator-bundle.v${cilium_version}
EOF

# Modify operator and bundle for offline deployment
function get_image() {
    local image="$1"
    local tag="$2"
    docker pull "$image:$tag" > /dev/null
    echo "$image""@$(docker inspect "$image:$tag" | jq -r '.[0].RepoDigests[0]' | cut -d'@' -f2)"
}

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
yq e -i '.image.override = "'"${cilium_image}"'" |
   .hubble.relay.image.override = "'"${hubble_relay_image}"'" |
   .operator.image.override = "'"${operator_image}"'" |
   .preflight.image.override = "'"${preflight_image}"'" |
   .clustermesh.apiserver.image.override = "'"${clustermesh_image}"'" |
   .certgen.image.override = "'"${certgen_image}"'" |
   .hubble.ui.backend.image.override = "'"${hubble_ui_be_image}"'" |
   .hubble.ui.frontend.image.override = "'"${hubble_ui_fe_image}"'" |
   .hubble.ui.proxy.image.override = "'"${hubble_ui_proxy_image}"'" |
   .etcd.image.override = "'"${etcd_operator_image}"'" |
   .nodeinit.image.override = "'"${nodeinit_image}"'" |
   .clustermesh.apiserver.etcd.image.override = "'"${clustermesh_etcd_image}"'"' "$values_file"

template_dir="${operator_dir}/cilium/templates"

# certgen
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.certgen.image.override }}"|' "${template_dir}/_clustermesh-apiserver-generate-certs-job-spec.tpl"
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.certgen.image.override }}"|' "${template_dir}/_hubble-generate-certs-job-spec.tpl"

# cilium
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.image.override }}"|' "${template_dir}/cilium-agent-daemonset.yaml"

# etcd-operator
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.etcd.image.override }}"|' "${template_dir}/cilium-etcd-operator-deployment.yaml"

# nodeinit
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.nodeinit.image.override }}"|' "${template_dir}/cilium-nodeinit-daemonset.yaml"

# operator
# IMPORTANT: For now we are replacing all possible image values with the generic
# operator. This assumes that no one will want to do an offline deployment in one
# of the public clouds, which makes sense, but could be potentially a problem for
# hybrid clouds in the future (e.g. Anthos, etc).
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.operator.image.override }}"|' "${template_dir}/cilium-operator-deployment.yaml"

# preflight
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.preflight.image.override }}"|' "${template_dir}/cilium-preflight-daemonset.yaml"
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.preflight.image.override }}"|' "${template_dir}/cilium-preflight-deployment.yaml"

# clustermesh
sed -i 's|^\([[:blank:]]*\)image: {{ \.Values\.clustermesh\.apiserver\.etcd.*$|\1image: "{{ .Values.clustermesh.apiserver.etcd.image.override }}"|' "${template_dir}/clustermesh-apiserver-deployment.yaml"
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.clustermesh\.apiserver\.image.*$|\1image: "{{ .Values.clustermesh.apiserver.image.override }}"|' "${template_dir}/clustermesh-apiserver-deployment.yaml"

# hubble-relay
sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.hubble.relay.image.override }}"|' "${template_dir}/hubble-relay-deployment.yaml"

# hubble-ui
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.frontend.*$|\1image: "{{ .Values.hubble.ui.frontend.image.override }}"|' "${template_dir}/hubble-ui-deployment.yaml"
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.backend.*$|\1image: "{{ .Values.hubble.ui.backend.image.override }}"|' "${template_dir}/hubble-ui-deployment.yaml"
sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.proxy.*$|\1image: "{{ .Values.hubble.ui.proxy.image.override }}"|' "${template_dir}/hubble-ui-deployment.yaml"

# update watches file
# shellcheck disable=SC2016
yq e -i '.[0].overrideValues["image.override"] = "$RELATED_IMAGE_CILIUM" |
   .[0].overrideValues["hubble.relay.image.override"] = "$RELATED_IMAGE_HUBBLE_RELAY" |
   .[0].overrideValues["operator.image.override"] = "$RELATED_IMAGE_OPERATOR" |
   .[0].overrideValues["preflight.image.override"] = "$RELATED_IMAGE_PREFLIGHT" |
   .[0].overrideValues["clustermesh.apiserver.image.override"] = "$RELATED_IMAGE_CLUSTERMESH" |
   .[0].overrideValues["certgen.image.override"] = "$RELATED_IMAGE_CERTGEN" |
   .[0].overrideValues["hubble.ui.backend.image.override"] = "$RELATED_IMAGE_HUBBLE_UI_BE" |
   .[0].overrideValues["hubble.ui.frontend.image.override"] = "$RELATED_IMAGE_HUBBLE_UI_FE" |
   .[0].overrideValues["hubble.ui.proxy.image.override"] = "$RELATED_IMAGE_HUBBLE_UI_PROXY" |
   .[0].overrideValues["etcd.image.override"] = "$RELATED_IMAGE_ETCD_OPERATOR" |
   .[0].overrideValues["nodeinit.image.override"] = "$RELATED_IMAGE_NODEINIT" |
   .[0].overrideValues["clustermesh.apiserver.etcd.image.override"] = "$RELATED_IMAGE_CLUSTERMESH_ETCD"' "${operator_dir}/watches.yaml"
## end offline modifications

git add Makefile.releases "${operator_dir}" "${bundle_dir}"

git commit --message "Add Cilium v${cilium_version}"

make "images.operator.v${cilium_version}" WITHOUT_TAG_SUFFIX=true
make "generate.configs.v${cilium_version}" WITHOUT_TAG_SUFFIX=true

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

git add "manifests/cilium.v${cilium_version}" "${bundle_dir}"

git commit --amend --all --message "Add Cilium v${cilium_version}"
