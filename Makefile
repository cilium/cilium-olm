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

.buildx_builder:
	# see https://github.com/docker/buildx/issues/308
	mkdir -p ../.buildx
	docker buildx create --platform linux/amd64 > $@

images.all: images.operator-v1.8 images.operator-bundle-v1.8

images.operator-v1.8: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./ \
		--name cilium-olm-v1.8 \
		--args ciliumVersion=1.8.5,ciliumRelease=1.8 \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./ \
		--name cilium-olm-v1.8 \
		--registry $(REGISTRY) \
		> image-cilium-olm-v1.8.tag

images.operator-bundle-v1.8: .buildx_builder
	$(IMAGINE) build \
		--builder $$(cat .buildx_builder) \
		--base ./bundles \
		--name cilium-olm-bundle-v1.8 \
		--args ciliumVersion=1.8.5,ciliumRelease=1.8 \
		--registry $(REGISTRY) \
		$(imagine_push_or_export) \
		--cleanup
	$(IMAGINE) image \
		--base ./bundles \
		--name cilium-olm-bundle-v1.8 \
		--registry $(REGISTRY) \
		> image-cilium-olm-bundle-v1.8.tag

generate.bundles:
	./generate-bundle.sh "$$(cat image-cilium-olm-v1.8.tag)" 1.8 1.8.5
