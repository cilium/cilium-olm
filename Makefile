# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

GOBIN = $(shell go env GOPATH)/bin

IMAGINE ?= $(GOBIN)/imagine
KG ?= $(GOBIN)/kg

OPM ?= $(GOBIN)/opm

ifeq ($(MAKER_CONTAINER),true)
  IMAGINE=imagine
  KG=kg
endif

REGISTRY ?= docker.io/cilium

imagine_push_or_export = --export
ifeq ($(PUSH),true)
imagine_push_or_export = --push
endif

include Makefile.releases

.buildx_builder:
	# see https://github.com/docker/buildx/issues/308
	mkdir -p ../.buildx
	docker buildx create --platform linux/amd64 > $@

images.operator-base: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./operator/base \
		--name cilium-olm-base \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./operator/base \
		--name cilium-olm-base \
		--registry $(REGISTRY) \
		> image-cilium-olm-base.tag

images.operator.%: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./operator/cilium.v$(cilium_version) \
		--name cilium-olm.v$(cilium_version) \
		--args ciliumVersion=$(cilium_version) \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./operator/cilium.v$(cilium_version) \
		--name cilium-olm.v$(cilium_version) \
		--registry $(REGISTRY) \
		> image-cilium-olm.v$(cilium_version).tag

images.operator-bundle.%: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./bundles/cilium.v$(cilium_version) \
		--dockerfile ../Dockerfile \
		--name cilium-olm-bundle.v$(cilium_version) \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./bundles/cilium.v$(cilium_version) \
		--name cilium-olm-bundle.v$(cilium_version) \
		--registry $(REGISTRY) \
		> image-cilium-olm-bundle.v$(cilium_version).tag

generate.bundles.%:
	./generate-bundle.sh "$$(cat image-cilium-olm.v$(cilium_version).tag)" $(cilium_version)

validate.bundles.%:
	$(OPM) alpha bundle validate --tag $$(cat image-cilium-olm-bundle.v$(cilium_version).tag)
