{ ... }:
{
  flake.modules.nixos.ai-litellm =
{ config, ... }:

let
  # One deployment in the group "free". Lower order is tried first. rpm stays
  # below the provider's own limit so the router skips it before it trips.
  free = order: rpm: model: params: {
    model_name = "free";
    litellm_params = { inherit model order rpm; } // params;
  };
  key = name: { api_key = "os.environ/${name}"; };
in
{
  # One local endpoint for free tiers only. OpenCode Go is not here: it refuses
  # proxied calls (missing x-opencode-session), so Hermes and opencode call it
  # directly. "free" is for public work only, never for Hermes chat or private
  # data. Providers that train on prompts (Gemini, Mistral) come last.
  # No database: no budgets or key management yet, so stateDir holds nothing
  # that must survive a reboot.
  services.litellm = {
    enable = true;
    # All interfaces so rubi reaches it over Tailscale. Port 4000 is not in
    # allowedTCPPorts, so the firewall only lets it in on tailscale0 (trusted).
    host = "0.0.0.0";
    port = 4000;
    environmentFile = config.sops.templates."litellm.env".path;
    settings = {
      model_list = [
        # All OpenRouter :free models share one account limit (20 RPM), so the
        # two together stay under it.
        (free 1 9 "openrouter/cohere/north-mini-code:free" (key "OPENROUTER_API_KEY"))
        (free 2 9 "openrouter/google/gemma-4-31b-it:free" (key "OPENROUTER_API_KEY"))
        (free 3 20 "openai/nvidia/nemotron-3-ultra-550b-a55b" (key "NVIDIA_API_KEY" // {
          api_base = "https://integrate.api.nvidia.com/v1";
        }))
        # shortcut: the Groq rpm is a guess below the usual free limit, set it
        # from the console's limits page.
        (free 4 20 "groq/openai/gpt-oss-120b" (key "GROQ_API_KEY"))
        # Cerebras Free Trial: 5 RPM, 1M tokens per day.
        (free 5 4 "cerebras/gpt-oss-120b" (key "CEREBRAS_API_KEY"))
        # shortcut: Gemini free limits are shown only per project in AI Studio,
        # set rpm from aistudio.google.com/rate-limit.
        # 3.6-flash answered on the free tier; 3.8-flash returned 503 high demand.
        (free 6 8 "gemini/gemini-3.6-flash" (key "GEMINI_API_KEY"))
        # mistral-large is not on the free tier (403 tier_not_allowed); codestral is.
        (free 7 30 "mistral/codestral-latest" (key "MISTRAL_API_KEY"))
      ];
      # A failed deployment cools for 30 minutes and the group moves to the next
      # order by itself. num_retries above 0 only re-called the same limited
      # deployments: with 7, one request made 44 upstream calls when all were
      # limited; with 0, one call per deployment (tested locally). Nous is not
      # here: the Portal free tier gives no API key, only Hermes's own login.
      router_settings = {
        num_retries = 0;
        allowed_fails = 0;
        cooldown_time = 1800;
        enable_pre_call_checks = true;
      };
      # Providers reject parameters they do not know; drop them instead.
      litellm_settings.drop_params = true;
      general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
    };
  };

  sops.secrets = {
    # diego's opencode and pi read it to call the pool (parts/home/{cobalto,rubi}.nix).
    # rubi holds a copy of the same value in its own secrets.yaml.
    "litellm-master-key".owner = "diego";
    "gemini-api-key" = { };
    "openrouter-api-key" = { };
    "groq-api-key" = { };
    "cerebras-api-key" = { };
    "mistral-api-key" = { };
  };
  sops.templates."litellm.env" = {
    content = ''
      LITELLM_MASTER_KEY=${config.sops.placeholder."litellm-master-key"}
      NVIDIA_API_KEY=${config.sops.placeholder."hermes-nvidia-api-key"}
      GEMINI_API_KEY=${config.sops.placeholder."gemini-api-key"}
      OPENROUTER_API_KEY=${config.sops.placeholder."openrouter-api-key"}
      GROQ_API_KEY=${config.sops.placeholder."groq-api-key"}
      CEREBRAS_API_KEY=${config.sops.placeholder."cerebras-api-key"}
      MISTRAL_API_KEY=${config.sops.placeholder."mistral-api-key"}
    '';
    restartUnits = [ "litellm.service" ];
  };
}
  ;
}
