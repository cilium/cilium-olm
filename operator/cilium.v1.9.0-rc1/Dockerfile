FROM docker.io/errordeveloper/cilium-olm-base:52ce5914e19d7d81c74b0ca4ab9dea1c6b5caef8-dev

ARG ciliumVersion=1.9.0-rc1

# Required OpenShift Labels
LABEL version="v${ciliumVersion}"

COPY cilium ${HOME}/helm-charts/cilium
