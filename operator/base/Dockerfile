# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

FROM quay.io/operator-framework/helm-operator:v1.0.1

# Required Licenses
COPY LICENSE /licenses/LICENSE.cilium-olm

# Required OpenShift Labels
LABEL name="Cilium" \
      vendor="Isovalent" \
      release="1" \
      summary="Cilium OLM operator"

ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
WORKDIR ${HOME}
