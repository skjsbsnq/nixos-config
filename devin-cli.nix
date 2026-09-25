# Devin CLI —— Cognition 的官方命令行 agent。
# nixpkgs 里没有包，这里直接拉官方预编译包。Linux 版是 static-pie
# 静态链接二进制，不需要 patchelf，解压即用。
#
# 升级方法：去 https://static.devin.ai/cli/current/manifest.json 看最新
# version 和对应 x86_64-unknown-linux 的 sha256，改掉下面两处即可。
# 不想被 nix 管的话，也可以删掉这个文件，改用官方脚本（装到 ~/.local/bin，
# 可自行更新）：
#   curl -fsSL https://cli.devin.ai/install.sh | bash
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "devin-cli";
  version = "3000.11.3";

  src = fetchurl {
    url = "https://static.devin.ai/cli/${finalAttrs.version}/devin-${finalAttrs.version}-x86_64-unknown-linux.tar.gz";
    sha256 = "83b3b113c01bf2a3e9e100db08d77e6b086806a7754f091e20831bdfe215157e";
  };

  # tar 包顶层就是 bin/ 和 share/，没有包裹目录
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/devin $out/bin/devin
    cp -r share $out/share
    runHook postInstall
  '';

  meta = {
    description = "Devin CLI - local coding agent from Cognition";
    homepage = "https://devin.ai/cli";
    license = lib.licenses.unfree;
    mainProgram = "devin";
    platforms = [ "x86_64-linux" ];
  };
})
