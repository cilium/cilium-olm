GOBIN = $(shell go env GOPATH)/bin

IMAGINE ?= $(GOBIN)/imagine

ifeq ($(MAKER_CONTAINER),true)
  IMAGINE=imagine
endif

REGISTRY ?= docker.io/cilium

imagine_push_or_export = --export
ifeq ($(PUSH),true)
imagine_push_or_export = --push
endif

.buildx_builder:
	# see https://github.com/docker/buildx/issues/308
	mkdir -p ../.buildx
	docker buildx create --platform linux/amd64 > $@

images.all: images.operator

images.operator: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./ \
		--name cilium-olm \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./ \
		--name cilium-olm \
		--registry $(REGISTRY) \
		> image-cilium-olm.tag

images.operator-bundle: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./ \
		--name cilium-olm-bundle \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./ \
		--name cilium-olm-bundle \
		--registry $(REGISTRY) \
		> image-cilium-olm-bundle.tag

manifests.generate:
	./generate-manifests.sh "$$(cat image-cilium-olm.tag)"
