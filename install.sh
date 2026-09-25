#!/usr/bin/env bash
# ============================================================
# NixOS 一键配置脚本
#
# 适用场景：图形化最小安装完成后，把系统一次配好
# （zen 内核 + NVIDIA open + fcitx5 + Maple Mono 字体 +
#   Steam/QQ/微信/Chrome/Sparkle/Bottles/ProtonPlus/LACT +
#   Denial WM + cosmic-greeter + Devin CLI）
#
# 用法：
#   bash install.sh            # 完整流程：备份 -> 拷贝 -> 个性化 -> 构建
#   bash install.sh prepare    # 只做准备工作（方便人工检查配置后再构建）
#   bash install.sh build      # 只做构建（之前已跑过 prepare）
#
# 可覆盖变量：USER_NAME=xxx HOST_NAME=yyy bash install.sh
#
# 刚装完的最小系统上没有这个仓库时，任选一种方式拉下来：
#   curl -L https://github.com/skjsbsnq/nixos-config/archive/refs/heads/main.tar.gz | tar xz
#   nix-shell -p git --run 'git clone https://github.com/skjsbsnq/nixos-config.git'
# 然后进目录执行 bash install.sh
# ============================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR=/etc/nixos
MODE="${1:-all}"

USER_NAME="${USER_NAME:-$(id -un)}"
HOST_NAME="${HOST_NAME:-$(hostname)}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------- 环境检查 ----------------
[ -f /etc/NIXOS ] || die "本脚本要在已安装好的 NixOS 系统上运行（不是安装介质）"
command -v nixos-rebuild >/dev/null || die "找不到 nixos-rebuild"
for f in flake.nix configuration.nix denial.nix devin-cli.nix; do
  [ -f "$REPO_DIR/$f" ] || die "仓库目录里缺少 $f"
done
info "用户名=$USER_NAME  主机名=$HOST_NAME（可用 USER_NAME=/HOST_NAME= 环境变量覆盖）"

sudo -v
# 构建可能跑很久，保活 sudo 凭证
( while true; do sudo -n true 2>/dev/null; sleep 60; done ) &
SUDO_ALIVE=$!
trap 'kill $SUDO_ALIVE 2>/dev/null || true' EXIT

