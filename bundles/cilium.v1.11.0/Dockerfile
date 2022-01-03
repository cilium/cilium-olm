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
