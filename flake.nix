{
  description = "Patched version of Caddy";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in
    {

      # Provide some binary packages for selected system types.
      packages = forAllSystems
        (
          system:
          let
            version = "2.10.0";

            pkgs = nixpkgsFor.${system};
            dist = pkgs.fetchFromGitHub {
              owner = "caddyserver";
              repo = "dist";
              tag = "v${version}";
              hash = "sha256-us1TnszA/10OMVSDsNvzRb6mcM4eMR3pQ5EF4ggA958=";
            };
          in
          {

            caddy = pkgs.buildGoModule {
              pname = "caddy";
              inherit version;
              src = ./caddy-src;
              runVend = true;
              vendorHash = "sha256-umakzDzEOX/wBfV6DEB62g4DffIzyCw4u0QnLH08SdU=";
              # vendorHash = pkgs.lib.fakeHash;
              postInstall = ''
                install -Dm644 ${dist}/init/caddy.service ${dist}/init/caddy-api.service -t $out/lib/systemd/system

                substituteInPlace $out/lib/systemd/system/caddy.service \
                  --replace-fail "/usr/bin/caddy" "$out/bin/caddy"
                substituteInPlace $out/lib/systemd/system/caddy-api.service \
                  --replace-fail "/usr/bin/caddy" "$out/bin/caddy"
              '';
              meta = {
                homepage = "https://caddyserver.com";
                description = "Fast and extensible multi-platform HTTP/1-2-3 web server with automatic HTTPS";
                license = pkgs.lib.licenses.asl20;
                mainProgram = "caddy";
                maintainers = with pkgs.lib.maintainers; [
                  Br1ght0ne
                  emilylange
                  techknowlogick
                ];
              };
            };
            default = self.packages.${system}.caddy;
          }
        );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ go ];
          };
        }
      );

    };
}
