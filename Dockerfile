FROM quay.io/operator-framework/helm-operator:v1.0.1

# Required OpenShift Labels
LABEL name="Cilium Operator for OpenShift" \
      vendor="Cilium Project" \
      version="v0.0.1" \
      release="1" \
      summary="This operator will install Cilium."

# Required Licenses
COPY LICENSE /licenses/LICENSE.Cilium

ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
COPY helm-charts  ${HOME}/helm-charts
WORKDIR ${HOME}
