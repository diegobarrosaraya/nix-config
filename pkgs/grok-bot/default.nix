{ appimageTools, fetchurl }:
let
  version = "1.1.0";
  # The build hash in the URL changes with every release; update both together.
  build = "83d46d618ef4c12afa17edd8e3c29d6caf046d17";
in
appimageTools.wrapType2 {
  pname = "grok-bot";
  inherit version;
  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${build}/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-1w5UaS045tFt3x3Rf7zAeokuzMiQ4KWu38Ow4T5thx0=";
  };
}
