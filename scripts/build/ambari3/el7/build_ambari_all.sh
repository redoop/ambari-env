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

set -e

echo "############## PRE BUILD_AMBARI_ALL start #############"

PROJECT_PATH="/opt/modules/ambari3"   # 你的目标项目路径
PATCH_SCRIPT="/scripts/util/apply_patch.sh"  # 工具脚本路径
RPM_PACKAGE="/data/rpm-package/ambari3" # 目标路径

patch_files=(
  "/scripts/build/ambari3/el7/patch2_0_0/patch0-COMPONENT-VERSION-UPGRADE.diff"
  # 后续可继续添加补丁文件路径
)

for patch_file in "${patch_files[@]}"; do
  "$PATCH_SCRIPT" "$PROJECT_PATH" "$patch_file"
done



# 开启 gcc 高版本
source /opt/rh/devtoolset-7/enable
cd "$PROJECT_PATH"

# 使用jdk 17
export JAVA_HOME=/opt/modules/jdk-17.0.2
export PATH=$JAVA_HOME/bin:$PATH


mvn -T 16 -B  install \
package \
rpm:rpm \
-Drat.skip=true \
-Dcheckstyle.skip=true \
-DskipTests \
-Dspotbugs.skip=true \
-Preplaceurl


find "$PROJECT_PATH" -iname '*.rpm' -exec cp -rv {} "$RPM_PACKAGE" \;


echo "############## PRE BUILD_AMBARI_ALL end #############"
