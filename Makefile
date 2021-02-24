# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

REGISTRY ?= quay.io/cilium

RHCONNECT_CERTIFICATION_REGISTRY_PREFIX_FOR_CILIUM_OLM_OPERATOR_IMAGE := scan.connect.redhat.com/ospid-104ec1da-384c-4d7c-bd27-9dbfd8377f5b
RHCONNECT_CERTIFICATION_REGISTRY_PREFIX_FOR_CILIUM_OLM_OPERATOR_BUNDLE_IMAGE := scan.connect.redhat.com/ospid-e31ac831-7e72-42bb-baf9-f392ef7ea622

PUSH ?= false

GOBIN = $(shell go env GOPATH)/bin

IMAGINE ?= $(GOBIN)/imagine
KG ?= $(GOBIN)/kg

OPM ?= $(GOBIN)/opm

ifeq ($(MAKER_CONTAINER),true)
  IMAGINE=imagine
  KG=kg
endif

images.all: lint
	@echo "Current image tags:"
	@cat *.tag

images.%.all:
	@echo "Current image tags:"
	@cat *.tag

include Makefile.releases

lint:
	scripts/lint.sh

.buildx_builder:
	docker buildx create --platform linux/amd64 > $@

images.operator.v%: .buildx_builder
	$(IMAGINE) build \
		--builder=$$(cat .buildx_builder) \
		--base=./operator/cilium.v$(cilium_version) \
		--name=cilium-olm \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--registry=$(RHCONNECT_CERTIFICATION_REGISTRY_PREFIX_FOR_CILIUM_OLM_OPERATOR_IMAGE) \
		--push=$(PUSH)
	$(IMAGINE) image \
		--base=./operator/cilium.v$(cilium_version) \
		--name=cilium-olm \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--registry=$(RHCONNECT_CERTIFICATION_REGISTRY_PREFIX_FOR_CILIUM_OLM_OPERATOR_IMAGE) \
		> image-cilium-olm-v$(cilium_version).tag

images.operator-bundle.v%: .buildx_builder
	$(IMAGINE) build \
		--builder=$$(cat .buildx_builder) \
		--base=./bundles/cilium.v$(cilium_version) \
		--dockerfile=../Dockerfile \
		--name=cilium-olm-metadata \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--registry=$(RHCONNECT_CERTIFICATION_REGISTRY_PREFIX_FOR_CILIUM_OLM_OPERATOR_BUNDLE_IMAGE) \
		--push=$(PUSH)
	$(IMAGINE) image \
		--base=./bundles/cilium.v$(cilium_version) \
		--name=cilium-olm-metadata \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--registry=$(RHCONNECT_CERTIFICATION_REGISTRY_PREFIX_FOR_CILIUM_OLM_OPERATOR_BUNDLE_IMAGE) \
		> image-cilium-olm-metadata-v$(cilium_version).tag

generate.configs.v%:
	scripts/generate-configs.sh "image-cilium-olm-v$(cilium_version).tag" "$(cilium_version)"

validate.bundles.v%:
	$(OPM) alpha bundle validate --tag "$$(cat image-cilium-olm-metadata-v$(cilium_version).tag | head -1)"
	operator-sdk bundle validate "$$(cat image-cilium-olm-metadata-v$(cilium_version).tag | head -1)"
	operator-sdk scorecard "$$(cat image-cilium-olm-metadata-v$(cilium_version).tag | head -1)"
