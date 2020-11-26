#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
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
chart_dir="operator/cilium.v${cilium_version}"

root_dir="$(git rev-parse --show-toplevel)"

cd "${root_dir}"

if ! [ -f image-cilium-olm-base.tag ] ; then
  echo "run 'make images.operator-base' first"
  exit 2
fi

if ! mkdir "${chart_dir}" 2> /dev/null ; then
  echo "version ${cilium_version} has already been added"
  echo "if you want to re-add it, you can to run 'rm -rf ${chart_dir}' and edit 'Makefile.releases'"
  exit 3
fi

curl --silent --fail --show-error --location "${chart_url}" --output /tmp/cilium-chart.tgz

tar -xf /tmp/cilium-chart.tgz -C "${chart_dir}"

rm -f /tmp/cilium-chart.tgz

cp LICENSE "${chart_dir}/LICENSE"

cat > "${chart_dir}/watches.yaml" << EOF
# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

- group: cilium.io
  version: v1alpha1
  kind: CiliumConfig
  chart: helm-charts/cilium
EOF

cat > "${chart_dir}/Dockerfile" << EOF
# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

FROM quay.io/operator-framework/helm-operator:v1.2.0

# Required Licenses
COPY LICENSE /licenses/LICENSE.cilium-olm

# Required OpenShift Labels
LABEL name="Cilium" \\
      version="v${cilium_version}" \\
      vendor="Isovalent" \\
      release="1" \\
      summary="Cilium OLM operator" \\
      description="This operator mamaged Cilium installation and it is OLM-compliant"

ENV HOME=/opt/helm
COPY watches.yaml \${HOME}/watches.yaml
WORKDIR \${HOME}

COPY cilium \${HOME}/helm-charts/cilium
EOF

cat >> Makefile.releases << EOF

# Cilium v${cilium_version}

images.all: images.operator.v${cilium_version} images.operator-bundle.v${cilium_version}

images.operator.all: images.operator.v${cilium_version}
images.operator-bundle.all: images.operator-bundle.v${cilium_version}

images.operator.v${cilium_version} images.operator-bundle.v${cilium_version} generate.bundles.v${cilium_version} validate.bundles.v${cilium_version}: cilium_version=${cilium_version}

images.operator-bundle.v${cilium_version}: generate.bundles.v${cilium_version}
validate.bundles.v${cilium_version}: images.operator-bundle.v${cilium_version}
EOF

git add Makefile.releases "${chart_dir}"

git commit --message "Add Cilium v${cilium_version}"

make "images.operator.v${cilium_version}"
make "generate.bundles.v${cilium_version}"
git add "manifests/cilium.v${cilium_version}" "bundles/cilium.v${cilium_version}"

git commit --amend --all --message "Add Cilium v${cilium_version}"
