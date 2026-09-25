# Denial WM + 登录管理器。
# 这个文件只在 flake 构建时生效（依赖 denial.nixosModules.default 提供的
# programs.denial 选项），纯 channel 的 nixos-rebuild 请忽略它。
{ config, ... }:

{
  # Denial 官方模块：注册 wayland-session、portal、polkit agent、
  # xwayland、rtkit、DDC 显示器控制、CJK 回退字体等。
  programs.denial.enable = true;

  # ---- 显示管理器：COSMIC Greeter ----
  # System76 COSMIC 的登录界面，自带会话列表（Denial 会自动出现在菜单里）。
  # 该模块内部已启用 greetd + cosmic-comp，不要重复开 services.greetd。
  # 如果安装器已经装了 GNOME/KDE（有 GDM/SDDM），请只保留一个 DM，
  # 在登录界面会话菜单里选 "Denial" 即可。
  services.displayManager.cosmic-greeter.enable = true;

  # 想开机免密直接进 Denial，取消注释（改用户名）：
  # services.displayManager.autoLogin = {
  #   enable = true;
  #   user = "wwt";
  # };

  # Denial 的机器级默认配置可被覆盖，例如固定显示器布局：
  # environment.etc."denial/outputs.conf".source = ./outputs.conf;
  # environment.etc."denial/session.conf".source = ./session.conf;
}
