{
  description = "NixOS 桌面系统 (zen kernel + NVIDIA open + Denial WM)";

  # Denial 官方二进制缓存。子 flake 的 nixConfig 不会生效，必须在顶层再声明一次。
  # 没有这个缓存，cache miss 时会从源码编译整套 Flutter 引擎（验证机上需要 >48GiB 临时空间）。
  nixConfig = {
    extra-substituters = [ "https://denial.cachix.org" ];
    extra-trusted-public-keys = [
      "denial.cachix.org-1:wd8YTnvPmugFrtdMJWtR1XdVknR3/g2nmBJkT+vAruo="
    ];
  };

  inputs = {
    # 当前 stable 分支。想用滚动版可改成 "github:NixOS/nixpkgs/nixos-unstable"
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Denial 是 Flutter-native Wayland compositor（公开 alpha，仅 x86_64-linux）。
    # 注意：刻意不要写 denial.inputs.nixpkgs.follows——它要求用其锁定的 nixpkgs 构建。
    denial.url = "github:denialwm/denial";
  };

  outputs =
    { nixpkgs, denial, ... }:
    {
      # 属性名约定与 networking.hostName 一致；install.sh 会自动改成实际主机名。
      # 用引号写法兼容主机名含连字符的情况。
      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix # 主配置（不含 Denial，可脱离 flake 单独 rebuild）
          denial.nixosModules.default # Denial 官方 NixOS 模块
          ./denial.nix # Denial 桌面 + greetd 登录器
        ];
      };
    };
}
