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



echo "############## ONE_KEY_BUILD for ambari 3.0 start #############"

export NEXUS_URL=$(cat /scripts/system/before/nexus/.lock)
export NEXUS_USERNAME="admin"
export NEXUS_PASSWORD="admin123"
echo $NEXUS_URL

PROJECT_PATH="/opt/modules/bigtop"
RPM_PACKAGE="/data/deb-package/bigtop"
mkdir -p "$RPM_PACKAGE"


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

echo "2.0.0 补丁"
bash /scripts/build/bigtop3/ub2204/build2_0_0.sh

echo "2.1.0 补丁"
bash /scripts/build/bigtop3/ub2204/build2_1_0.sh


# 开启 gcc 高版本

cd "$PROJECT_PATH"

# 定义所有组件列表，并标注版本历史
ALL_COMPONENTS=(
  # 1.0.0 版本
#  bigtop-groovy-pkg
#  bigtop-jsvc-pkg
#  bigtop-select-pkg
#  bigtop-utils-pkg
#  zookeeper-pkg
#  hadoop-pkg
  flink-rpm
  hbase-rpm
  hive-rpm
#  kafka-rpm
#  spark-rpm
#  solr-rpm
#  tez-rpm
#  zeppelin-rpm
#  livy-rpm
#  # 1.0.1 版本新增
#  sqoop-rpm
#  ranger-rpm
#  # 1.0.2 版本新增
#  redis-rpm
#  # 1.0.3 版本新增
#  phoenix-rpm
#  dolphinscheduler-rpm
#  # 1.0.4 版本新增
#  doris-download
#  # 1.0.5 版本新增
#  nightingale-download
#  categraf-download
#  victoriametrics-download
#  cloudbeaver-download
#  celeborn-download
#  ozone-download
#  impala-download
#  # 1.0.6 版本新增
#  hudi-download
#  paimon-download
#  # 1.0.7 版本新增
#  atlas-download
#  superset-download
)

# 编译所有组件
gradle "${ALL_COMPONENTS[@]}" \
  -PparentDir=/usr/bigtop \
  -Dbuildwithdeps=true \
  -PpkgSuffix


# 遍历 output 目录下的每个子目录
for dir in "$PROJECT_PATH"/output/*; do
    if [ -d "$dir" ]; then
        # 获取子目录的名称
        component=$(basename "$dir")

        # 创建目标目录
        mkdir -p "$RPM_PACKAGE/$component"

        # 查找并复制文件
        find "$dir" -iname '*.deb' -exec cp -rv {} "$RPM_PACKAGE/$component" \;
    fi
done


echo "############## ONE_KEY_BUILD for ambari 3.0 start end #############"