prepare() {
  # ---------- 1. 备份 ----------
  local bak="${NIXOS_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  info "备份 $NIXOS_DIR -> $bak"
  sudo cp -a "$NIXOS_DIR" "$bak"
  local old_cfg="$bak/configuration.nix"

  # ---------- 2. 拷贝仓库配置（不动 hardware-configuration.nix）----------
  info "拷贝 flake.nix / configuration.nix / denial.nix / devin-cli.nix 到 $NIXOS_DIR"
  sudo install -m644 \
    "$REPO_DIR/flake.nix" "$REPO_DIR/configuration.nix" \
    "$REPO_DIR/denial.nix" "$REPO_DIR/devin-cli.nix" \
    "$NIXOS_DIR/"

  if [ ! -f "$NIXOS_DIR/hardware-configuration.nix" ]; then
    warn "未找到 hardware-configuration.nix，自动重新生成"
    sudo nixos-generate-config --show-hardware-config \
      | sudo tee "$NIXOS_DIR/hardware-configuration.nix" >/dev/null
  fi

  # ---------- 3. 个性化：主机名 / 用户名 / stateVersion ----------
  info "写入主机名 $HOST_NAME、用户名 $USER_NAME"
  sudo sed -i \
    -e "s/networking\.hostName = \"[^\"]*\"/networking.hostName = \"$HOST_NAME\"/" \
    -e "s/users\.users\.wwt/users.users.$USER_NAME/" \
    -e "s/description = \"wwt\"/description = \"$USER_NAME\"/" \
    "$NIXOS_DIR/configuration.nix"
  sudo sed -i "s/nixosConfigurations\.\"[^\"]*\"/nixosConfigurations.\"$HOST_NAME\"/" \
    "$NIXOS_DIR/flake.nix"
  sudo sed -i "s/user = \"wwt\"/user = \"$USER_NAME\"/" "$NIXOS_DIR/denial.nix"

  if [ -f "$old_cfg" ]; then
    # stateVersion 必须沿用安装器生成的值
    local sv
    sv="$(grep -oE 'system\.stateVersion *= *"[^"]+"' "$old_cfg" | head -1 | grep -oE '[0-9.]+' || true)"
    if [ -n "$sv" ]; then
      info "沿用安装器的 system.stateVersion = $sv"
      sudo sed -i "s/system\.stateVersion = \"[^\"]*\"/system.stateVersion = \"$sv\"/" \
        "$NIXOS_DIR/configuration.nix"
    fi

    # bootloader 沿用安装器生成的 boot.loader.*（覆盖脚本自带的 systemd-boot 默认值）
    local boot_lines boot_tmp
    boot_lines="$(grep -oE '^\s*boot\.loader\.[A-Za-z0-9_.-]+\s*=[^;]+;' "$old_cfg" | sed 's/^[[:space:]]*//' | sort -u || true)"
    if [ -n "$boot_lines" ]; then
      info "沿用安装器的 boot.loader 配置"
      boot_tmp="$(mktemp)"
      printf '%s\n' "$boot_lines" | sed 's/^/    /' > "$boot_tmp"
      sudo sed -i \
        -e '/boot\.loader\.systemd-boot\.enable = true;/d' \
        -e '/boot\.loader\.efi\.canTouchEfiVariables = true;/d' \
        "$NIXOS_DIR/configuration.nix"
      sudo sed -i "/# ---------- 引导 ----------/r $boot_tmp" "$NIXOS_DIR/configuration.nix"
      rm -f "$boot_tmp"
    else
      warn "旧配置中没找到 boot.loader.* 行，保留默认 systemd-boot(UEFI)；BIOS/GRUB 请手动改 configuration.nix"
    fi

    # 提示：旧配置如果装了桌面环境/登录器，会和 cosmic-greeter 冲突
    local de_lines
    de_lines="$(grep -oE '^\s*services\.(xserver\.)?(displayManager|desktopManager)\.[a-zA-Z0-9_.-]+\s*=\s*true' "$old_cfg" || true)"
    if [ -n "$de_lines" ]; then
      warn "旧配置启用了桌面/登录管理器（已被本配置移除，不会迁移）："
      printf '    %s\n' "$de_lines"
      warn "如需保留请在 configuration.nix 里加回对应行；和 cosmic-greeter 只留一个 DM"
    fi
  else
    warn "未找到旧 configuration.nix，bootloader 用默认 systemd-boot(UEFI)、stateVersion 用仓库默认值"
  fi

  info "准备完成。可以检查 $NIXOS_DIR/configuration.nix 后执行: bash install.sh build"
}

build() {
  info "开始构建（首次要下载/编译 zen 内核、NVIDIA 驱动、Denial 等，会比较久）"
  # 首次 rebuild 前 flakes 还没启用，用 NIX_CONFIG 临时打开；
  # denial.cachix.org 缓存由 flake.nix 的 nixConfig 提供（root 是受信用户自动生效）
  sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
    nixos-rebuild switch --flake "$NIXOS_DIR#$HOST_NAME"

  cat <<EOF

$(printf '\033[1;32m✔ 完成\033[0m')  建议重启进入新系统（新内核 + 显示管理器都要重启生效）

  重启后：
    • 登录界面是 COSMIC Greeter，会话选择 Denial
    • Sparkle：设置里打开"服务模式"后 TUN/系统代理才可用
    • Devin CLI：终端输入 devin，按提示登录
    • 输入法：Ctrl+Space 切换中/英
EOF
}

case "$MODE" in
  all)     prepare; build ;;
  prepare) prepare ;;
  build)   build ;;
  *)       die "未知参数 $MODE（可用: all / prepare / build）" ;;
esac
