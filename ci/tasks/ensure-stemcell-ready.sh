#!/usr/bin/env bash

set -e -o pipefail

my_dir="$( cd $(dirname $0) && pwd )"
release_dir="$( cd ${my_dir} && cd ../.. && pwd )"

source ${release_dir}/ci/tasks/utils.sh

: ${image_access_key:?}
: ${image_secret_key:?}
: ${image_region:?}

wget -q -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq
cp jq /usr/bin

saved_image_destinations="$(echo $(aliyun ecs DescribeRegions \
    --access-key-id ${image_access_key} \
    --access-key-secret ${image_secret_key} \
    --region ${image_region}
    ) | jq -r '.Regions.Region[].RegionId'
    )"

: ${image_destinations:=$saved_image_destinations}

stemcell_path=${PWD}/input-stemcell/*.tgz
original_stemcell_name="$(basename ${stemcell_path})"

echo -e "Checking image ${original_stemcell_name} is shared..."
success=false
while [[ ${success} = false ]]
do
    for regionId in ${image_destinations[*]}
    do
        DescribeImagesResponse="$(aliyun ecs DescribeImages \
                --access-key-id ${image_access_key}  \
                --access-key-secret ${image_secret_key} \
                --region ${regionId} \
                --RegionId ${regionId} \
                --ImageName ${original_stemcell_name} \
                --Status Waiting,Creating,Available
                )"
        imageId=$(echo ${DescribeImagesResponse} | jq -r '.Images.Image[0].ImageId')
        IsPublic=$(echo ${DescribeImagesResponse} | jq -r '.Images.Image[0].IsPublic')
        if [[ ${IsPublic} = "True" ]]; then
            echo "[$regionId Success] The image $imageId has been published."
            success=true
        else
            success=false
            sleep 10
            echo -e "[$regionId Failed] The image $imageId has not been published. Publishing it......"
            ModifyImageSharePermissionResponse="$(aliyun ecs ModifyImageSharePermission \
                --access-key-id ${image_access_key}  \
                --access-key-secret ${image_secret_key} \
                --region ${regionId} \
                --RegionId ${regionId} \
                --ImageId ${imageId} \
                --IsPublic true
                )"
            echo -e "Publishing image ${imageId} response: ${ModifyImageSharePermissionResponse}"
            break
        fi
    done
done
echo -e "Finished!"