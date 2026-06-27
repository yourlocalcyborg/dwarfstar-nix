{
  description = "DwarfStar (antirez ds4) — DeepSeek V4 inference runtime, ROCm build for AMD Strix Halo (gfx1151)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      ds4 = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        inherit ds4;
        default = ds4;
        # Convenience variant for an RDNA3 discrete GPU; adjust as needed.
        ds4-gfx1100 = pkgs.callPackage ./package.nix { rocmArch = "gfx1100"; };
      };

      apps.${system}.default = {
        type = "app";
        program = "${ds4}/bin/ds4";
      };

      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ ds4 ];
        packages = [ pkgs.rocmPackages.rocminfo pkgs.rocmPackages.rocm-smi ];
      };
    };
}
