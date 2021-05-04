#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 1.9.1'"
  exit 1
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
cat > "${operator_dir}/Dockerfile" << EOF
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

LABEL com.redhat.openshift.versions="v4.5,v4.6,v4.7"
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

git add Makefile.releases "${operator_dir}" "${bundle_dir}"

git commit --message "Add Cilium v${cilium_version}"

make "images.operator.v${cilium_version}" WITHOUT_TAG_SUFFIX=true
make "generate.configs.v${cilium_version}" WITHOUT_TAG_SUFFIX=true

git add "manifests/cilium.v${cilium_version}" "${bundle_dir}"

git commit --amend --all --message "Add Cilium v${cilium_version}"
