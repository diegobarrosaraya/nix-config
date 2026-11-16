{ appimageTools, fetchurl }:
let
  version = "1.4.261";
in
appimageTools.wrapType2 {
  pname = "orca";
  inherit version;
  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-/33kkAhWr4B4Xlqx/jAaPQ3wmi0CMA/QThIJTocarEc=";
  };
}
