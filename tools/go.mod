module github.com/cilium/cilium-olm

go 1.15

require (
	github.com/errordeveloper/imagine v0.0.0-20201215192748-b3494e82bc78
	github.com/errordeveloper/kue v0.3.1-0.20201014144342-209ddfde99c5
	github.com/operator-framework/operator-registry v1.14.3
	sigs.k8s.io/controller-tools v0.4.0 // indirect
)

// based on https://github.com/docker/buildx/blob/v0.5.1/go.mod#L61-L68

replace (
	// protobuf: corresponds to containerd (through buildkit)
	github.com/golang/protobuf => github.com/golang/protobuf v1.3.5
	github.com/jaguilar/vt100 => github.com/tonistiigi/vt100 v0.0.0-20190402012908-ad4c4a574305

	// genproto: corresponds to containerd (through buildkit)
	google.golang.org/genproto => google.golang.org/genproto v0.0.0-20200224152610-e50cd9704f63
)
