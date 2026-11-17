{
  appimageTools,
  fetchurl,
}:
let
  pname = "orca";
  version = "1.4.261";
  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-/33kkAhWr4B4Xlqx/jAaPQ3wmi0CMA/QThIJTocarEc=";
  };
  # wrapType2 does not install the AppImage's desktop entry or icons.
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm444 ${contents}/orca-ide.desktop $out/share/applications/orca.desktop
    substituteInPlace $out/share/applications/orca.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=orca'
    mkdir -p $out/share/icons
    cp -r ${contents}/usr/share/icons/hicolor $out/share/icons/
  '';
}
