// Copyright 2017-2020 Authors of Cilium
// SPDX-License-Identifier: Apache-2.0

package operator

constants: {
	name:      "cilium-olm"
	namespace: "cilium"
}

_commonMetadata: {
	name: constants.name
	labels: name: constants.name
	namespace: constants.namespace
}

_workload: {
	metadata: _commonMetadata
	spec:     _workloadSpec
}

_workloadSpec: {
	template: {
		metadata: labels: _commonMetadata.labels
		spec: {
			hostNetwork: true
			tolerations: [{operator: "Exists"}]
			serviceAccount: constants.name
			volumes: [{
				name: "tmp"
				emptyDir: {}
			}]
			containers: [{
				name:    "operator"
				command: _command
				image:   parameters.image
				ports: [{
					containerPort: 9443
					name:          "https"
					protocol:      "TCP"
				}]
				env: [{
					name:  "WATCH_NAMESPACE"
					value: "cilium"
				}]
				volumeMounts: [{
					name:      "tmp"
					mountPath: "/tmp"
				}]
				resources: {
					limits: {
						cpu:    "100m"
						memory: "100Mi"
					}
					requests: {
						cpu:    "100m"
						memory: "100Mi"
					}
				}
			}]
			terminationGracePeriodSeconds: 10
		}
	}
}

_command: [...string]

if !parameters.test {
	_workload: {
		apiVersion: "apps/v1"
		kind:       "Deployment"
	}
	_workloadSpec: {
		replicas: 1
		selector: matchLabels: _commonMetadata.labels
		template: {
			metadata: labels: _commonMetadata.labels
		}
	}
	_command: [
		"/usr/local/bin/helm-operator",
		"run",
		"--watches-file=watches.yaml",
		"--enable-leader-election",
		"--leader-election-id=cilium-olm",
		"--zap-devel",
	]
}

if parameters.test {
	_workload: {
		apiVersion: "batch/v1"
		kind:       "Job"
	}

	_workloadSpec: {
		backoffLimit: 0
		template: spec: restartPolicy: "Never"
	}
	_command: [
		"test.\(constants.name)-controllers",
		"-test.v",
		"-test.timeout=25m", // this must be kept greater then the sum of all polling timeouts
	]
}

_serviceAccount: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata:   _commonMetadata
}

_serviceSelector: {
	if !parameters.test {
		name: constants.name
	}
	if parameters.test {
		"job-name": constants.name
	}
}

_service: {
	apiVersion: "v1"
	kind:       "Service"
	metadata:   _commonMetadata
	spec: {
		selector: _serviceSelector
		ports: [{
			name:       "https"
			port:       443
			targetPort: 9443
		}]
	}
}

_rbac_ClusterRoleBinding: {
	apiVersion: "rbac.authorization.k8s.io/v1beta1"
	kind:       "ClusterRoleBinding"
	metadata: {
		name:   "\(constants.namespace)-\(constants.name)"
		labels: _commonMetadata.labels
	}
	roleRef: {
		kind:     "ClusterRole"
		name:     constants.name
		apiGroup: "rbac.authorization.k8s.io"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      constants.name
		namespace: constants.namespace
	}]
}

namespace: [...{}]

if constants.namespace != "kube-system" {
	namespace: [{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			name: constants.namespace
			annotations: {
				// node selector is required to make cilium-operator run on control plane nodes
				"openshift.io/node-selector": ""
			}
			labels: {
				name: constants.namespace
				// run level sets priority for Cilium to be deployed prior to other components
				"openshift.io/run-level": "0"
				// enable cluster logging for Cilium namespace
				"openshift.io/cluster-logging": "true"
				// enable cluster monitoring for Cilium namespace
				"openshift.io/cluster-monitoring": "true"
			}
		}
	}]
}
_rbac_items: _roles + _roleBindings + _clusterRoles + _clusterRoleBindings

_core_items: namespace + [
		_serviceAccount,
		_workload,
		_service,
] + _rbac_items + _olm_items

#WorkloadTemplate: {
	kind:       "List"
	apiVersion: "v1"
	items:      _core_items
}

#WorkloadParameters: {
	image:         string
	test:          bool
	ciliumVersion: string
	onlyCSV:       bool
}

parameters: #WorkloadParameters

template: {}

if parameters.onlyCSV {
	template: #CSVWorkloadTemplate
}

if !parameters.onlyCSV {
	template: #WorkloadTemplate
}
