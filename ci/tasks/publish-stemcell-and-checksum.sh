#!/bin/bash

set -eu

: ${ALICLOUD_ACCESS_KEY_ID:?}
: ${ALICLOUD_SECRET_ACCESS_KEY:?}
: ${bosh_io_bucket_name_cn:?}
: ${bosh_io_bucket_region_cn:?}
: ${bosh_io_bucket_name_eu:?}
: ${bosh_io_bucket_region_eu:?}

my_dir="$( cd $(dirname $0) && pwd )"
release_dir="$( cd ${my_dir} && cd ../.. && pwd )"

go version
source ${release_dir}/ci/tasks/utils.sh
ls bosh-cli
ls ${release_dir}
ls $(pwd)
#chmod +x bosh-cli/bosh-cli-*
cp bosh-cli/bosh-cli-* /usr/bin/bosh
#alias bosh='bosh-cli/bosh-*'
chmod +x /usr/bin/bosh

go version

success_message=${PWD}/notification/success
failed_message=${PWD}/notification/failed

# inputs
light_stemcell_dir="$PWD/light-stemcell"

light_stemcell_path="$(echo ${light_stemcell_dir}/*.tgz)"
light_stemcell_name="$(basename "${light_stemcell_path}")"

tar -Oxf ${light_stemcell_path} stemcell.MF > /tmp/stemcell.MF

OS_NAME="$(bosh int /tmp/stemcell.MF --path /operating_system)"
STEMCELL_VERSION="$(bosh int /tmp/stemcell.MF --path /version)"

git clone stemcells-index stemcells-index-output

meta4_path=$PWD/stemcells-index-output/published/$OS_NAME/$STEMCELL_VERSION/stemcells.alicloud.meta4

mkdir -p "$(dirname "${meta4_path}")"
meta4 create --metalink="$meta4_path"

meta4 import-file --metalink="$meta4_path" --version="$STEMCELL_VERSION" "light-stemcell/${light_stemcell_name}"
meta4 file-set-url --location="cn" --priority="1" --metalink="$meta4_path" --file="${light_stemcell_name}" "https://$bosh_io_bucket_name_cn.oss-$bosh_io_bucket_region_cn.aliyuncs.com/$light_stemcell_name"
meta4 file-set-url --location="eu" --priority="1" --metalink="$meta4_path" --file="${light_stemcell_name}" "https://$bosh_io_bucket_name_eu.oss-$bosh_io_bucket_region_eu.aliyuncs.com/$light_stemcell_name"

pushd stemcells-index-output > /dev/null
  git add -A
  git -c user.email="ci@localhost" -c user.name="CI Bot" \
    commit -m "publish: $OS_NAME/$STEMCELL_VERSION"
popd > /dev/null

echo "Uploading light stemcell ${light_stemcell_name} to ${bosh_io_bucket_name_cn}..."
aliyun oss cp "${light_stemcell_path}" "oss://${bosh_io_bucket_name_cn}/${light_stemcell_name}" --access-key-id ${ALICLOUD_ACCESS_KEY_ID} --access-key-secret ${ALICLOUD_SECRET_ACCESS_KEY} --region ${bosh_io_bucket_region_cn} --force
aliyun oss set-acl "oss://${bosh_io_bucket_name_cn}/${light_stemcell_name}" public-read --access-key-id ${ALICLOUD_ACCESS_KEY_ID} --access-key-secret ${ALICLOUD_SECRET_ACCESS_KEY} --region ${bosh_io_bucket_region_cn}

echo "Uploading light stemcell ${light_stemcell_name} to ${bosh_io_bucket_name_eu}..."
aliyun oss cp "${light_stemcell_path}" "oss://${bosh_io_bucket_name_eu}/${light_stemcell_name}" --access-key-id ${ALICLOUD_ACCESS_KEY_ID} --access-key-secret ${ALICLOUD_SECRET_ACCESS_KEY} --region ${bosh_io_bucket_region_eu} --force
aliyun oss set-acl "oss://${bosh_io_bucket_name_eu}/${light_stemcell_name}" public-read --access-key-id ${ALICLOUD_ACCESS_KEY_ID} --access-key-secret ${ALICLOUD_SECRET_ACCESS_KEY} --region ${bosh_io_bucket_region_eu}

echo "Stemcell metalink"
cat "$meta4_path"

# Write the success message
echo -e "[bosh-alicloud-light-stemcell-builder Success]\nPublish the latest light stemcell light-${light_stemcell_name} success." > ${success_message}

# Write the failed message
echo -e "[bosh-alicloud-light-stemcell-builder Failed]\nPublish the latest light stemcell light-${light_stemcell_name} failed. Please check it!" > ${failed_message}
