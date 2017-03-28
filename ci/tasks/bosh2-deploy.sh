#!/bin/bash

set -e

manifest_dir=$(pwd)/manifest

export BOSH_ENVIRONMENT=`bosh2 int director-state/director-creds.yml --path /internal_ip`
export BOSH_CA_CERT="$(bosh2 int director-state/director-creds.yml --path /director_ssl/ca)"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh2 int director-state/director-creds.yml --path /admin_password`
export BOSH_DEPLOYMENT=$deployment_name

if [[ "${delete_deployment_first:-false}" != "false" ]]; then
  bosh2 -n delete-deployment
fi

release_name=${release_name:-docker-boshrelease}
release_version=$(cat candidate-release/version)
bosh2 upload-release candidate-release/*.tgz

cd boshrelease-ci
mkdir -p tmp

cat > tmp/versions.yml <<YAML
---
- type: replace
  path: /releases/name=${release_name}/version
  value: ${release_version}
YAML

cat > tmp/deployment.yml <<YAML
---
- type: replace
  path: /name
  value: ${deployment_name:?required}
YAML

cat > tmp/vars.yml <<YAML
--- {}
YAML

set -x
bosh2 int ${manifest_path:?required}       \
  -o           tmp/deployment.yml              \
  -o           tmp/versions.yml                \
  --vars-store tmp/creds.yml \
  --vars-file  tmp/vars.yml  \
  --var-errs \
    > $manifest_dir/manifest.yml

bosh2 -n deploy $manifest_dir/manifest.yml

if [[ "${test_errand:-X}" != "X" ]]; then
  bosh2 run-errand ${test_errand}
fi