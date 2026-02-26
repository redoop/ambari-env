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



echo "############## ONE_KEY_BUILD start #############"

export NEXUS_URL=$(cat /scripts/system/before/nexus/.lock)
export NEXUS_USERNAME="admin"
export NEXUS_PASSWORD="admin123"
echo $NEXUS_URL

PROJECT_PATH="/opt/modules/bigtop"
RPM_PACKAGE="/data/rpm-package/bigtop"
mkdir -p "$RPM_PACKAGE"
mkdir -p "$PROJECT_PATH"



echo "1.0.0 补丁"
bash /scripts/build/bigtop/build.sh

echo "1.0.1 补丁"
bash /scripts/build/bigtop/build1_0_1.sh

echo "1.0.2 补丁"
bash /scripts/build/bigtop/build1_0_2.sh

echo "1.0.3 补丁"
bash /scripts/build/bigtop/build1_0_3.sh

echo "1.0.4 补丁"
bash /scripts/build/bigtop/build1_0_4.sh

echo "1.0.5 补丁"
bash /scripts/build/bigtop/build1_0_5.sh

echo "1.0.6 补丁"
bash /scripts/build/bigtop/build1_0_6.sh

echo "1.0.7 补丁"
bash /scripts/build/bigtop/build1_0_7.sh

# 检测操作系统并执行相应的设置脚本
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_NAME=$ID
  OS_VERSION=$VERSION_ID
  
  echo "检测到操作系统: $OS_NAME $OS_VERSION"
  
  if [[ "$OS_NAME" == "rocky" && "$OS_VERSION" =~ ^8 ]]; then
    # 开启 gcc 高版本 (GCC Toolset 11)
    source /opt/rh/gcc-toolset-11/enable
  elif [[ "$OS_NAME" == "kylin" && "$OS_VERSION" =~ ^V10 ]]; then
    echo "Kylin V10 系统"
  else
    # 开启 gcc 高版本 (DevToolset 7)
    source /opt/rh/devtoolset-7/enable
  fi
else
  # 开启 gcc 高版本 (DevToolset 7)
  source /opt/rh/devtoolset-7/enable
fi

cd "$PROJECT_PATH"

# 定义所有组件列表，并标注版本历史
ALL_COMPONENTS=(
  # 1.0.0 版本
  bigtop-groovy-rpm
  bigtop-jsvc-rpm
  bigtop-select-rpm
  bigtop-utils-rpm
  zookeeper-rpm
  hadoop-rpm
  flink-rpm
  hbase-rpm
  hive-rpm
  kafka-rpm
  spark-rpm
  solr-rpm
  tez-rpm
  zeppelin-rpm
  livy-rpm
  # 1.0.1 版本新增
  sqoop-rpm
  ranger-rpm
  # 1.0.2 版本新增
  redis-rpm
  # 1.0.3 版本新增
  phoenix-rpm
  dolphinscheduler-rpm
  # 1.0.4 版本新增
  doris-download
  # 1.0.5 版本新增
  nightingale-download
  categraf-download
  victoriametrics-download
  cloudbeaver-download
  celeborn-download
  ozone-download
  impala-download
  # 1.0.6 版本新增
  hudi-download
  paimon-download
  # 1.0.7 版本新增
  atlas-download
  superset-download
)

# 判断是否传入参数
if [ $# -gt 0 ]; then
  # 如果传入参数，使用传入的组件列表
  COMPONENTS_TO_BUILD=("$@")
  echo "编译指定组件: ${COMPONENTS_TO_BUILD[*]}"
else
  # 如果没有传入参数，编译所有组件
  COMPONENTS_TO_BUILD=("${ALL_COMPONENTS[@]}")
  echo "编译所有组件"
fi

# 编译组件
echo "开始编译组件: ${COMPONENTS_TO_BUILD[*]}"
if gradle "${COMPONENTS_TO_BUILD[@]}" \
  -PparentDir=/usr/bigtop \
  -Dbuildwithdeps=true \
  -PpkgSuffix -d; then
  echo "Gradle 构建成功"
else
  echo "ERROR: Gradle 构建失败，退出码: $?"
  echo "请检查上面的错误日志，或使用 --info 参数查看详细信息"
  exit 1
fi


# 遍历 output 目录下的每个子目录
for dir in "$PROJECT_PATH"/output/*; do
    if [ -d "$dir" ]; then
        # 获取子目录的名称
        component=$(basename "$dir")

        # 创建目标目录
        mkdir -p "$RPM_PACKAGE/$component"

        # 查找并复制文件（使用 || true 避免 find 没找到文件时导致脚本失败）
        find "$dir" -iname '*.rpm' -not -iname '*.src.rpm' -exec cp -rv {} "$RPM_PACKAGE/$component" \; || true
        
        # 输出复制结果
        rpm_count=$(find "$RPM_PACKAGE/$component" -iname '*.rpm' 2>/dev/null | wc -l)
        echo "组件 $component: 复制了 $rpm_count 个 RPM 包"
    fi
done


echo "############## ONE_KEY_BUILD end #############"
