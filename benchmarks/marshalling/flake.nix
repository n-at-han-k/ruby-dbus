{
  description = "ruby-dbus ay marshalling benchmark";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      gtkGemInputs = with pkgs; [
        gtk4
        glib
        pango
        cairo
        gdk-pixbuf
        graphene
        gobject-introspection
        harfbuzz
        fribidi
        libthai
        libdatrie
        libepoxy
        libxkbcommon
        wayland
        vulkan-loader
        vulkan-headers
        libsysprof-capture
        libsepol
        libselinux
        pcre2
        util-linux
        libffi
        expat
        freetype
        fontconfig
        zlib
        libpng
        pixman
        libxcb
        libxrender
        libxext
        libx11
        xorgproto
        libpthread-stubs
        libxau
        libxdmcp
      ];

      gems = pkgs.bundlerEnv {
        name = "ruby-dbus-ay-bench-gems";
        ruby = pkgs.ruby_3_4;
        gemfile = ./Gemfile;
        lockfile = ./Gemfile.lock;
        gemset = import ./gemset.nix;
        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = attrs: {
            nativeBuildInputs = [
              pkgs.pkg-config
            ];
            buildInputs = gtkGemInputs;
          };
          gtk4 = attrs: {
            nativeBuildInputs = [
              pkgs.pkg-config
              pkgs.gobject-introspection
            ];
            buildInputs = gtkGemInputs;
          };
        };
      };

      typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0" (with pkgs; [
        glib.out
        gtk4.out
        pango.out
        gdk-pixbuf.out
        graphene.out
        cairo.out
        harfbuzz.out
        gobject-introspection.out
      ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          gems
          gems.wrappedRuby
        ];
        GI_TYPELIB_PATH = typelibPath;
      };

      apps.${system} = {
        benchmarks = {
          type = "app";
          program = toString (pkgs.writeShellScript "benchmarks" ''
            set -euo pipefail
            nix develop --command ./new.rb
            nix develop --command ./old.rb
          '');
        };
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/microvm-run";
        };
      };

      packages.${system}.default = self.nixosConfigurations.bench.config.microvm.declaredRunner;

      nixosConfigurations.bench = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          ({ pkgs, lib, ... }: {
            system.stateVersion = lib.trivial.release;
            networking.hostName = "ruby-dbus-bench";
            networking.useDHCP = false;
            networking.firewall.enable = false;
            services.dbus.enable = true;
            boot.kernelParams = [ "console=ttyS0" ];

            environment.systemPackages = [
              gems
              gems.wrappedRuby
              pkgs.dbus
              pkgs.weston
            ];

            environment.etc."ruby-dbus".source = ../..;

            microvm = {
              hypervisor = "qemu";
              mem = 3072;
              vcpu = 2;
            };

            systemd.services.ruby-dbus-bench = {
              wantedBy = [ "multi-user.target" ];
              after = [
                "dbus.service"
              ];
              path = [
                gems
                gems.wrappedRuby
                pkgs.dbus
                pkgs.weston
                pkgs.coreutils
              ];
              environment = {
                GI_TYPELIB_PATH = typelibPath;
                XDG_RUNTIME_DIR = "/run/user/0";
              };
              serviceConfig = {
                Type = "simple";
                StandardOutput = "journal+console";
                StandardError = "journal+console";
                WorkingDirectory = "/etc/ruby-dbus/benchmarks/marshalling";
                ExecStart = pkgs.writeShellScript "run-benchmarks" ''
                  set -euo pipefail
                  mkdir -p "$XDG_RUNTIME_DIR"
                  eval "$(dbus-launch --sh-syntax)"

                  weston --backend=headless-backend.so --socket=wl-bench --idle-time=0 --width=800 --height=600 &
                  WESTON_PID=$!
                  export WAYLAND_DISPLAY=wl-bench
                  sleep 2

                  timeout 15 ${gems.wrappedRuby}/bin/ruby ./new.rb || true
                  timeout 15 ${gems.wrappedRuby}/bin/ruby ./old.rb || true

                  kill "$WESTON_PID" 2>/dev/null || true
                '';
              };
            };
          })
        ];
      };
    };
}
