{
  appimageTools,
  fetchurl,
}:
let
  pname = "grok-bot";
  version = "1.1.0";
  # The build hash in the URL changes with every release; update both together.
  build = "83d46d618ef4c12afa17edd8e3c29d6caf046d17";
  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${build}/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-1w5UaS045tFt3x3Rf7zAeokuzMiQ4KWu38Ow4T5thx0=";
  };
  # wrapType2 does not install the AppImage's desktop entry or icons.
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm444 ${contents}/grok-bot.desktop $out/share/applications/grok-bot.desktop
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=grok-bot'
    mkdir -p $out/share/icons
    cp -r ${contents}/usr/share/icons/hicolor $out/share/icons/
  '';
}
