#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 2 ] ; then
  echo "$0 supports exactly 2 argument"
  echo "example: '$0 1.9 4.7'"
  exit 1
fi

if [ -z "${RHPC_USERNAME_FOR_PUBLISHED_IMAGES+x}" ] ; then
  echo "RHPC_USERNAME_FOR_PUBLISHED_IMAGES environment variable must be set in order to push to RedHat Partner Connect registry"
  exit 2
fi

if [ -z "${RHPC_PASSWORD_FOR_PUBLISHED_IMAGES+x}" ] ; then
  echo "RHPC_PASSWORD_FOR_PUBLISHED_IMAGES environment variable must be set in order to push to RedHat Partner Connect registry"
  exit 2
fi

cilium_version="${1}" 
openshift_version="${2}"

index_image="registry.redhat.io/redhat/certified-operator-index:v${openshift_version}"

export ANY_REGISTRY_USERNAME="${RHPC_USERNAME_FOR_PUBLISHED_IMAGES}" ANY_REGISTRY_PASSWORD="${RHPC_PASSWORD_FOR_PUBLISHED_IMAGES}"

docker pull "${index_image}"

docker run --rm --entrypoint sh --user root "${index_image}" -c "
  yum install -q -y sqlite
  sqlite3 -column /database/index.db \"select distinct operatorbundle_name from related_image where operatorbundle_name like 'cilium.v${cilium_version}-%';\"
"
