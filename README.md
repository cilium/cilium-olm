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
CUE is not very easy to use on its own, so a simple opinionated utility called [`kuegen`][kuegen] is being used to execute CUE templates and write out YAML files.

The CUE templates can be found in [`config/operator/`](config/operator/). `kuegen` is invoked with [a helper script](scripts/generate-configs.sh), which is typically driven by `make`, e.g. `make generate.configs.v1.9.6`.

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
[kuegen]: https://github.com/errordeveloper/kuegen

## Common Workflows

To work with this repository, a maintainer should have Docker with latest version of [`buildx` plugin](https://github.com/docker/buildx) installed, as well as Go toolchain.

To install `kuegen`, `imagine` and `opm` utilities to `GOPATH`, run:

```
(cd tools ; go install github.com/errordeveloper/imagine github.com/errordeveloper/kuegen github.com/operator-framework/operator-registry/cmd/opm)
```

### Publishing a Cilium release

All releases and release candidates should be added to this repo for testing, albeit only latest stable release should be published in the RedHat Catalog.

To prepare a new Cilium release candidate, manually trigger the [`prepare-test-rc` GitHub Actions workflow](https://github.com/cilium/cilium-olm/actions/workflows/prepare-test-rc.yaml), passing in the version number (e.g. `1.12.3`).

The workflow will take care of the following:

- Create the RC branch by running `scripts/add-release.sh ${VERSION}`, which will:
  - Create new dirs `{operator,manifests,bundles}/cilium.v{VERSION}` populate these with generated configs.
  - Download the Helm chart tarball for `${VERSION}` and unpack it.
  - Create a commit that has all the changes.
  - Push it to a new branch `rc/v${VERSION}`.
- Linting / building / validating the RC branch.
  - This pushes an image with the corresponding commit SHA to `quay.io/cilium/cilium-olm`, which can be used for manual testing.
- Set up an OpenShift cluster on AWS using the manifests from the RC branch, tweaked as required in order to run conformance tests, and run the conformance tests.
  - In case of failure, the OpenShift log bundle is uploaded as an artifact for manual inspection.

At this point, you can open a PR from the RC branch and iterate on it, re-triggering tests via the `prepare-test-rc` workflow as necessary.

After the RC branch is merged into `master`, run [the `publish` GitHub Actions workflow](https://github.com/cilium/cilium-olm/actions/workflows/publish.yaml) on the `master` branch, passing in the version number (e.g. `1.12.3`).

After the workflow run is completed, login to [RedHat Partner Connect][] and click "Publish" on the image (once the vulnerability scanning is done).

Once the image is published, use the fork at [cilium/certified-operators](https://github.com/cilium/certified-operators), by adding the
new manifests to the appropriately named new directory under `operators/cilium` (`operators/cilium/v1.10.0`, for example) in a branch.
Before committing your changes make sure to modify the `image` reference in the `manifests/cilium.clusterserviceversion.yaml` so that
the sha256 tag of the image is used (rather than the semantic tag).

Create a new PR against the official [OpenShift certified operators repository](https://github.com/redhat-openshift-ecosystem/certified-operators).
If the CI tests against the PR fails and you can't figure out why you can file a support case on [RedHat Partner Connect][]. After the CI tests
succeed the PR will automatically be merged and the version will be officially certified.

#### Manual testing

To manually test a release candidate (e.g. you want to iterate on manifests on a live cluster, without using the automation), you need to [create an Openshift cluster and install the new operator](https://docs.cilium.io/en/latest/installation/k8s-install-openshift-okd/#k8s-install-openshift-okd), by modifying the OLM manifests to use the CI generated images.
Also, make sure that the CiliumConfig ([v1.12.0](https://github.com/cilium/cilium-olm/blob/master/manifests/cilium.v1.12.0/cluster-network-07-cilium-ciliumconfig.yaml), for example) has the following values (this ensures that the K8s networking e2e tests will pass):

```yaml
apiVersion: cilium.io/v1alpha1
kind: CiliumConfig
metadata:
  name: cilium
  namespace: cilium
spec:
  debug:
    enabled: true
  k8s:
    requireIPv4PodCIDR: true
  pprof:
    enabled: true
  logSystemLoad: true
  bpf:
    preallocateMaps: true
  etcd:
    leaseTTL: 30s
  ipv4:
    enabled: true
  ipv6:
    enabled: true
  identityChangeGracePeriod: 0s
  ipam:
    mode: "cluster-pool"
    operator:
      clusterPoolIPv4PodCIDR: "10.128.0.0/14"
      clusterPoolIPv4MaskSize: "23"
  nativeRoutingCIDR: "10.128.0.0/14"
  endpointRoutes: {enabled: true}
  kubeProxyReplacement: "probe"
  clusterHealthPort: 9940
  tunnelPort: 4789
  cni:
    binPath: "/var/lib/cni/bin"
    confPath: "/var/run/multus/cni/net.d"
    chainingMode: portMap
  prometheus:
    serviceMonitor: {enabled: false}
  hubble:
    tls: {enabled: false}
```

Run the Network Conformance tests [according to these instructions](https://redhat-connect.gitbook.io/openshift-badges/badges/container-network-interface-cni/workflow/running-the-cni-tests) to ensure that Cilium functions as expected. There are 3 expected failures in these conformance tests. They are:

```
NetworkPolicy between server and client should not allow access by TCP when a policy specifies only SCTP
NetworkPolicy between server and client should allow egress access to server in CIDR block
NetworkPolicy between server and client should ensure an IP overlapping both IPBlock.CIDR and IPBlock.Except is allowed
```
Once these conformance tests are passed it is safe to assume that the generated manifests are working correctly.

## Updating helm-operator base image

TODO

## Changing configuration

TODO

## Getting Help

If you need help, post a thread looking for support in the #launchpad channel (CC @errordeveloper).
