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

set -euo pipefail

# =====[0] 变量 =====
DOWNLOAD_DIR="/opt/modules"

# R
R_VER="4.4.2"
R_TARBALL="R-${R_VER}.tar.gz"
R_URL="https://mirrors.tuna.tsinghua.edu.cn/CRAN/src/base/R-4/${R_TARBALL}"
R_SRC_DIR="${DOWNLOAD_DIR}/R-${R_VER}"
R_PREFIX="/usr/local/R-${R_VER}"

# pandoc（官方二进制兜底）
PANDOC_VER="${PANDOC_VER:-3.1.13}"
PANDOC_TGZ="pandoc-${PANDOC_VER}-linux-amd64.tar.gz"
PANDOC_URL="https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/${PANDOC_TGZ}"
PANDOC_PREFIX="/usr/local/pandoc-${PANDOC_VER}"

# TeX Live（官方 install-tl 兜底）
TL_YEAR="${TL_YEAR:-2024}"
TL_PREFIX="/opt/texlive/${TL_YEAR}"
TL_BIN="${TL_PREFIX}/bin/x86_64-linux"
TL_PROFILE="${DOWNLOAD_DIR}/texlive.profile"

# CRAN 镜像
CRAN_MIRRORS="c('https://mirrors.tuna.tsinghua.edu.cn/CRAN/','https://mirrors.ustc.edu.cn/CRAN/','https://mirrors.aliyun.com/CRAN/')"

# 可选：是否对 SparkR 的 Rd 进行自动修复（\url{..}{..} -> \href{..}{..} & \itemize 花括号）
RUN_SPARKR_RD_FIX="${RUN_SPARKR_RD_FIX:-0}"  # 1=启用，0=关闭
SPARKR_DIR="${SPARKR_DIR:-}"                 # 设置为 SparkR 包根目录路径（包含 man/*.Rd）

# =====[1] 前置检查与目录 =====
if ! command -v dnf >/dev/null 2>&1; then
  echo "未发现 dnf（Kylin V10 应有），退出"; exit 1
fi
sudo mkdir -p "$DOWNLOAD_DIR"
sudo chown "$(id -u)":"$(id -g)" "$DOWNLOAD_DIR"

# =====[2] 基础依赖（对齐 Rocky8 + 图形/字体链） =====
echo ">>> 安装基础开发依赖与图形/字体相关 devel 包（含 pkgconf-pkg-config）..."
BASE_DEPS=(
  gcc gcc-c++ gcc-gfortran
  make which tar curl
  pkgconf-pkg-config
  readline-devel zlib-devel bzip2-devel xz-devel
  pcre2-devel libicu-devel libcurl-devel
  libX11-devel libXt-devel
  cairo-devel pango-devel
  libpng-devel libjpeg-turbo-devel libtiff-devel
  freetype-devel fontconfig-devel
  libwebp-devel
  harfbuzz-devel fribidi-devel
  openssl-devel libgit2-devel
  qpdf tidy
)
MATH_DEPS=( openblas-devel lapack-devel )

sudo dnf -y install "${BASE_DEPS[@]}" || true
sudo dnf -y install "${MATH_DEPS[@]}" || true
sudo dnf -y install ca-certificates openssl || true
sudo update-ca-trust || true

# =====[3] pandoc（系统包优先，失败则官方二进制） =====
ensure_pandoc_sys() {
  if dnf -q list pandoc >/dev/null 2>&1; then
    sudo dnf -y install pandoc && return 0
  fi
  return 1
}
ensure_pandoc_bin() {
  if command -v pandoc >/dev/null 2>&1; then return 0; fi
  echo ">>> 使用官方二进制安装 pandoc ${PANDOC_VER}"
  cd "$DOWNLOAD_DIR"
  rm -f "$PANDOC_TGZ"
  curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$PANDOC_TGZ" "$PANDOC_URL"
  [ -s "$PANDOC_TGZ" ] || { echo "pandoc 包下载失败"; exit 1; }
  sudo rm -rf "$PANDOC_PREFIX"
  sudo tar -xzf "$PANDOC_TGZ" -C /usr/local
  if ! grep -q "PANDOC_HOME=${PANDOC_PREFIX}" /etc/profile 2>/dev/null; then
    echo "export PANDOC_HOME=${PANDOC_PREFIX}" | sudo tee -a /etc/profile >/dev/null
    echo 'export PATH=$PANDOC_HOME/bin:$PATH' | sudo tee -a /etc/profile >/dev/null
  fi
  export PATH="$PANDOC_PREFIX/bin:$PATH"
  pandoc -v | head -n1
}
echo ">>> 安装 pandoc..."
if ! command -v pandoc >/dev/null 2>&1; then
  ensure_pandoc_sys || ensure_pandoc_bin
