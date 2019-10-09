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
    DescribeImagesResponse="$(aliyun ecs DescribeImages \
            --access-key-id $1  \
            --access-key-secret $2 \
            --region $3 \
            --RegionId $3 \
            --ImageName $4 \
            --Status Waiting,Creating,Available,UnAvailable,CreateFailed \
            --ImageOwnerAlias self
            )"
    TotalTargetImage=$(echo ${DescribeImagesResponse} | jq -r '.TotalCount')
    if [[ ${TotalTargetImage} -gt 0 ]]; then
        TargetImage=$(echo ${DescribeImagesResponse} | jq -r '.Images.Image[0].ImageId')
        echo "Remove the existed image $original_stemcell_name ..."
        DeleteImageResponse="$(aliyun ecs DeleteImage \
            --access-key-id $1 \
            --access-key-secret $2 \
            --region $3 \
            --RegionId $3 \
            --ImageId ${TargetImage} \
            --Force true
            )"
        echo -e "DeleteImage $TargetImage Response: $DeleteImageResponse"
    fi
}
