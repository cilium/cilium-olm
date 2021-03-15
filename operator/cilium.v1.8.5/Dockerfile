# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

FROM quay.io/operator-framework/helm-operator:v1.5.0

# Required Licenses
COPY LICENSE /licenses/LICENSE.cilium-olm

# Required OpenShift Labels
LABEL name="Cilium" \
      version="v1.8.5" \
      vendor="Isovalent" \
      release="1" \
      summary="Cilium OLM operator" \
      description="This operator mamaged Cilium installation and it is OLM-compliant"

ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
WORKDIR ${HOME}

COPY cilium ${HOME}/helm-charts/cilium
