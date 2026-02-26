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

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" =~ ^(rhel|centos)$ && "$VERSION_ID" == 7* ]]; then
        # RHEL/CentOS 7
        /scripts/build/ambari3/el7/build_ambari_all.sh
    elif [[ "$ID" =~ ^(rhel|centos|rocky|almalinux)$ && "$VERSION_ID" == 8* ]]; then
        # RHEL/CentOS/Rocky/AlmaLinux 8
        /scripts/build/ambari3/el8/build_ambari_all.sh
    elif [[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]]; then
        # Ubuntu 22.04
        /scripts/build/ambari3/ub2204/build_ambari_all.sh
    elif [[ "$ID" == "kylin" && "$VERSION_ID" =~ ^[Vv]?10 ]]; then
        # Kylin V10
        /scripts/build/ambari3/kylinv10/build_ambari_all.sh
    else
        echo "不支持的系统: $ID $VERSION_ID"
        exit 1
    fi
else
    echo "/etc/os-release 文件不存在，无法判断系统类型"
    exit 2
fi
