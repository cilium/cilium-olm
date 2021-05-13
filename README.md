# Cilium OLM

> NOTE: this documentation is for Cilium maintainers, the user guide for OpenShift is part of [Cilium documentation][okd-gsg]

This repository contains Cilium packaging for OpenShift, which is centred around [Operator Lifecycle Management APIs (OLM)][olm].

## Key Components

On OpenShift Cilium has to be installed by an installer operator in order to comply with RedHat certification requirements.

To install Cilium on OpenShift, users must have the following:

- standard Kubernetes manifests for Cilium installer operator - RBAC, Deployment, Service ...etc
- OpenShift-specific manifests for the installer operator - Subscription, OperatorGroup, ClusterServiceVersion

### Installer operator

The installer operator is based on RedHat's helm-operator, which was chosen for expediance. In the future it's expected that Cilium will have a general-purpose installation operator that will support OpenShift as well as other platforms.

The operator is configured using a [`CiliumConfig` CRD](config/crd/cilium.io_cilumconfigs.yaml). The operator watches a single `CiliumConfig` CR in `cilium` namespace. The CRD is a simple object that hold Helm values.

Default CR specs for each release are sourced from top-level manifest (e.g. [`ciliumconfig.v1.10.yaml`](ciliumconfig.v1.10.yaml)), a copy is made for each release in `manifests/` (e.g. [`manifests/cilium.v1.9.6/cluster-network-07-cilium-ciliumconfig.yaml`](manifests/cilium.v1.9.6/cluster-network-07-cilium-ciliumconfig.yaml).

### Cofiguration source code

Since configuration for OLM was fairly complex to manage in static YAML format, it was written in [CUE](http://cuelang.org/).
CUE is not very easy to use on its own, so a simple opinionated utility called [`kg`][kg] is being used to execute CUE templates and write out YAML files.

The CUE templates can be found in [`config/operator/`](config/operator/). `kg` is invoked with [a helper script](scripts/generate-configs.sh), which is typically driven by `make`, e.g. `make generate.configs.v1.9.6`.

### Generated configuration

Configuration that is generated from CUE templates will get used in variety of different ways:

- contents of `manifests/` are used during installation in user guides as well as CI
- contents of `bundles/` are used for building metadata bundle images

### Images

The installation is reliant on operator application image, it is currently based on RedHat's helm-operator.

For the purposes of certfication, the operator application image is accompanied by a metadata bundle image. Both images have to undergo certification tests in RedHat Partner Connect registry, maintainers should be able to obtain access to this registry.

Image definitions for the operator application and the metadata bundle can be found under [`operator/`](operator) [`bundles/`](bundles). Images are mapped to Cilium releases.

Images are built using [GitHub Actions][] and pushed to [quay.io/cilium/cilium-olm](http://quay.io/cilium/cilium-olm) and [quay.io/cilium/cilium-olm-metadata](http://quay.io/cilium/cilium-olm-metadata). [`imagine`](https://github.com/errordeveloper/imagine) utility is being used to drive the builds.

The metadata bundle image contains just YAML files and no software as such, however it's a crucial part of OLM and when it comes to certification it's what is being tested the most. It's possible to install the operator based on this image, however it's not something that is recommended for Cilium, as Cilium should be installed during cluster bootstrap as otherwise users will have to carry out live network migration.

## Useful Links

- [RedHat Partner Connect][] (maintainers will be able to obtain access)
- [operator-courier](https://github.com/operator-framework/operator-courier) - tool used in certification tests
- [operator-test-playbooks](https://github.com/redhat-operator-ecosystem/operator-test-playbooks) - ansible playbooks used to drive certication test (see [#37](https://github.com/cilium/cilium-olm/issues/37))
- [Cilium OLM (operator) in RedHat Catalog](https://catalog.redhat.com/software/containers/isovalent/cilium-olm/5ff7310e293738682042b1dd)
- [Cilium OLM (bundle) in RedHat Catalog](https://catalog.redhat.com/software/containers/isovalent/cilium-olm-metadata/603fd17f69aea331dde395e4)

[RedHat Partner Connect]: https://connect.redhat.com
[rhpc-projects]: https://connect.redhat.com/projects
[GitHub Actions]: ../../actions/workflows/ci.yaml

[okd-gsg]: https://docs.cilium.io/en/v1.10/gettingstarted/k8s-install-openshift-okd
[olm]: https://docs.openshift.com/container-platform/4.7/operators/understanding/olm/olm-understanding-olm.html
[kg]: https://github.com/errordeveloper/kue/blob/209ddfde99c57e533eae750aa7aaa16c0efeab04/cmd/kg/main.go

## Common Workflows

To work with this repository, a maintainer should have Docker with latest version of [`buildx` plugin](https://github.com/docker/buildx) installed, as well as Go toolchain.

To install `kg`, `imagine` and `opm` utilities to `GOPATH`, run:

```
(cd tools ; go install github.com/errordeveloper/imagine github.com/errordeveloper/kue/cmd/kg github.com/operator-framework/operator-registry/cmd/opm)
```

### Adding Cilium release

All releases and release candidates should be added to this repo for testing, albeit only latest stable release should be published in the RedHat Catalog.

To add a Cilium release, run:

```
scripts/add-release.sh 1.10.0
```

This will do the following:

- create new dirs `{operator,manifests,bundles}/cilium.v1.10.0` populate these with generated configs
- download Helm chart tarball and unpack it to 
- create a local commit that has all the changes that can be pushed to the repo

Now push changes to a branch and open a PR. Once changes are on the master branch of this repo, new images will be built in [GitHub Actions][].

Next, images need to be copied from Quay to RedHat Partner Connect registry. This is a two-step process.

For this you will need to access [RedHat Partner Connect][] registry and obtain credential for each of the images. Export the following environment variables using the credentials from RedHat Partner Connect:

- `export RHPC_PASSWORD_FOR_OLM_OPERATOR_IMAGE="_____"`
- `export RHPC_PASSWORD_FOR_OLM_METADATA_IMAGE="_____"`
- `export RHPC_USERNAME_FOR_PUBLISHED_IMAGES="_____"`
- `export RHPC_PASSWORD_FOR_PUBLISHED_IMAGES="_____"`

The first step is to "promote" the operator application image from Quay to RedHat Partner Connect, for this run:

```
scripts/push-to-scan-1-olm-operator.sh 1.10.0
```

Access OLM operator project in [RedHat Partner Connect][rhcp-projects] portal and observe the scan results for the newly pushed image. Upon successful scan, publish the image. Do not create `latest` tag when publishing.

All releases and release candidates should be published at this stage, but the metadata bundles will not yet be published as that will be handled in the second step below.

It can take some time, but often just a few hours. Sometimes the image doesn't show up in UI right away, you will need to check back every couple of hours.

If an image scan fails, file an issue in this repository and work to address the issue. Once the chages are in master and [GitHub Actions][] build finished, re-run `scripts/push-to-scan-1-olm-operator.sh` and monitor the scan results.

Now it's time for the second step. Once operator application image has passed certification scan successfully and had been published, the metadata bundle can be pushed RedHat Partner Connect Registry also. To "promote" the metadata bundle run:

```
scripts/push-to-scan-2-olm-metadata.sh 1.10.0
```

Next, access the OLM bundle project in [RedHat Partner Connect][rhcp-projects] portal and observe scan results. This often takes much longer, as it results in much more testing, i.e. a test cluster gets created to run the tests. By comparison it's not just a couple of hours, but more likely 6 hours or so.

Any scan failures should be logged as issues and addressed. Once the chages are in master and [GitHub Actions][] build finished, re-run `scripts/push-to-scan-2-olm-metadata.sh` and monitor the scan results.

If the certification tests pass, and if the bundle is for latest stable release and not a release candidate or older release, publish the images for the release. In the [RedHat Partner Connect] UI, two images will show up: `*-cert-*` and `*-mktpl-*`. Only `*-cert-*` images should be published. Do not create `latest` tag when publishing.

## Updating helm-operator base image

TODO

## Changing configuration

TODO

## Getting Help

If you need help, post a thread looking for support in the #launchpad channel (CC @errordeveloper).
