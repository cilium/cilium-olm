#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

MAKER_IMAGE="${MAKER_IMAGE:-quay.io/cilium/image-maker:9e2e7ad1a524cf714d491945e90fe650125cd60a}"

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 1.9.1'"
  exit 1
fi

if [ -z "${RHPC_PASSWORD_FOR_OLM_METADATA_IMAGE+x}" ] ; then
  echo "RHPC_PASSWORD_FOR_OLM_METADATA_IMAGE environment variable must be set in order to push to RedHat Partner Connect registry"
  exit 2
fi

if [ -z "${RHPC_USERNAME_FOR_PUBLISHED_IMAGES+x}" ] ; then
  echo "RHPC_USERNAME_FOR_PUBLISHED_IMAGES environment variable must be set in order to push to RedHat Partner Connect registry"
  exit 2
fi

if [ -z "${RHPC_PASSWORD_FOR_PUBLISHED_IMAGES+x}" ] ; then
  echo "RHPC_PASSWORD_FOR_PUBLISHED_IMAGES environment variable must be set in order to push to RedHat Partner Connect registry"
  exit 2
fi

root_dir="$(git rev-parse --show-toplevel)"

if [ -z "${MAKER_CONTAINER+x}" ] ; then
   exec docker run --env RHPC_PASSWORD_FOR_OLM_METADATA_IMAGE --env RHPC_USERNAME_FOR_PUBLISHED_IMAGES --env RHPC_PASSWORD_FOR_PUBLISHED_IMAGES --rm --volume "${root_dir}:/src" --workdir /src "${MAKER_IMAGE}" "/src/scripts/$(basename "${0}")" "${1}"
fi

export QUAY_PUBLIC_ACCESS_ONLY="true" ANY_REGISTRY_USERNAME="unused" ANY_REGISTRY_PASSWORD="${RHPC_PASSWORD_FOR_OLM_METADATA_IMAGE}"

cilium_version="${1}" 

main_registry="quay.io/cilium"
rhpc_registry="registry.connect.redhat.com/isovalent"
olm_metadata_scan_registry="scan.connect.redhat.com/ospid-e31ac831-7e72-42bb-baf9-f392ef7ea622"

olm_operator_rhpc_image="$(imagine image "--base=./operator/cilium.v${cilium_version}" "--name=cilium-olm" "--custom-tag-suffix=v${cilium_version}" "--without-tag-suffix" "--registry=${rhpc_registry}")"

olm_metadata_source_image="$(imagine image "--base=./bundles/cilium.v${cilium_version}" "--name=cilium-olm-metadata" "--custom-tag-suffix=v${cilium_version}" "--without-tag-suffix" "--registry=${main_registry}")"

olm_metadata_digest="$(crane digest "${olm_metadata_source_image}" 2> /dev/nul || true)"

if [ -z "${olm_metadata_digest}" ] ; then
  echo "${olm_metadata_source_image} was not published yet, if you already pushed to master, check status in GitHub Actions"
  exit 3
fi

olm_metadata_scan_image="${olm_metadata_scan_registry}${olm_metadata_source_image/${main_registry}/}"

if ! env ANY_REGISTRY_USERNAME="${RHPC_USERNAME_FOR_PUBLISHED_IMAGES}" ANY_REGISTRY_PASSWORD="${RHPC_PASSWORD_FOR_PUBLISHED_IMAGES}" crane digest "${olm_operator_rhpc_image}" 2> /dev/null ; then
  echo "${olm_operator_rhpc_image} was not published yet, if you already ran 'push-to-scan-1-olm-operator.sh' for it, check the results & publish it"
  exit 3
fi

echo "will copy ${olm_metadata_source_image}@${olm_metadata_digest} to ${olm_metadata_scan_image}"

crane copy "${olm_metadata_source_image}" "${olm_metadata_scan_image}" 
