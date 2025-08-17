{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    deno
    nil
    nixd
    zed-editor
  ];
}
