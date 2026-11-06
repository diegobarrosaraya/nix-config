# Skill dir layout for ai-skills extraSkillSources: $out/pretty-mermaid/SKILL.md
# with node_modules beside scripts/, so the skill's relative script paths work.
{ lib, buildNpmPackage, src }:

buildNpmPackage {
  pname = "pretty-mermaid-skill";
  version = "1.0.0";
  inherit src;

  dontNpmBuild = true;
  npmDepsHash = "sha256-NhPPp507jseWggWMvYOfll7visYEMQDuljGtk/LuoA4=";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/pretty-mermaid
    cp -r SKILL.md scripts references assets node_modules package.json $out/pretty-mermaid/
    runHook postInstall
  '';

  meta = {
    description = "Pretty Mermaid agent skill (beautiful-mermaid renderer, bundled with deps)";
    homepage = "https://github.com/imxv/Pretty-mermaid-skills";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
