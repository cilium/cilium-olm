FROM quay.io/operator-framework/helm-operator:v1.0.1

ARG ciliumVersion

# Required OpenShift Labels
LABEL name="Cilium" \
      vendor="Isovalent" \
      version="v${ciliumVersion}" \
      release="1" \
      summary="Cilium OLM operator"

# Required Licenses
COPY LICENSE /licenses/LICENSE.Cilium

ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
COPY helm-charts/cilium.v${ciliumVersion}  ${HOME}/helm-charts
WORKDIR ${HOME}
