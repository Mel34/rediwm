{
  lib,
  tzdata,
  systemd,
  glibc,
  pulseaudio,
  dejavu_fonts,
  fontconfig,
  poppler_data,
}:

# Keep distro-specific paths in the packaging layer. --replace-fail makes
# upstream changes visible rather than silently shipping broken lookups.
''
  substituteInPlace src/polkit/native.c \
    --replace-fail 'const char *paths[] = {' 'const char *paths[] = {"/run/wrappers/bin/polkit-agent-helper-1", '
  substituteInPlace src/systemd_edit.zig \
    --replace-fail '/usr/bin/pkexec' '/run/wrappers/bin/pkexec' \
    --replace-fail 'else "/bin/pkexec"' 'else "/run/wrappers/bin/pkexec"' \
    --replace-fail '/usr/bin/systemctl' '${lib.getExe' systemd "systemctl"}' \
    --replace-fail 'else "/bin/systemctl"' 'else "${lib.getExe' systemd "systemctl"}"'
  substituteInPlace src/config_runtime/region.zig src/control_center/sections/region.zig \
    --replace-fail '/usr/share/zoneinfo' '${tzdata}/share/zoneinfo'
  substituteInPlace src/control_center/sections/region.zig \
    --replace-fail '/usr/bin/locale' '${lib.getBin glibc}/bin/locale'
  substituteInPlace src/audio/sounds.zig \
    --replace-fail '/usr/bin/paplay' '${lib.getExe' pulseaudio "paplay"}'
  # Permit only these font/character-map data directories after Landlock,
  # never the whole Nix store. The UI's selected fonts are opened beforehand.
  substituteInPlace src/pdf/sandbox.c \
    --replace-fail '/usr/share/fonts' '${dejavu_fonts}/share/fonts' \
    --replace-fail '/usr/local/share/fonts' '${dejavu_fonts.minimal}' \
    --replace-fail '/usr/share/fontconfig' '${fontconfig}/etc/fonts' \
    --replace-fail '/usr/share/poppler' '${poppler_data}/share/poppler'
''
