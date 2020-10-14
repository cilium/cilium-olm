package operator

_leaderElectionRules: [
	{
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"patch",
			"delete",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
			"patch",
		]
	},
]

_helmOperatorClusterRules: [
	{
		// Operator needs to get namespaces so that it can read namespaces to ensure they exist
		apiGroups: [
			"",
		]
		resources: [
			"namespaces",
		]
		verbs: [
			"get",
		]
	}, {
		// Operator needs to manage Helm release secrets
		apiGroups: [
			"",
		]
		resources: [
			"secrets",
		]
		verbs: [
			"*",
		]
	}, {
		// Operator needs to create events on CRs about things happening during reconciliation
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
		]
	}, {
		// Operator needs to manage ciliumconfigs
		apiGroups: [
			"cilium.io",
		]
		resources: [
			"ciliumconfigs",
			"ciliumconfigs/status",
		]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		// Operator needs to manage cilium RBAC resources
		apiGroups: [
			"rbac.authorization.k8s.io/v1",
		]
		resources: [
			"clusterroles",
			"clusterrolebindings",
		]
		verbs: [
			"*",
		]
		resourceNames: [
			"cilium",
			"cilium-operator",
		]
	},
]

_helmOperatorRules: [
	{ // TODO: reduce this to just the resource Cilium chart ships
		apiGroups: [
			"",
		]
		resources: [
			"*",
		]
		verbs: [
			"*",
		]
	}
]

_roles: [
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name:      "leader-election"
			namespace: parameters.namespace
		}
		rules: _leaderElectionRules
	},
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name:      constants.name
			namespace: parameters.namespace
		}
		rules: _helmOperatorRules
	},
]

_roleBindings: [
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      "leader-election"
			namespace: parameters.namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "Role"
			name:     "leader-election"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      constants.name
			namespace: parameters.namespace
		}]

	},
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      constants.name
			namespace: parameters.namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "Role"
			name:     constants.name
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      constants.name
			namespace: parameters.namespace
		}]

	},
]

_clusterRoles: [
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(parameters.namespace)-\(constants.name)"
		rules: _helmOperatorClusterRules
	},
]

_clusterRoleBindings: [
	{
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: "\(parameters.namespace)-\(constants.name)"
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "\(parameters.namespace)-\(constants.name)"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      constants.name
			namespace: parameters.namespace
		}]
	},
]