else
  echo "pandoc 已存在：$(pandoc -v | head -n1)"
fi

# =====[4] TeX Live（系统包优先，失败则官方 install-tl；固定国内仓库） =====
ensure_tex_sys() {
  local ok=0
  for p in texlive texlive-latex texlive-latex-bin texlive-amsmath texlive-collection-basic texlive-scheme-basic; do
    if dnf -q list "$p" >/dev/null 2>&1; then
      sudo dnf -y install "$p" && ok=1 || true
    fi
  done
  return $ok
}

download_install_tl_tarball() {
  echo ">>> 下载 TeX Live 安装器（多镜像 + TLS1.2 + 校验）"
  cd "$DOWNLOAD_DIR"; rm -f install-tl-unx.tar.gz
  CTAN_MIRRORS=(
    "https://mirrors.tuna.tsinghua.edu.cn/CTAN"
    "https://mirrors.ustc.edu.cn/CTAN"
    "https://mirrors.bfsu.edu.cn/CTAN"
    "https://mirrors.sjtug.sjtu.edu.cn/ctan"
    "https://mirror.ctan.org"
  )
  local download_ok=0
  for base in "${CTAN_MIRRORS[@]}"; do
    for scheme in https http; do
      local url="${base}/systems/texlive/tlnet/install-tl-unx.tar.gz"; url="${url/https:/$scheme:}"
      echo "尝试镜像：$url"
      if curl -L --retry 5 --retry-delay 2 --connect-timeout 20 --max-time 300 \
           --tlsv1.2 --speed-time 30 --speed-limit 10240 \
           -o install-tl-unx.tar.gz "$url"; then
        if [ -s install-tl-unx.tar.gz ] && [ "$(stat -c%s install-tl-unx.tar.gz)" -ge 1000000 ] \
           && tar -tzf install-tl-unx.tar.gz >/dev/null 2>&1; then
          echo "下载成功：$url"; download_ok=1; break 2
        else
          echo "校验失败（体积过小或非有效 tar.gz），切换镜像…"
        fi
      else
        echo "下载失败，切换镜像/协议…"
      fi
    done
  done
  [ "$download_ok" -eq 1 ] || { echo "所有镜像均失败。"; exit 1; }
}

