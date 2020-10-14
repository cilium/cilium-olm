package operator

constants: {
	name: "cilium-olm"
}

_workload: {
	metadata: {
		name: constants.name
		labels: name: constants.name
		namespace: parameters.namespace
	}
	spec: _workloadSpec
}

_workloadSpec: {
	template: {
		metadata: labels: name: constants.name
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
		selector: matchLabels: name: constants.name
		template: {
			metadata: labels: name: constants.name
		}
	}
	_command: [
		"/usr/local/bin/helm-operator",
		"run",
		"--watches-file=watches.yaml",
		"--enable-leader-election",
		"--leader-election-id=cilium-olm",
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
	metadata: {
		name: constants.name
		labels: name: constants.name
		namespace: parameters.namespace
	}
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
	metadata: {
		name: constants.name
		labels: name: constants.name
		namespace: parameters.namespace
	}
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
		name: "\(parameters.namespace)-\(constants.name)"
		labels: name: constants.name
	}
	roleRef: {
		kind:     "ClusterRole"
		name:     constants.name
		apiGroup: "rbac.authorization.k8s.io"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      constants.name
		namespace: parameters.namespace
	}]
}

namespace: [...{}]

if parameters.namespace != "kube-system" {
	namespace: [{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			name: parameters.namespace
			annotations: {
				// node selector is required to make cilium-operator run on control plane nodes
				"openshift.io/node-selector": ""
			}
			labels: {
				name: parameters.namespace
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
] + _rbac_items

#WorkloadTemplate: {
	kind:       "List"
	apiVersion: "v1"
	items:      _core_items
}

#CSVWorkloadTemplate: {
	apiVersion: "operators.coreos.com/v1alpha1"
	kind:       "ClusterServiceVersion"
	metadata: {
		annotations: capabilities: "Basic Install"
		name:      "cilium.v\(parameters.ciliumVersion)"
		namespace: "placeholder"
	}
	spec: {
		apiservicedefinitions: {}
		customresourcedefinitions: owned: [{
			kind:    "CiliumConfig"
			name:    "ciliumconfigs.cilium.io"
			version: "v1alpha1"
		}]
		displayName: "Cilium"
		description: "Cilium - eBPF-based Networking, Security, and Observability"
		icon: [{
			base64data: ""
			mediatype:  ""
		}]
		install: {
			spec: {
				deployments: [{
					name: constants.name
					spec: _workloadSpec
				}]
				permissions: [{
					rules:              _leaderElectionRules + _helmOperatorRules
					serviceAccountName: constants.name
				}]
				clusterPermissions: [{
					rules:              _helmOperatorClusterRules
					serviceAccountName: constants.name
				}]
			}
			strategy: "deployment"
		}
		installModes: [{
			supported: false
			type:      "OwnNamespace"
		}, {
			supported: false
			type:      "SingleNamespace"
		}, {
			supported: false
			type:      "MultiNamespace"
		}, {
			supported: true
			type:      "AllNamespaces"
		}]
		keywords: [
			"networking",
			"security",
			"observability",
			"eBPF",
		]
		links: [{
			name: "Cilium Homepage"
			url:  "https://cilium.io/"
		}]
		maturity: "stable"
		provider: name: "Isovalent"
		version: parameters.ciliumVersion
	}

}

#WorkloadParameters: {
	namespace:     string
	image:         string
	test:          bool
	ciliumVersion: string
	csv:           bool
}

parameters: #WorkloadParameters

template: {}

if parameters.csv {
	template: #CSVWorkloadTemplate
}

if !parameters.csv {
	template: #WorkloadTemplate
}
