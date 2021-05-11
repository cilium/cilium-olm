#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

MAKER_IMAGE="${MAKER_IMAGE:-docker.io/cilium/image-maker:60c02a5e6cb057f462739f2b7b19f5c3f6a22933}"

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 1.9.1'"
  exit 1
fi

if [ -z "${RHPC_PASSWORD_FOR_OLM_OPERATOR_IMAGE+x}" ] ; then
  echo "RHPC_PASSWORD_FOR_OLM_OPERATOR_IMAGE environment variable must be set in order to push to RedHat Partner Connect registry"
  exit 2
fi

root_dir="$(git rev-parse --show-toplevel)"

if [ -z "${MAKER_CONTAINER+x}" ] ; then
   exec docker run --env RHPC_PASSWORD_FOR_OLM_OPERATOR_IMAGE --rm --volume "${root_dir}:/src" --workdir /src "${MAKER_IMAGE}" "/src/scripts/$(basename "${0}")" "${1}"
fi

export QUAY_PUBLIC_ACCESS_ONLY="true" ANY_REGISTRY_USERNAME="unused" ANY_REGISTRY_PASSWORD="${RHPC_PASSWORD_FOR_OLM_OPERATOR_IMAGE}"

cilium_version="${1}" 

main_registry="quay.io/cilium"
olm_operator_scan_registry="scan.connect.redhat.com/ospid-104ec1da-384c-4d7c-bd27-9dbfd8377f5b"

olm_operator_source_image="$(imagine image "--base=./operator/cilium.v${cilium_version}" "--name=cilium-olm" "--custom-tag-suffix=v${cilium_version}" "--without-tag-suffix" "--registry=${main_registry}")"

olm_operator_digest="$(crane digest "${olm_operator_source_image}" 2> /dev/nul || true)"

if [ -z "${olm_operator_digest}" ] ; then
  echo "${olm_operator_source_image} was not published yet, if you already pushed to master, check status in GitHub Actions"
  exit 3
fi

olm_operator_scan_image="${olm_operator_scan_registry}${olm_operator_source_image/${main_registry}/}"

echo "will copy ${olm_operator_source_image}@${olm_operator_digest} to ${olm_operator_scan_image}"

crane copy "${olm_operator_source_image}" "${olm_operator_scan_image}" 
