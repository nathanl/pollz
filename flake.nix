{
  description = "Development environment for the Pollz project";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05-small";
    # Pinned to Elixir 1.19.3 + Erlang 28.1.1. To upgrade, find a nixpkgs commit
    # after the desired version bump and update this SHA + run `nix flake update nixpkgs-unstable`.
    # Window: nixpkgs@8c39c423 (Elixir 1.19.3, 2025-11-14) .. nixpkgs@fea32a68 (Erlang 28.2, 2025-11-24)
    nixpkgs-unstable.url = "github:nixos/nixpkgs/dbff0491a2f9961ba647b5f022195891c2924254";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs-unstable, nixpkgs-stable, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        stablePkgs = import nixpkgs-stable.outPath {
          inherit system;
          config.allowUnfree = true;
          config.allowBroken = true;
        };
        unstablePkgs = import nixpkgs-unstable.outPath {
          inherit system;
          config.allowUnfree = true;
        };
        # postgresql is sourced from stablePkgs for the timescaledb extension ABI;
        # timescaledb-tune (unstablePkgs) is a standalone CLI tool with no ABI dependency.
        postgresql = stablePkgs.postgresql_16.withPackages (ps: with ps; [
          timescaledb
          timescaledb_toolkit
        ]);
      in
      {
        devShells.default = unstablePkgs.mkShell {
          name = "Pollz Nix Shell";

          packages = with unstablePkgs; [
            exiftool
            postgresql
            timescaledb-tune
            beam.interpreters.erlang_28
            beam28Packages.elixir_1_19
          ];
        };
      });
}
