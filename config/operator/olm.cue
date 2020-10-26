// Copyright 2017-2020 Authors of Cilium
// SPDX-License-Identifier: Apache-2.0

package operator

_olm_items: [
	{
		apiVersion: "operators.coreos.com/v1alpha2"
		kind:       "OperatorGroup"
		metadata: {
			name:      constants.name
			namespace: constants.namespace
		}
		spec: targetNamespaces: [constants.namespace]
	},
	{
		apiVersion: "operators.coreos.com/v1alpha1"
		kind:       "Subscription"
		metadata: {
			name:      constants.name
			namespace: constants.namespace
		}
		spec: {
			channel:             "stable"
			name:                constants.name
			startingCSV:         "cilium.v\(parameters.ciliumVersion)"
			installPlanApproval: "Automatic"
			source:              "certified-operators"
			sourceNamespace:     "openshift-marketplace"
		}
	},
        #CSVWorkloadTemplate,
]

#CSVWorkloadTemplate: {
	apiVersion: "operators.coreos.com/v1alpha1"
	kind:       "ClusterServiceVersion"
	metadata: {
		annotations: capabilities: "Basic Install"
		name:      "cilium.v\(parameters.ciliumVersion)"
		namespace: constants.namespace
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
					rules:              _helmOperatorClusterRules + _ciliumClusterRules
					serviceAccountName: constants.name
				}]
			}
			strategy: "deployment"
		}
		installModes: [{
			supported: true
			type:      "OwnNamespace"
		}, {
			supported: true
			type:      "SingleNamespace"
		}, {
			supported: false
			type:      "MultiNamespace"
		}, {
			supported: false
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