ensure_tex_official() {
  if [ -x "${TL_BIN}/pdftex" ]; then return 0; fi
  download_install_tl_tarball
  rm -rf "${DOWNLOAD_DIR}/install-tl-unx"; mkdir -p "${DOWNLOAD_DIR}/install-tl-unx"
  tar -xzf "${DOWNLOAD_DIR}/install-tl-unx.tar.gz" -C "${DOWNLOAD_DIR}/install-tl-unx" --strip-components=1

  cat > "$TL_PROFILE" <<EOF
selected_scheme scheme-small
TEXDIR ${TL_PREFIX}
TEXMFLOCAL /opt/texlive/texmf-local
TEXMFSYSCONFIG ${TL_PREFIX}/texmf-config
TEXMFSYSVAR ${TL_PREFIX}/texmf-var
TEXMFVAR ~/.texlive${TL_YEAR}/texmf-var
TEXMFCONFIG ~/.texlive${TL_YEAR}/texmf-config
binary_x86_64-linux 1
instopt_adjustpath 0
instopt_adjustrepo 0
instopt_letter 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
EOF

  # 固定仓库，避免自动跳 MIT
  CTAN_CANDS=(
    "https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet"
    "https://mirrors.ustc.edu.cn/CTAN/systems/texlive/tlnet"
    "https://mirrors.bfsu.edu.cn/CTAN/systems/texlive/tlnet"
    "https://mirrors.sjtug.sjtu.edu.cn/ctan/systems/texlive/tlnet"
  )
  CTAN_REPO=""
  for u in "${CTAN_CANDS[@]}"; do
    curl -I --tlsv1.2 --connect-timeout 10 "$u/texlive.tlpdb" >/dev/null 2>&1 && { CTAN_REPO="$u"; break; }
  done
  [ -z "$CTAN_REPO" ] && CTAN_REPO="http://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet"
  echo "Using TeX Live repo: $CTAN_REPO"

  sudo mkdir -p "$(dirname "$TL_PREFIX")"; sudo chown -R "$(id -u)":"$(id -g)" "$(dirname "$TL_PREFIX")"
  (cd "${DOWNLOAD_DIR}/install-tl-unx" && ./install-tl -profile "$TL_PROFILE" -repository "$CTAN_REPO")

  if ! grep -q "TEXLIVE_HOME=${TL_PREFIX}" /etc/profile 2>/dev/null; then
    echo "export TEXLIVE_HOME=${TL_PREFIX}" | sudo tee -a /etc/profile >/dev/null
    echo 'export PATH=$TEXLIVE_HOME/bin/x86_64-linux:$PATH' | sudo tee -a /etc/profile >/dev/null
    echo 'export MANPATH=$TEXLIVE_HOME/texmf-dist/doc/man:$MANPATH' | sudo tee -a /etc/profile >/dev/null
    echo 'export INFOPATH=$TEXLIVE_HOME/texmf-dist/doc/info:$INFOPATH' | sudo tee -a /etc/profile >/dev/null
  fi
  export PATH="${TL_BIN}:$PATH"
  pdftex --version | head -n1 || true
}

echo ">>> 安装 TeX Live..."
if ! kpsewhich latex >/dev/null 2>&1; then
  if ! ensure_tex_sys; then
    echo "系统仓库不可用/不完整，使用官方 install-tl 兜底"
    ensure_tex_official
  else
    echo "已通过系统包安装到可用的 TeX 环境"
  fi
else
  echo "TeX 已存在：$(kpsewhich -var-value=TEXMFROOT 2>/dev/null || echo ok)"
fi

# =====[4b] TeX Live 宏包：latex 基础 + 推荐 + 字体等 =====
if command -v tlmgr >/dev/null 2>&1; then
  echo ">>> 安装/更新 LaTeX 常用集合与字体（用于 Rd2pdf/手册）..."
  # 固定仓库
  for u in \
    https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
    https://mirrors.ustc.edu.cn/CTAN/systems/texlive/tlnet \
    https://mirrors.bfsu.edu.cn/CTAN/systems/texlive/tlnet \
    https://mirrors.sjtug.sjtu.edu.cn/ctan/systems/texlive/tlnet; do
    if curl -I --tlsv1.2 --connect-timeout 8 "$u/texlive.tlpdb" >/dev/null 2>&1; then tlmgr option repository "$u"; break; fi
  done
  tlmgr update --self || true
  tlmgr install \
    latex-bin collection-latex collection-latexrecommended collection-latexextra \
    collection-fontsrecommended lmodern cm-super psnfss inconsolata \
    latexmk hyperref url xcolor geometry graphics oberdiek titlesec fancyvrb framed \
    etoolbox kvoptions iftex ifplatform upquote varwidth \
    hyphen-english babel-english || true
fi

# =====[5] 编译安装 R =====
echo ">>> 下载并编译 R-${R_VER} ..."
cd "$DOWNLOAD_DIR"
if [ ! -f "$R_TARBALL" ]; then
  curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$R_TARBALL" "$R_URL"
fi
rm -rf "$R_SRC_DIR"; tar -xzf "$R_TARBALL" -C "$DOWNLOAD_DIR"

cd "$R_SRC_DIR"
CFG=( "--prefix=$R_PREFIX" )
if rpm -q openblas-devel >/dev/null 2>&1 || ls /usr/lib*/libopenblas.* >/dev/null 2>&1; then
  CFG+=( --with-blas --with-lapack )
fi
./configure "${CFG[@]}"
make -j"$(nproc)"
sudo make install

if ! grep -q "R_HOME=$R_PREFIX" /etc/profile 2>/dev/null; then
  echo "export R_HOME=$R_PREFIX" | sudo tee -a /etc/profile >/dev/null
  echo 'export PATH=$R_HOME/bin:$PATH' | sudo tee -a /etc/profile >/dev/null
