module github.com/cilium/cilium-olm

go 1.15

require (
	github.com/errordeveloper/imagine v0.0.0-20201013191633-45183892735e
	github.com/errordeveloper/kue v0.3.1-0.20201014144342-209ddfde99c5
	github.com/operator-framework/operator-registry v1.14.3
	sigs.k8s.io/controller-tools v0.4.0 // indirect
)

replace github.com/containerd/containerd => github.com/containerd/containerd v1.3.1-0.20200227195959-4d242818bf55

replace github.com/docker/docker => github.com/docker/docker v1.4.2-0.20200227233006-38f52c9fec82

replace github.com/jaguilar/vt100 => github.com/tonistiigi/vt100 v0.0.0-20190402012908-ad4c4a574305
