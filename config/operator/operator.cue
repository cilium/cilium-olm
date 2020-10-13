package operator

constants: {
	name:    "cilium-olm"
}

_workload: {
	metadata: {
		name: "\(constants.name)"
		labels: name: "\(constants.name)"
		namespace: "\(parameters.namespace)"
	}
	spec: _workloadSpec
}

_workloadSpec: {
	template: {
		metadata: labels: name: "\(constants.name)"
		spec: {
			serviceAccount: "\(constants.name)"
			volumes: [
				{
					name: "tmp"
					emptyDir: {}
				},
				{
					name: "cert"
					secret: {
						optional:    true
						defaultMode: 420
						secretName:  "\(constants.name)-webhook-server-cert"
					}
				},
			]
			containers: [{
				name:    "operator"
				command: _command
				image:   "\(parameters.image)"
				ports: [{
					containerPort: 9443
					name:          "https"
					protocol:      "TCP"
				}]
				volumeMounts: [
					{
						name:      "tmp"
						mountPath: "/tmp"
					},
					{
						mountPath: "/run/cert"
						name:      "cert"
						readOnly:  true
					},
				]
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
		selector: matchLabels: name: "\(constants.name)"
		template: {
			metadata: labels: name: "\(constants.name)"
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
		name: "\(constants.name)"
		labels: name: "\(constants.name)"
		namespace: "\(parameters.namespace)"
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
		labels: name: "\(constants.name)"
	}
	roleRef: {
		kind:     "ClusterRole"
		name:     "\(constants.name)"
		apiGroup: "rbac.authorization.k8s.io"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "\(constants.name)"
		namespace: "\(parameters.namespace)"
	}]
}

_core_items: [
	_serviceAccount,
	_workload,
	_service,
	_rbac_ClusterRoleBinding,
]

#WorkloadTemplate: {
	kind:       "List"
	apiVersion: "v1"
	items: _core_items
}

#WorkloadParameters: {
	namespace:      string
	image:          string
	test:           bool
}

parameters: #WorkloadParameters
template:   #WorkloadTemplate
