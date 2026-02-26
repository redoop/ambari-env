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
# 用法: ./apply_patch.sh <PROJECT_PATH> <PATCH_FILE>
# 作用：判断补丁是否已应用，未应用则自动打补丁，并处理常见异常。
# apply_patch.sh
# 用法: /scripts/util/apply_patch.sh <PROJECT_PATH> <PATCH_FILE>
# 功能：判断补丁是否已应用，未应用则自动打补丁，支持幂等，处理新增文件等常见场景。
#!/usr/bin/env bash
set -e

# 参数解析
PROJECT_PATH="$1"   # 项目目录，补丁将在此目录下应用
PATCH_FILE="$2"     # 补丁文件路径

# 参数校验
if [ -z "$PROJECT_PATH" ] || [ -z "$PATCH_FILE" ]; then
  echo "Usage: $0 <PROJECT_PATH> <PATCH_FILE>"
  exit 1
fi

echo "正在处理补丁文件：$PATCH_FILE"

# 进入项目目录（git apply 不像 patch 有 -d 参数）
cd "$PROJECT_PATH"

# 检查补丁是否已应用（能干跑反向应用 => 已经应用过）
if git apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
  echo "补丁：$PATCH_FILE 已经应用，跳过"
else
  # 正向检查（不真正应用）
  if git apply --check "$PATCH_FILE" >/dev/null 2>&1; then
    # 正式应用
    if git apply "$PATCH_FILE"; then
      echo "补丁：$PATCH_FILE 已经成功执行"
    else
      echo "补丁：$PATCH_FILE 执行失败"
      exit 2
    fi
  else
    # 兼容“新增文件”类补丁：目标文件不存在时，git apply --check 常见报错是 does not exist
    # 这里选择：如果是“目标文件不存在”，认为是新增文件补丁，跳过（保持你原逻辑）
    if git apply --check "$PATCH_FILE" 2>&1 | grep -qiE "does not exist|not found"; then
      echo "补丁：$PATCH_FILE 是新增文件，跳过"
    else
      echo "补丁：$PATCH_FILE 执行失败"
      exit 2
    fi
  fi
fi
