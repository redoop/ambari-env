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
echo "############## INIT YUM start #############"
FLAG_FILE="/var/lib/init/.lock"
mkdir -p /var/lib/init

# ========== 各系统 repo 模板函数 ==========
write_repo_centos7() {
  cat >/etc/yum.repos.d/yum-public.repo <<EOF
[yum-public-base]
name=YUM Public Repository (CentOS 7)
baseurl=http://$1:8081/repository/yum-public/\$releasever/os/\$basearch/
enabled=1
gpgcheck=0
[yum-public-update]
name=YUM Public Repository (CentOS 7)
baseurl=http://$1:8081/repository/yum-public/\$releasever/updates/\$basearch/
enabled=1
gpgcheck=0
[yum-public-extras]
name=YUM Public Repository (CentOS 7)
baseurl=http://$1:8081/repository/yum-public/\$releasever/extras/\$basearch/
enabled=1
gpgcheck=0
[yum-public-centosplus]
name=YUM Public Repository (CentOS 7)
baseurl=http://$1:8081/repository/yum-public/\$releasever/centosplus/\$basearch/
enabled=1
gpgcheck=0
[yum-public-scl]
name=YUM Public Repository (CentOS 7 SCL)
baseurl=http://$1:8081/repository/yum-public/7.9.2009/sclo/\$basearch/sclo/
enabled=1
gpgcheck=0
[yum-public-scl-rh]
name=YUM Public Repository (CentOS 7 SCL-RH)
baseurl=http://$1:8081/repository/yum-public/7.9.2009/sclo/\$basearch/rh/
enabled=1
gpgcheck=0
[yum-public-epel]
name=YUM Public Repository (CentOS 7 EPEL)
baseurl=http://$1:8081/repository/yum-public/\$releasever/\$basearch/
enabled=1
gpgcheck=0
#[yum-public-mariadb]
#name=YUM Public Repository (CentOS 7 MariaDB)
#baseurl=http://$1:8081/repository/yum-public/yum/10.11.15/centos7-amd64/
#enabled=1
#gpgcheck=0
EOF
}

write_repo_rocky8() {
  cat >/etc/yum.repos.d/yum-public.repo <<EOF
[rocky-baseos]
name=Rocky Linux \$releasever - BaseOS
baseurl=http://$1:8081/repository/rocky8-mirrors/\$releasever/BaseOS/\$basearch/os/
gpgcheck=0
enabled=1

[rocky-appstream]
name=Rocky Linux \$releasever - AppStream
baseurl=http://$1:8081/repository/rocky8-mirrors/\$releasever/AppStream/\$basearch/os/
gpgcheck=0
enabled=1

[rocky-extras]
name=Rocky Linux \$releasever - Extras
baseurl=http://$1:8081/repository/rocky8-mirrors/\$releasever/extras/\$basearch/os/
gpgcheck=0
enabled=1

[rocky-epel]
name=EPEL for Rocky Linux \$releasever - \$basearch
baseurl=http://$1:8081/repository/rocky8-epel/epel/\$releasever/Everything/\$basearch/
gpgcheck=0
enabled=1

[rocky-powertools]
name=Rocky Linux \$releasever - PowerTools
baseurl=http://$1:8081/repository/rocky8-mirrors/\$releasever/PowerTools/\$basearch/os/
gpgcheck=0
enabled=1

EOF
}


# ========== 各系统初始化操作函数 ==========
init_centos7() {
  rm -rf /etc/yum.repos.d/CentOS* /etc/yum.repos.d/epel* /etc/yum.repos.d/ambari-bigtop*
  yum clean all
  echo "执行 CentOS 7 初始化脚本"
  yum -y install centos-release-scl centos-release-scl-rh openssh-server passwd sudo net-tools unzip wget git || true
  rm -rf /etc/yum.repos.d/CentOS*
}

init_rocky8() {
  rm -rf /etc/yum.repos.d/Rocky* /etc/yum.repos.d/epel* /etc/yum.repos.d/ambari-bigtop*
  dnf clean all && dnf clean packages

  echo "执行 Rocky 8 初始化脚本"

  dnf -y install \
      asciidoc \
      autoconf \
      automake \
      bzip2-devel \
      cmake \
      cppunit-devel \
      cyrus-sasl-devel \
      curl \
      docbook2X \
      fuse \
      fuse-devel \
      fuse-libs \
      gcc \
      gcc-c++ \
      git \
      iproute \
      krb5-devel \
      less \
      libtirpc-devel \
      libtool \
      libxml2-devel \
      lsof \
      lzo-devel \
      make \
      net-tools \
      openssh-server \
      openssl-devel \
      patch \
      procps-ng \
      protobuf-devel \
      python3 \
      redhat-lsb-core \
      rpm-build \
      rsync \
      snappy-devel \
      sudo \
      tar \
      unzip \
      vim \
      wget \
      which \
      xmlto \
      zlib-devel \
      isa-l-devel \
      libpmem-devel \
      libpmemobj-devel \
      protobuf-compiler \
      pkgconf \
      m4 \
      autoconf-archive \
      libzip-devel \
      sharutils \
      libgsasl-devel \
      libzstd-devel \
  || true

  # yum -y install wget || true
  # 这里不装 scl 相关包，因为 Rocky 8 通常不需要

  rm -rf /etc/yum.repos.d/Rocky*
}


# ========== 主流程 ==========
rm_init_repos() {
  NEXUS_IP=$(cat /scripts/system/before/nexus/.lock)
  echo "读取nexus 服务器地址：$NEXUS_IP"

  OS_ID=$(grep -oP '^ID="?(\w+)"?' /etc/os-release | cut -d= -f2 | tr -d '"')
  OS_VERSION_ID=$(grep -oP '^VERSION_ID="?([0-9\.]+)"?' /etc/os-release | cut -d= -f2 | tr -d '"')

  case "${OS_ID}_${OS_VERSION_ID}" in
    centos_7* | rhel_7* )
      write_repo_centos7 "$NEXUS_IP"
      echo "repo 文件已写入，正在初始化 CentOS 7 repo ..."
      init_centos7
      ;;
    centos_8* | rhel_8* | rockylinux_8* | rocky_8* | almalinux_8* )
      write_repo_rocky8 "$NEXUS_IP"
      echo "repo 文件已写入，正在初始化 Rocky 8 repo ..."
      init_rocky8
      ;;
    # 后续新增系统直接加分支及对应的 write_repo_xxx 和 init_xxx
    *)
      echo "未知系统: ${OS_ID} ${OS_VERSION_ID}，请手动补充repo模板和初始化逻辑" >&2
      ;;
  esac
}

rm_init_repos

if [ ! -f "$FLAG_FILE" ]; then
  echo 'root:root' | chpasswd
  ssh-keygen -A

  # 确保 sshd_config 存在并允许 root 登录
  if [ ! -f "/etc/ssh/sshd_config" ]; then
    touch /etc/ssh/sshd_config
  fi
  grep -q '^PermitRootLogin' /etc/ssh/sshd_config \
    && sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

  # 全局 alias 配置（注意加 color）
  grep -qxF "alias ll='ls -alF --color=auto'" /etc/profile || echo "alias ll='ls -alF --color=auto'" >> /etc/profile
  grep -qxF "alias ls='ls --color=auto'" /etc/profile || echo "alias ls='ls --color=auto'" >> /etc/profile

  # 确保新 shell 生效
  grep -qxF "source /etc/profile" /root/.bashrc || echo "source /etc/profile" >> /root/.bashrc

  touch "$FLAG_FILE"
else
  echo "yum 已经完成初始化"
fi


echo "############## INIT YUM end #############"
