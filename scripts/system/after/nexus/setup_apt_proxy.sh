#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: JaneTTR

set -ex

echo "############## SETUP CONFIGURE_APT_REPO start #############"

# Nexus 服务器信息
NEXUS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"

########## Ubuntu 22.04 仓库 ##########
REPOS_UBUNTU22=(
  "ubuntu22-aliyun|https://mirrors.aliyun.com/ubuntu/"
  "ubuntu22-tsinghua|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
  "ubuntu22-official|http://archive.ubuntu.com/ubuntu/"
)
GROUP_REPO_UBUNTU22="ubuntu22-group"
GROUP_MEMBERS_UBUNTU22=("ubuntu22-aliyun" "ubuntu22-tsinghua" "ubuntu22-official")

# ================= 函数定义 ===================

# 检查仓库是否存在
check_repo_exists() {
  local repo_name=$1
  local response
  response=$(curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repo_name}")
  [[ $response == *"\"name\" : \"${repo_name}\""* ]]
}

# 创建 APT 代理仓库
create_proxy_repo_apt() {
  local repo_name=$1
  local remote_url=$2
  local repo_config

  repo_config=$(
    cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "apt": {
    "distribution": "jammy",
    "flat": false
  },
  "proxy": {
    "remoteUrl": "${remote_url}",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  }
}
EOF
  )

  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/apt/proxy" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# 获取组仓库成员
get_group_members() {
  local repo_name=$1
  curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repo_name}" | grep -oP '"memberNames" : \[\K[^\]]+' | tr -d '"' | tr ',' '\n'
}

# 创建组仓库
create_group_repo_apt() {
  local repo_name=$1
  shift
  local members=("$@")
  local members_json=$(printf '"%s",' "${members[@]}")
  members_json="[${members_json%,}]"

  local repo_config

  repo_config=$(
    cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "apt": {
    "distribution": "jammy",
    "flat": false
  },
  "group": {
    "memberNames": ${members_json}
  }
}
EOF
  )

  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/apt/group" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# 更新组仓库成员
update_group_repo_members_apt() {
  local repo_name=$1
  shift
  local new_members=("$@")
  local existing_members=()

  if check_repo_exists "${repo_name}"; then
    existing_members=($(get_group_members "${repo_name}"))
  fi

  local all_members=("${existing_members[@]}" "${new_members[@]}")
  local unique_members=($(echo "${all_members[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

  local members_json=$(printf '"%s",' "${unique_members[@]}")
  members_json="[${members_json%,}]"

  local repo_config

  repo_config=$(
    cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "apt": {
    "distribution": "jammy",
    "flat": false
  },
  "group": {
    "memberNames": ${members_json}
  }
}
EOF
  )

  curl -u "${USERNAME}:${PASSWORD}" -X PUT "${NEXUS_URL}/service/rest/v1/repositories/apt/group/${repo_name}" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# ================== 创建/更新 Ubuntu 22.04 仓库 ==================
for repo in "${REPOS_UBUNTU22[@]}"; do
  IFS="|" read -r repo_name remote_url <<<"${repo}"
  if check_repo_exists "${repo_name}"; then
    echo "APT仓库 ${repo_name} 已存在。"
  else
    echo "正在创建APT代理仓库 ${repo_name}..."
    create_proxy_repo_apt "${repo_name}" "${remote_url}"
  fi
done

if check_repo_exists "${GROUP_REPO_UBUNTU22}"; then
  echo "组APT仓库 ${GROUP_REPO_UBUNTU22} 已存在，正在更新成员..."
  update_group_repo_members_apt "${GROUP_REPO_UBUNTU22}" "${GROUP_MEMBERS_UBUNTU22[@]}"
else
  echo "组APT仓库 ${GROUP_REPO_UBUNTU22} 不存在，正在创建..."
  create_group_repo_apt "${GROUP_REPO_UBUNTU22}" "${GROUP_MEMBERS_UBUNTU22[@]}"
fi

echo "APT仓库创建成功。"
echo "############## SETUP CONFIGURE_APT_REPO end #############"
