#!/usr/bin/env bash

# rounds up to the nearest GB
mb_to_gb() {
  mb="$1"
  echo "$(( (${mb}+1024-1)/1024 ))"
}

# Oportunistically configure aliyun cli for use
configure_aliyun_cli() {
  local cli_input="$(realpath aliyun-cli/aliyun-cli-* 2>/dev/null || true)"
  if [[ -n "${cli_input}" ]]; then
    tar -xzf aliyun-cli/aliyun-cli-linux-*.tgz -C /usr/bin
  fi
}
configure_aliyun_cli

# cleanup the failed image
cleanup_previous_image() {
    image_access_key="$1"
    image_secret_key="$2"
    regionId="$3"
    original_stemcell_name="$4"
    DescribeImagesResponse="$(aliyun ecs DescribeImages \
            --access-key-id ${image_access_key} \
            --access-key-secret ${image_secret_key} \
            --region ${regionId} \
            --RegionId ${regionId} \
            --ImageName ${original_stemcell_name} \
            --Status Waiting,Creating,Available,UnAvailable,CreateFailed \
            --ImageOwnerAlias self
            )"
    TotalTargetImage=$(echo ${DescribeImagesResponse} | jq -r '.TotalCount')
    if [[ ${TotalTargetImage} > "0" ]]; then
        TargetImage=$(echo ${DescribeImagesResponse} | jq -r '.Images.Image[0].ImageId')
        echo "Remove the existed in ${regionId} image $original_stemcell_name ..."
        DeleteImageResponse="$(aliyun ecs DeleteImage \
            --access-key-id ${image_access_key} \
            --access-key-secret ${image_secret_key} \
            --region ${regionId} \
            --RegionId ${regionId}\
            --ImageId ${TargetImage} \
            --Force true
            )"
        echo -e "DeleteImage $TargetImage Response: $DeleteImageResponse"
        sleep 5
    fi
}
