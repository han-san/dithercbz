{
  description = "A script that applies a dithering effect on images in cbz/cbr files.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    name = "dithercbz";
  in
    {
      packages.${system} = {
        ${name} = pkgs.writeShellApplication {
          name = "${name}";
          runtimeInputs = with pkgs; [ imagemagick parallel p7zip ];
          text = builtins.readFile ./dithercbz.bash;
        };
        default = self.packages.${system}.${name};
      };
    };
}
