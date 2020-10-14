GOBIN = $(shell go env GOPATH)/bin

IMAGINE ?= $(GOBIN)/imagine
KG ?= $(GOBIN)/kg

ifeq ($(MAKER_CONTAINER),true)
  IMAGINE=imagine
  KG=kg
endif

REGISTRY ?= docker.io/cilium

imagine_push_or_export = --export
ifeq ($(PUSH),true)
imagine_push_or_export = --push
endif

images.all: images.operator.v1.8.5 images.operator-bundle.v1.8.5

images.operator.v1.8.5 images.operator-bundle.v1.8.5 generate.bundles.v1.8.5: cilium_version=1.8.5

images.operator-bundle.v1.8.5: generate.bundles.v1.8.5

.buildx_builder:
	# see https://github.com/docker/buildx/issues/308
	mkdir -p ../.buildx
	docker buildx create --platform linux/amd64 > $@

images.operator.%: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./ \
		--name cilium-olm.v$(cilium_version) \
		--args ciliumVersion=$(cilium_version) \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./ \
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

generate.bundles.%: images.operator.%
	./generate-bundle.sh "$$(cat image-cilium-olm.v$(cilium_version).tag)" $(cilium_version)
