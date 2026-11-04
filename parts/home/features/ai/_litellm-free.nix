# The LiteLLM "free" pool (parts/nixos/optional/ai/litellm.nix on cobalto) as
# opencode and pi config. Gemini and Mistral in the pool train on prompts.
{ lib, url }:
let
  model = "litellm/free";
  key = "/run/secrets/litellm-master-key";
in
{
  # Merge into an opencode.json: provider plus the free model on every agent.
  opencode = {
    inherit model;
    small_model = model;
    agent = lib.genAttrs [ "title" "summary" "compaction" "plan" "build" "general" ] (_: {
      inherit model;
    });
    provider.litellm = {
      npm = "@ai-sdk/openai-compatible";
      name = "LiteLLM free pool";
      options = {
        baseURL = url;
        apiKey = "{file:${key}}";
      };
      models.free.name = "Free (failover)";
    };
  };

  # pi's default model lives in its mutable settings.json, so pick
  # litellm/free once with /model and Ctrl+S.
  pi.".pi/agent/models.json".text = builtins.toJSON {
    providers.litellm = {
      baseUrl = url;
      api = "openai-completions";
      apiKey = "!cat ${key}";
      models = [ { id = "free"; } ];
    };
  };
}
