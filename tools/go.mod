module github.com/cilium/cilium-olm

go 1.15

require (
	github.com/containerd/containerd v1.5.7 // indirect
	github.com/errordeveloper/imagine v0.0.0-20201215192748-b3494e82bc78
	github.com/errordeveloper/kuegen v0.4.0
	github.com/go-openapi/validate v0.19.5 // indirect
	github.com/golangplus/bytes v0.0.0-20160111154220-45c989fe5450 // indirect
	github.com/golangplus/fmt v0.0.0-20150411045040-2a5d6d7d2995 // indirect
	github.com/mikefarah/yq/v2 v2.4.1 // indirect
	github.com/operator-framework/operator-registry v1.19.1
	github.com/xlab/handysort v0.0.0-20150421192137-fb3537ed64a1 // indirect
	sigs.k8s.io/controller-tools v0.6.0 // indirect
	sigs.k8s.io/kustomize v2.0.3+incompatible // indirect
	sigs.k8s.io/structured-merge-diff/v3 v3.0.0 // indirect
	vbom.ml/util v0.0.0-20160121211510-db5cfe13f5cc // indirect

)

// based on https://github.com/docker/buildx/blob/v0.5.1/go.mod#L61-L68

replace (
	// operator-registry: https://github.com/operator-framework/operator-registry/blob/v1.15.3/go.mod#L26
	github.com/golang/protobuf => github.com/golang/protobuf v1.4.2
	// protobuf: corresponds to containerd (through buildkit)
	// github.com/golang/protobuf => github.com/golang/protobuf v1.3.5
	github.com/jaguilar/vt100 => github.com/tonistiigi/vt100 v0.0.0-20190402012908-ad4c4a574305

	// genproto: corresponds to containerd (through buildkit)
	google.golang.org/genproto => google.golang.org/genproto v0.0.0-20200224152610-e50cd9704f63
)
