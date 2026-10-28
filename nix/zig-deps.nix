{
  stdenvNoCC,
  zig_0_17,
  cacert,
}:

# Only this fixed-output fetch may access the network. The actual build
# receives the verified package cache and runs completely offline.
stdenvNoCC.mkDerivation {
  pname = "rediwm-zig-deps";
  version = "1";
  src = ../build.zig.zon;
  dontUnpack = true;
  nativeBuildInputs = [
    zig_0_17
    cacert
  ];
  dontConfigure = true;
  dontInstall = true;
  dontFixup = true;
  buildPhase = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    cp "$src" build.zig.zon
    touch build.zig
    zig build --fetch
    mkdir -p "$out"
    cp -R "$ZIG_GLOBAL_CACHE_DIR/p" "$out/p"
  '';
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-Bm0/CoGiYtscJWFCDKVEiUmA59n9PATonIuEjOBr3GM=";
}
