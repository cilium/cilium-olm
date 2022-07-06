# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

REGISTRY ?= docker.io/spc35771

WITHOUT_TAG_SUFFIX ?= false
PUSH ?= true

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
		--args http_proxy=http://snapp-mirror:TmfBZb68qjGGF6feBdqX@mirror-fra-1.snappcloud.io:30128 \
		--args https_proxy=http://snapp-mirror:TmfBZb68qjGGF6feBdqX@mirror-fra-1.snappcloud.io:30128 \
		--args no_proxy=localhost,127.0.0.1,.svc,.cluster,.local,.snappcloud.io,.staging-snappcloud.io \
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

generate.configs.v%:
	scripts/generate-configs.sh "image-cilium-olm-v$(cilium_version).tag" "$(cilium_version)"
