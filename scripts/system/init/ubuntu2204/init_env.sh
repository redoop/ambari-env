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
echo "############## INIT APT start #############"
FLAG_FILE="/var/lib/init/.lock"
mkdir -p /var/lib/init

# ========== repo 模板函数 ==========
write_repo_ubuntu22() {
  # $1 为 Nexus 私服地址，比如 192.168.1.100
  cat >/etc/apt/sources.list <<EOF
deb [trusted=yes] http://$1:8081/repository/ubuntu22-tsinghua/ jammy main restricted universe multiverse
deb [trusted=yes] http://$1:8081/repository/ubuntu22-tsinghua/ jammy-updates main restricted universe multiverse
deb [trusted=yes] http://$1:8081/repository/ubuntu22-tsinghua/ jammy-security main restricted universe multiverse
deb [trusted=yes] http://$1:8081/repository/ubuntu22-tsinghua/ jammy-backports main restricted universe multiverse
EOF
}

# ========== 各系统初始化操作函数 ==========
init_ubuntu22() {
  apt-get clean
  apt-get update

  echo "执行 Ubuntu 22.04 初始化脚本"
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-client \
    openssh-server \
    sudo \
    net-tools \
    unzip \
    wget \
    git \
    patch \
    build-essential \
    cmake \
    autoconf \
    automake \
    libtool \
    vim \
    lsof \
    iproute2 \
    less \
    curl \
    bzip2 \
    zlib1g-dev \
    libssl-dev \
    libsnappy-dev \
    libbz2-dev \
    libtirpc-dev \
    libkrb5-dev \
    libxml2-dev \
    protobuf-compiler \
    python3 \
    python3-pip \
    tar \
    debhelper \
    devscripts \
    build-essential \
    dh-make \
    lintian \
    fakeroot \
    locales \
    libcppunit-dev pkg-config m4 autoconf-archive \
    liblzo2-dev libzip-dev sharutils libfuse-dev \
    libsasl2-dev libgsasl-dev \
    asciidoc rsync libzstd-dev libprotobuf-dev libisal-dev libpmem-dev
  rm -rf /var/lib/apt/lists/*
}

# ========== 主流程 ==========
rm_init_repos() {
  NEXUS_IP=$(cat /scripts/system/before/nexus/.lock)
  echo "读取nexus 服务器地址：$NEXUS_IP"

  OS_ID=$(grep -oP '^ID="?(\w+)"?' /etc/os-release | cut -d= -f2 | tr -d '"')
  OS_VERSION_ID=$(grep -oP '^VERSION_ID="?([0-9\.]+)"?' /etc/os-release | cut -d= -f2 | tr -d '"')

  case "${OS_ID}_${OS_VERSION_ID}" in
    ubuntu_22.04* )
      write_repo_ubuntu22 "$NEXUS_IP"
      echo "repo 文件已写入，正在初始化 Ubuntu 22.04 repo ..."
      init_ubuntu22
      ;;
    *)
      echo "未知系统: ${OS_ID} ${OS_VERSION_ID}，请手动补充repo模板和初始化逻辑" >&2
      exit 1
      ;;
  esac
}

rm_init_repos

if [ ! -f "$FLAG_FILE" ]; then
  echo 'root:root' | chpasswd
  mkdir -p /var/run/sshd
  if ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "ERROR: ssh-keygen not found! openssh-client 没装成功？"
    exit 2
  fi
  ssh-keygen -A

  # 确保 sshd_config 存在并允许 root 登录
  if [ ! -f "/etc/ssh/sshd_config" ]; then
    touch /etc/ssh/sshd_config
  fi
  grep -q '^PermitRootLogin' /etc/ssh/sshd_config \
    && sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

  # 常用 alias 配置
  grep -qxF "alias ll='ls -alF --color=auto'" /etc/profile || echo "alias ll='ls -alF --color=auto'" >> /etc/profile
  grep -qxF "alias ls='ls --color=auto'" /etc/profile || echo "alias ls='ls --color=auto'" >> /etc/profile
  grep -qxF "source /etc/profile" /root/.bashrc || echo "source /etc/profile" >> /root/.bashrc

  touch "$FLAG_FILE"
else
  echo "APT 已经完成初始化"
fi

echo "############## INIT APT end #############"
