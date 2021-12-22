# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

REGISTRY ?= quay.io/cilium

WITHOUT_TAG_SUFFIX ?= false
PUSH ?= false

GOBIN = $(shell go env GOPATH)/bin

IMAGINE ?= $(GOBIN)/imagine

OPM ?= $(GOBIN)/opm

ifeq ($(MAKER_CONTAINER),true)
  IMAGINE=imagine
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
		--without-tag-suffix=$(WITHOUT_TAG_SUFFIX) \
		--push=$(PUSH)
	$(IMAGINE) image \
		--base=./operator/cilium.v$(cilium_version) \
		--name=cilium-olm \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--without-tag-suffix=$(WITHOUT_TAG_SUFFIX) \
		> image-cilium-olm-v$(cilium_version).tag

images.operator-bundle.v%: .buildx_builder
	$(IMAGINE) build \
		--builder=$$(cat .buildx_builder) \
		--base=./bundles/cilium.v$(cilium_version) \
		--name=cilium-olm-metadata \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--without-tag-suffix=$(WITHOUT_TAG_SUFFIX) \
		--push=$(PUSH)
	$(IMAGINE) image \
		--base=./bundles/cilium.v$(cilium_version) \
		--name=cilium-olm-metadata \
		--custom-tag-suffix=v$(cilium_version) \
		--registry=$(REGISTRY) \
		--without-tag-suffix=$(WITHOUT_TAG_SUFFIX) \
		> image-cilium-olm-metadata-v$(cilium_version).tag

generate.configs.v%:
	scripts/generate-configs.sh "$(cilium_version)"

validate.bundles.v%:
	$(OPM) alpha bundle validate --tag "$$(cat image-cilium-olm-metadata-v$(cilium_version).tag | head -1)"
	operator-sdk bundle validate "$$(cat image-cilium-olm-metadata-v$(cilium_version).tag | head -1)"
	operator-sdk scorecard "$$(cat image-cilium-olm-metadata-v$(cilium_version).tag | head -1)"