fi

# 当前会话立刻生效（包含 pandoc 与 TeX）
export PATH="$R_PREFIX/bin:${PANDOC_PREFIX}/bin:${TL_BIN}:$PATH"

echo ">>> 验证版本："
echo "- R 版本：$(R --version | head -n1)"
echo "- pandoc 版本：$(pandoc -v | head -n1 || echo '未检测到')"
echo "- latex 可用：$(kpsewhich latex >/dev/null 2>&1 && echo yes || echo no)"

# =====[6] 安装常用 R 包（包含 ragg、pkgdown、devtools） =====
echo ">>> 安装常用 R 包（ragg/pkgdown/devtools 等）..."
export R_LIBS_USER="${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
mkdir -p "$R_LIBS_USER"
Rscript -e "
options(repos=$CRAN_MIRRORS, Ncpus=parallel::detectCores());
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS='true');
pkgs <- c('ragg','pkgdown','devtools','knitr','rmarkdown','e1071','survival','httr2','gh','htmlwidgets','usethis','profvis','roxygen2','testthat');
need <- pkgs[!suppressWarnings(sapply(pkgs, function(p) requireNamespace(p, quietly=TRUE)))]
if (length(need)) install.packages(need) else message('All required packages already installed.')
"

# =====[7]（可选）SparkR Rd 自动修复 =====
#if [ "$RUN_SPARKR_RD_FIX" = "1" ]; then
#  if [ -z "$SPARKR_DIR" ] || [ ! -d "$SPARKR_DIR" ]; then
#    echo "RUN_SPARKR_RD_FIX=1 但未设置有效的 SPARKR_DIR，跳过 Rd 修复。"
#  else
#    echo ">>> 修复 SparkR Rd：\\url{..}{..} -> \\href{..}{..}，以及 \\itemize 缺括号"
#    MAN_DIR="$(find "$SPARKR_DIR" -type d -name man | head -n1 || true)"
#    if [ -z "$MAN_DIR" ]; then
#      echo "未找到 $SPARKR_DIR/man 目录，跳过 Rd 修复。"
#    else
#      BACKUP_DIR="$SPARKR_DIR/.rd_fix_backup_$(date +%Y%m%d_%H%M%S)"
#      mkdir -p "$BACKUP_DIR"; cp -a "$MAN_DIR" "$BACKUP_DIR"/
#      # \url{..}{..} -> \href{..}{..}
#      find "$MAN_DIR" -name '*.Rd' -print0 | while IFS= read -r -d '' f; do
#        perl -0777 -pe 's/\\url\{([^}]+)\}\{([^}]+)\}/\\href{$1}{$2}/g' -i "$f"
#      done
#      # 裸 \itemize -> \itemize{  并补右花括号
#      SECTION_RE='\\(name|alias|title|description|details|value|references|seealso|note|author|examples|keyword|concept|section)\\{'
#      find "$MAN_DIR" -name '*.Rd' -print0 | while IFS= read -r -d '' f; do
#        sed -i 's/^[[:space:]]*\\itemize[[:space:]]*$/\\itemize{/g' "$f"
#        awk -v SECTION_RE="$SECTION_RE" '
#          BEGIN{inlist=0}
#          {
#            line=$0
#            if (inlist==0 && line ~ /^[[:space:]]*\\itemize\{[[:space:]]*$/) { inlist=1; print line; next }
#            if (inlist==1) {
#              if (line ~ "^" SECTION_RE) { print "}"; inlist=0; print line; next }
#              if (line ~ /^[[:space:]]*\}[[:space:]]*$/) { inlist=0; print line; next }
#              print line; next
#            }
#            print line
#          }
#          END{ if (inlist==1) print "}" }
#        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
#      done
#      echo "SparkR Rd 修复完成。备份在：$BACKUP_DIR"
#    fi
#  fi
#fi

echo "===== DONE（Kylin V10 对齐 Rocky8：pandoc + TeX + R + 依赖 + 宏包就绪）====="
echo "提示：如需启用 SparkR Rd 自动修复，请在运行前导出："
echo "  export RUN_SPARKR_RD_FIX=1"
echo "  export SPARKR_DIR=/path/to/SparkR"
