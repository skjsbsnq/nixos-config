# NixOS 主配置 —— 图形化最小安装后直接替换 /etc/nixos/configuration.nix 使用。
#
# 【使用前必须核对的三处】
#   1. imports 里的 ./hardware-configuration.nix 用安装器生成的那个
#   2. boot.loader / networking.hostName / users 按安装器生成的值修改
#   3. system.stateVersion 保持安装器原值，不要升级这个数字
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix # 安装器生成，不要动
  ];

  # ---------- 引导 ----------
  # UEFI + systemd-boot（图形安装器默认）。如果用 GRUB 或 BIOS 启动，
  # 请保留安装器生成的 boot.loader.* 行并删掉下面两行。
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---------- 内核：linux-zen ----------
  boot.kernelPackages = pkgs.linuxPackages_zen;
  # zen 跟最新主线走。若某次升级后 nvidia-open 编译失败（内核太新驱动没跟上），
  # 可以把 nvidia 的 package 换成 config.boot.kernelPackages.nvidiaPackages.beta，
  # 或临时退回 pkgs.linuxPackages（默认 LTS 内核）。

  # ---------- Nix 本体 ----------
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Denial 官方 cachix 缓存（flake.nix 里也写了，这里再固化到系统 nix.conf）
    substituters = [
      "https://cache.nixos.org"
      "https://denial.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "denial.cachix.org-1:wd8YTnvPmugFrtdMJWtR1XdVknR3/g2nmBJkT+vAruo="
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  # QQ / 微信 / Chrome / NVIDIA 闭源组件都需要
  nixpkgs.config.allowUnfree = true;

  # ---------- 网络 / 本地化 ----------
  networking.hostName = "nixos"; # 改成你的主机名（要和 flake.nix 里的属性名一致）
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";
  # 双系统与 Windows 共存时取消下一行注释，避免时间打架
  # time.hardwareClockInLocalTime = true;

  i18n.defaultLocale = "zh_CN.UTF-8";
  # 想要英文界面中文输入，改成 "en_US.UTF-8" 即可，输入法不受影响

  # ---------- NVIDIA（开源内核模块 nvidia-open）----------
  # 仅支持 Turing(RTX20/GTX16) 及更新的 GPU；更老的卡改 open = false。
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam/32 位游戏需要
  };
  hardware.nvidia = {
    modesetting.enable = true; # Wayland 必需
    powerManagement.enable = true; # 修复睡眠/唤醒问题
    powerManagement.finegrained = false; # 笔记本混合显卡按需再开
    open = true; # nvidia-open 内核模块
    nvidiaSettings = true; # nvidia-settings 控制面板
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ---------- 声音 ----------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ---------- 蓝牙 / 其他硬件服务 ----------
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # 托盘管理（若桌面自带可删）
  services.printing.enable = true; # CUPS
  services.fstrim.enable = true; # SSD 定期 TRIM
  services.fwupd.enable = true; # 固件更新
  powerManagement.enable = true;
  services.gnome.gnome-keyring.enable = true; # Chrome/QQ 存密码需要 Secret Service

  # ---------- Steam / 游戏 ----------
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true; # Steam 大屏/gamescope 会话
  };
  programs.gamemode.enable = true;
  hardware.steam-hardware.enable = true; # 手柄等外设 udev 规则

  # ---------- LACT（显卡监控/超频，含 NVIDIA）----------
  services.lact.enable = true; # 提供 lactd 服务，打开 lact GUI 即用

  # ---------- fcitx5 中文输入法 ----------
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true; # Wayland 会话（Denial/GNOME Wayland）用原生协议
      addons = with pkgs; [
        fcitx5-chinese-addons # 拼音/双拼/五笔/云拼音
        fcitx5-gtk # GTK 程序输入法模块
        fcitx5-configtool # 图形配置工具
        # fcitx5-rime        # 想要 Rime/雾凇拼音就取消注释
      ];
      # 预置默认输入法列表：英文键盘 + 拼音，开箱按 Ctrl+Space 即可切
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "pinyin";
        };
        "Groups/0/Items/0" = {
          Name = "keyboard-us";
        };
        "Groups/0/Items/1" = {
          Name = "pinyin";
        };
        "GroupOrder" = {
          "0" = "Default";
        };
      };
    };
  };

  # ---------- 字体：Maple Mono NF CN unhinted + Noto CJK ----------
  fonts = {
    packages = with pkgs; [
      maple-mono.NF-CN-unhinted # Maple Mono NF CN（连字、无 hinting）
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      monospace = [
        "Maple Mono NF CN"
        "Noto Sans Mono CJK SC"
      ];
      sansSerif = [
        "Noto Sans CJK SC"
        "Noto Sans"
      ];
      serif = [
        "Noto Serif CJK SC"
        "Noto Serif"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # ---------- 兼容层：跑非 Nix 打包的二进制/AppImage ----------
  programs.nix-ld.enable = true; # 通用动态链接二进制
  services.envfs.enable = true; # 提供 /bin、/usr/bin 兼容
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  environment.localBinInPath = true; # ~/.local/bin 进 PATH（devin 官方脚本装这也认）

  # ---------- 软件包 ----------
  environment.systemPackages =
    with pkgs;
    [
      sparkle # Mihomo 代理 GUI（TUN/系统代理依赖下面的 SparkleService）
      qq
      wechat # 微信原生 Linux 版 4.x
      google-chrome
      telegram-desktop
      bottles
      protonplus # Proton-GE 等兼容层管理器（配合 Steam/Bottles）

      # 终端与常用工具（Denial 下建议先有个靠谱终端）
      kitty
      git
      vim
      wget
      curl
      wl-clipboard
      xdg-utils
      fastfetch

      (callPackage ./devin-cli.nix { }) # Devin CLI（静态二进制，本地打包）
    ];

  # Electron/Chromium 系应用走 Wayland 原生（QQ、Chrome、Sparkle 都吃这个变量）
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # Chrome 若输入法候选框不跟随，手动加启动参数:
  #   --ozone-platform=wayland --enable-wayland-ime=true
  # 或写 ~/.config/chrome-flags.conf

  # ---------- Kitty 系统级默认配置 ----------
  # kitty 会把 /etc/xdg/kitty/kitty.conf 作为系统默认加载，
  # 用户的 ~/.config/kitty/kitty.conf 仍可覆盖这里每一项。
  environment.etc."xdg/kitty/kitty.conf".text = ''
    font_family      Maple Mono NF CN
    bold_font        auto
    italic_font      auto
    bold_italic_font auto
    font_size        11

    # 毛玻璃：半透明 + 背景模糊
    background_opacity         0.72
    dynamic_background_opacity yes
    background_blur            32
    # 注意：background_blur 需要合成器支持 KDE blur 协议。
    # Denial 目前若不支持就只呈现半透明效果（opacity 仍然生效），
    # 在 KDE/GNOME 下模糊会自动出现。

    confirm_os_window_close 0
    scrollback_lines           10000
    enable_audio_bell          no
  '';

  # ---------- Sparkle 特权服务（系统代理 + TUN 必需）----------
  # Sparkle 在 Linux 上改代理/建 TUN 网卡都要经过这个 root 服务
  # （nixpkgs 已把 sparkle-service 编好链接进包内 resources/files）。
  # 这里复刻官方 `sparkle-service service install` 生成的单元，同名同参数，
  # 让 App 内"服务模式"开关直接可用。
  systemd.services.SparkleService = {
    description = "Sparkle Service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.sparkle}/share/sparkle/resources/files/sparkle-service service run";
      Restart = "always";
      RestartSec = 3;
    };
  };
  # 用法：打开 Sparkle 设置 -> 开启"服务模式"/TUN。若 App 提示服务未安装，
  # 检查 `systemctl status SparkleService` 和 /tmp/sparkle-service.sock。

  # ---------- 用户 ----------
  users.users.wwt = {
    # 改成你的用户名
    isNormalUser = true;
    description = "wwt";
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video"
      "i2c" # Denial 的 DDC 显示器亮度控制
    ];
    # 密码沿用安装时设置的；这里不写密码字段，已有哈希不受影响
  };

  # ---------- 状态版本 ----------
  # 保持安装器生成的值！它决定数据迁移行为，不是"系统版本号"。
  system.stateVersion = "26.05";
}
