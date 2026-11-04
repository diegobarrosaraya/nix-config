{ config, inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  lib = inputs.nixpkgs.lib;
  hermes = config.flake.nixosConfigurations.cobalto.config.services.hermes-agent;
  # Closed list of team roles: later tasks declare the rest.
  roles = [ "planner" "coder-light" "coder-heavy" "reviewer" "tester" "security" "integrator" ];
in
{
  # Hermes must have one path for code work: the claude-<name> CLI. A generated
  # AGENTS.md that points at delegate_task caused the failed handover of 2026-10-29.
  flake.checks.x86_64-linux.hermes-agents-md =
    pkgs.runCommand "hermes-agents-md"
      {
        agentsMd = hermes.documents."AGENTS.md";
        disabled = builtins.toJSON hermes.settings.agent.disabled_toolsets;
        declared = lib.concatStringsSep "\n" (builtins.attrNames hermes.profiles);
        passAsFile = [ "agentsMd" ];
      }
      ''
        # Only the "Never use ..." rule may name these tools.
        if grep -nE 'delegate_task|execute_code|acp_command' "$agentsMdPath" | grep -v 'Never use'; then
          echo "AGENTS.md points at delegate_task, execute_code or acp_command for code work" >&2
          exit 1
        fi
        for t in delegation code_execution; do
          echo "$disabled" | grep -q "\"$t\"" || { echo "agent.disabled_toolsets lacks $t" >&2; exit 1; }
        done
        # A role named in backticks that no profile declares sends a card to nobody.
        for r in ${lib.concatStringsSep " " roles}; do
          if grep -q "\`$r\`" "$agentsMdPath" && ! echo "$declared" | grep -qx "$r"; then
            echo "AGENTS.md mentions role $r, which is not a declared profile" >&2
            exit 1
          fi
        done
        touch $out
      '';

  # Profile names become directory names and CLI arguments, and each soul is
  # copied at boot: a bad name or missing file must fail at build time.
  flake.checks.x86_64-linux.hermes-profiles-names =
    let
      names = builtins.attrNames hermes.profiles;
      bad = builtins.filter (n: builtins.match "[a-z0-9][a-z0-9-]*" n == null) names;
      missing = builtins.filter (n: !builtins.pathExists hermes.profiles.${n}.soul) names;
    in
    assert bad == [ ] || throw "bad hermes profile names: ${toString bad}";
    assert missing == [ ] || throw "hermes profile soul missing: ${toString missing}";
    pkgs.runCommand "hermes-profiles-names" { } "touch $out";

  # A read-only profile must not get a shell or a path to other agents, and only
  # the integrator may carry credentials: both are cheap to break by a config edit.
  flake.checks.x86_64-linux.hermes-profiles-readonly =
    let
      lib = inputs.nixpkgs.lib;
      # Read-only profiles that may still list `terminal`: security runs the scan and three read-only git commands,
      # and its prompt limits it to those. The missing-cli rule still applies.
      terminalAllowed = [ "security" ];
      # Every attribute name under a value, at any depth, through lists too (fallback_providers is a list of attrsets).
      keys = v:
        if builtins.isAttrs v then lib.concatLists (lib.mapAttrsToList (k: x: [ k ] ++ keys x) v)
        else if builtins.isList v then lib.concatMap keys v
        else [ ];
      get = p: path: lib.attrByPath path [ ] hermes.profiles.${p}.settings;
      names = builtins.attrNames hermes.profiles;
      ro = builtins.filter (n: hermes.profiles.${n}.readOnly) names;
      # An unset cli list falls back to Hermes's hermes-cli preset, which includes terminal.
      cliOk = n: builtins.isList (lib.attrByPath [ "platform_toolsets" "cli" ] null hermes.profiles.${n}.settings);
      errs =
        (map (n: "${n}: readOnly profile must set platform_toolsets.cli to a list (the default preset includes terminal)")
          (builtins.filter (n: !cliOk n) ro))
        ++ (map (n: "${n}: readOnly profile lists terminal in platform_toolsets.cli")
          (builtins.filter (n: cliOk n && builtins.elem "terminal" (get n [ "platform_toolsets" "cli" ]) && !builtins.elem n terminalAllowed) ro))
        ++ lib.concatMap (n:
          map (t: "${n}: readOnly profile does not disable ${t}")
            (builtins.filter (t: !builtins.elem t (get n [ "agent" "disabled_toolsets" ])) [ "delegation" "code_execution" ])) ro
        ++ lib.concatMap (n:
          map (k: "${n}: credential-like key '${k}' in settings (only integrator may have one)")
            (builtins.filter (k: lib.hasInfix "credential" (lib.toLower k) || lib.hasInfix "token" (lib.toLower k))
              (keys hermes.profiles.${n}.settings)))
          (builtins.filter (n: n != "integrator") names);
    in
    assert errs == [ ] || throw "hermes-profiles-readonly: ${lib.concatStringsSep "; " errs}";
    pkgs.runCommand "hermes-profiles-readonly" { } "touch $out";

  # The security gate is a script because a weak model cannot be trusted to run
  # shell pipelines. Synthetic terms only: no real term may appear in the repo.
  # Each variant bakes in its own term file, like the shipped binary does.
  flake.checks.x86_64-linux.hermes-security-scan =
    let
      scanWith = args: "${import ../pkgs/hermes-security-scan.nix ({ inherit pkgs; } // args)}/bin/hermes-security-scan";
      # Padding, CRLF, a blank and a whitespace-only line, and a regex-special term.
      terms = pkgs.writeText "terms" "  ZZZ-fake-term-one  \r\nYYY-fake-term-two\r\n\r\n   \r\nq.w\\e*[r\r\n";
      blank = pkgs.writeText "blank" "\n  \r\n\n";
      scan = scanWith { inherit terms; };
      scanBlank = scanWith { terms = blank; };
      scanMissing = scanWith { terms = "/nonexistent"; };
      # A gitleaks that exits 1 without a report, like a fatal error does.
      scanBadLeaks = scanWith { inherit terms; gitleaks = pkgs.writeShellScriptBin "gitleaks" "exit 1"; };
    in
    pkgs.runCommand "hermes-security-scan"
      { nativeBuildInputs = [ pkgs.git ]; }
      ''
        export HOME=$PWD GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

        # run WANT SCAN ARGS...: output lands in ../out
        run() {
          want=$1; s=$2; shift 2
          set +e; "$s" "$@" > ../out 2>&1; rc=$?; set -e
          [ "$rc" = "$want" ] || { echo "FAIL: $* gave $rc, wanted $want"; cat ../out; exit 1; }
        }
        # The output must never carry term text.
        nofake() { if grep -qiE 'fake-term|q.w.e' ../out; then echo "FAIL: term text printed"; cat ../out; exit 1; fi; }

        git init -q repo && cd repo
        printf "hello\n" > a.txt
        git add a.txt && git commit -qm base && git tag base
        printf "world\n" >> a.txt
        git commit -qam clean
        run 0 ${scan} diff base
        grep -q "terms=3 matches=0 secrets=0" ../out

        # Mixed case and padded term
        printf "x\nzzz-FAKE-term-ONE here\n" >> a.txt
        git commit -qam dirty
        run 1 ${scan} diff base
        grep -qx "a.txt:4" ../out
        nofake

        # CRLF term still matches; regex characters match as fixed text only
        printf "yyy-fake-TERM-two\n" > b.txt
        printf '%s\n' 'xQ.W\E*[R' > c.txt
        printf "qXwe\n" > d.txt
        git add . && git commit -qm more
        run 1 ${scan} diff base
        grep -qx "b.txt:1" ../out
        grep -qx "c.txt:1" ../out
        if grep -q "^d.txt" ../out; then echo "FAIL: regex decoy matched"; exit 1; fi
        nofake

        # History mode prints COMMIT:FILE
        run 1 ${scan} history
        grep -qE '^[0-9a-f]{7}:b.txt$' ../out
        nofake

        # A binary file, with diff disabled by attribute, is still scanned
        git checkout -q -b bin base
        printf '*.bin -diff\n' > .gitattributes
        printf 'ab\0zzz-fake-term-one\0cd\n' > x.bin
        git add . && git commit -qm bin
        run 1 ${scan} diff base
        grep -q "x.bin" ../out
        nofake
        git checkout -q master 2>/dev/null || git checkout -q main

        # A deleted line holding a term is not a match
        git init -q ../repo2 && cd ../repo2
        printf "ok\nZZZ-fake-term-one\n" > a.txt
        git add a.txt && git commit -qm base && git tag base
        printf "ok\n" > a.txt
        git commit -qam del
        run 0 ${scan} diff base

        # A card must not be able to hide a secret from gitleaks. Fake AWS-style pair.
        mkleak() {
          git init -q "$1" && cd "$1"
          printf "base\n" > a.txt
          git add a.txt && git commit -qm base && git tag base
          printf 'aws_access_key_id = AKIAIOSFODNN7EXAMPLQ%s\naws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEYQ\n' "$2" > cfg.ini
          git add cfg.ini && git commit -qm secret
          leak=$(git rev-parse HEAD)
        }
        mkleak ../repo3 ""
        run 1 ${scan} diff base
        grep -q "secrets=1" ../out
        printf '%s:cfg.ini:aws-access-token:1\n' "$leak" > .gitleaksignore
        git add .gitleaksignore && git commit -qm ignore
        run 1 ${scan} diff base
        grep -q "secrets=1" ../out
        git reset -q --hard HEAD~1
        printf '%s:cfg.ini:aws-access-token:1\n' "$leak" > .gitleaksignore
        run 1 ${scan} diff base
        grep -q "secrets=1" ../out
        mkleak ../repo4 " # gitleaks:allow"
        run 1 ${scan} diff base
        grep -q "secrets=1" ../out
        mkleak ../repo5 ""
        printf '[extend]\nuseDefault = true\n[allowlist]\npaths = ["cfg.ini"]\n' > .gitleaks.toml
        git add .gitleaks.toml && git commit -qm allow
        run 1 ${scan} diff base
        grep -q "secrets=1" ../out

        # The real base is a remote-tracking ref, which a plain bare clone drops
        mkleak ../repo6 ""
        git update-ref refs/remotes/origin/main base
        run 1 ${scan} diff origin/main
        grep -q "secrets=1" ../out
        # A base that is not an ancestor of HEAD scans nothing in gitleaks: fail closed
        git tag side
        git checkout -q -b other base
        printf "y\n" > y.txt && git add y.txt && git commit -qm other
        run 3 ${scan} diff side
        # An empty range is clean
        run 0 ${scan} diff HEAD
        grep -q "matches=0 secrets=0" ../out

        # A secret that exists only in a merge commit's conflict resolution
        git init -q ../repo7 && cd ../repo7
        printf "0\n" > f.txt
        git add f.txt && git commit -qm base && git tag base
        git checkout -q -b left && printf "L\n" > f.txt && git commit -qam left
        git checkout -q -b right base && printf "R\n" > f.txt && git commit -qam right
        git merge -q left >/dev/null 2>&1 || true
        printf 'aws_access_key_id = AKIAIOSFODNN7EXAMPLQ\naws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEYQ\n' > f.txt
        git add f.txt && git commit -qm evil-merge
        run 1 ${scan} diff base
        grep -q "secrets=1" ../out || { cat ../out; exit 1; }
        run 1 ${scan} history
        grep -q "secrets=1" ../out || { cat ../out; exit 1; }
        cd ../repo2

        # Term text in a path or in commit metadata must be caught and named by identifier only.
        mkmeta() {
          git init -q "../$1" && cd "../$1"
          printf "base\n" > a.txt
          git add a.txt && git commit -qm base && git tag base
        }
        mkmeta m1
        printf "x\n" > zzz-fake-term-one.txt
        git add . && git commit -qm "add file"
        run 1 ${scan} diff base
        grep -qE '^COMMIT:[0-9a-f]{7}:path$' ../out
        grep -q "matches=1" ../out
        nofake
        mkmeta m2
        printf "x\n" > b.txt
        git add . && git commit -qm "note about ZZZ-fake-term-one"
        run 1 ${scan} diff base
        grep -qE '^COMMIT:[0-9a-f]{7}:message$' ../out
        nofake
        mkmeta m3
        printf "x\n" > b.txt
        git add . && git commit -q --author="YYY-fake-term-two <a@b.c>" -m "add b"
        run 1 ${scan} diff base
        grep -qE '^COMMIT:[0-9a-f]{7}:author$' ../out
        nofake
        run 1 ${scan} history
        grep -qE '^COMMIT:[0-9a-f]{7}:author$' ../out
        nofake
        mkmeta m4
        printf "x\n" > b.txt
        git add . && GIT_COMMITTER_EMAIL=dev@zzz-fake-term-one.test git commit -qm "add b"
        run 1 ${scan} diff base
        grep -qE '^COMMIT:[0-9a-f]{7}:committer$' ../out
        nofake
        # A path that holds a term is term text: the content match must not print it either.
        mkmeta m6
        printf "ZZZ-fake-term-one\n" > zzz-fake-term-one.txt
        printf "plain\nYYY-fake-term-two\n" > ok.txt
        git add . && git commit -qm "add both"
        run 1 ${scan} diff base
        nofake
        grep -qx "ok.txt:2" ../out
        grep -qE '^COMMIT:[0-9a-f]{7}:path$' ../out
        run 1 ${scan} history
        nofake
        grep -qE '^[0-9a-f]{7}:ok.txt$' ../out

        mkmeta m5
        printf "x\n" > b.txt
        git add . && git commit -qm "add b"
        run 0 ${scan} diff base
        grep -q "matches=0 secrets=0" ../out
        run 0 ${scan} history
        nofake

        # Fail closed
        run 3 ${scan} diff no-such-ref
        run 3 ${scanMissing} diff base
        run 3 ${scanBlank} diff base
        run 3 ${scanBadLeaks} diff base
        run 3 ${scan}
        touch $out
      '';

  # Only the integrator (and Hermes chat, which leaves HERMES_PROFILE unset) may
  # get a git credential. Tests the real script built from the real option value.
  flake.checks.x86_64-linux.hermes-push-guard =
    let
      guard = import ../pkgs/hermes-push-guard.nix {
        inherit pkgs;
        profiles = hermes.pushProfiles;
        # A fake token in the store, so the credential path runs without secrets.
        table = "github.com fakeowner x-access-token ${pkgs.writeText "fake-token" "ghp_fake\n"}";
      };
    in
    pkgs.runCommand "hermes-push-guard" { } ''
      # want EXIT CMD...: HERMES_PROFILE is set by the caller via env
      ok() { env "$@" ${guard.allowed} || { echo "FAIL: $* denied, wanted allowed"; exit 1; }; }
      no() { if env "$@" ${guard.allowed}; then echo "FAIL: $* allowed, wanted denied"; exit 1; fi; }
      env -u HERMES_PROFILE ${guard.allowed}
      ok HERMES_PROFILE=
      for p in integrator default coder; do ok HERMES_PROFILE=$p; done
      for p in coder-light coder-heavy reviewer tester planner security unknown; do no HERMES_PROFILE=$p; done
      # Exact match only: case, suffix, space, glob and newline variants of an allowed name are denied.
      for p in INTEGRATOR integrator-evil 'integrator evil' '*' $'integrator\n' $'integrator\nx'; do no "HERMES_PROFILE=$p"; done

      # The credential helper path: token for an allowed profile, nothing for a denied one.
      got=$(env HERMES_PROFILE=integrator ${guard.token} github.com FakeOwner)
      [ "$got" = "x-access-token ghp_fake" ] || { echo "FAIL: got '$got'"; exit 1; }
      if got=$(env HERMES_PROFILE=coder-light ${guard.token} github.com fakeowner); then
        echo "FAIL: denied profile got a credential"; exit 1
      fi
      [ -z "$got" ] || { echo "FAIL: denied profile printed '$got'"; exit 1; }
      touch "$out"
    '';

  # AI credit is stripped, Azogue is added once for agent commits only, and
  # human trailers and human commits stay as written.
  flake.checks.x86_64-linux.ai-attribution-hook =
    let
      hook = import ../pkgs/ai-attribution-hook.nix { inherit pkgs; };
    in
    pkgs.runCommand "ai-attribution-hook" { nativeBuildInputs = [ pkgs.git ]; } ''
      export HOME=$TMPDIR GIT_AUTHOR_NAME=Diego GIT_AUTHOR_EMAIL=d@example.com
      git init -q repo && cd repo
      run() { printf '%b' "$2" > m; env $1 ${hook.script}/bin/ai-attribution-commit-msg m; }
      azogues() { grep -c 'Azogue bot' m || true; }
      fail() { echo "FAIL: $1"; cat m; exit 1; }

      run X=1 'fix: a\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/x\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n'
      grep -qiE 'claude|generated' m && fail "AI credit kept"
      [ "$(azogues)" = 1 ] || fail "stripped commit lacks Azogue"

      run CLAUDECODE=1 'fix: b\n\n${hook.trailer}\n'
      [ "$(azogues)" = 1 ] || fail "Azogue duplicated"

      run PI_CODING_AGENT=true 'fix: c\n\nCo-authored-by: Ana <ana@example.com>\nSigned-off-by: Diego <d@example.com>\n'
      grep -q 'Ana' m && grep -q 'Signed-off-by: Diego' m || fail "human trailer removed"
      [ "$(azogues)" = 1 ] || fail "agent shell commit lacks Azogue"

      run X=1 'fix: d\n\nSigned-off-by: Diego <d@example.com>\n'
      [ "$(azogues)" = 0 ] || fail "human commit got Azogue"

      GIT_AUTHOR_EMAIL=azogue@minerales.network run CLAUDECODE=1 'fix: e\n'
      [ "$(azogues)" = 0 ] || fail "Azogue as author got itself as co-author"
      touch "$out"
    '';

  # The hook and Hermes's Azogue identity apply in personal repos only, through
  # cobalto's real /etc/gitconfig. Work repos keep tool defaults.
  flake.checks.x86_64-linux.ai-attribution-scope =
    pkgs.runCommand "ai-attribution-scope"
      { nativeBuildInputs = [ pkgs.git ]; }
      ''
        export HOME=$TMPDIR CLAUDECODE=1
        export GIT_CONFIG_SYSTEM=${pkgs.writeText "cobalto-gitconfig" config.flake.nixosConfigurations.cobalto.config.environment.etc.gitconfig.text}
        printf '[user]\n\tname = Diego\n\temail = d@example.com\n' > $HOME/diego.gitconfig
        # commit DIR REMOTE GLOBAL: a commit carrying Claude's default trailer.
        commit() {
          git init -q "$1" && cd "$1"
          [ -z "$2" ] || git remote add origin "$2"
          GIT_CONFIG_GLOBAL=$3 git -c commit.gpgsign=false commit -q --allow-empty -m t \
            -m 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
          git log -1 --format='%an%n%B' > $TMPDIR/out; cd $TMPDIR
        }
        want() { grep -q "$1" out || { echo "FAIL $2: no '$1'"; cat out; exit 1; }; }
        not() { if grep -q "$1" out; then echo "FAIL $2: has '$1'"; cat out; exit 1; fi; }

        commit a https://github.com/diegobarrosaraya/x $HOME/diego.gitconfig
        want 'Azogue bot <azogue' personal; not Claude personal; want '^Diego$' personal
        commit b git@github.com:DiegoBarrosA/x.git $HOME/diego.gitconfig
        want 'Azogue bot <azogue' ssh-remote
        commit "$HOME/Projects/Personal/c" "" $HOME/diego.gitconfig
        want 'Azogue bot <azogue' personal-dir
        commit d https://github.com/acme/x $HOME/diego.gitconfig
        want Claude work; not Azogue work
        commit e https://github.com/diegobarrosaraya/x /dev/null
        want '^Azogue bot$' hermes-personal; not 'Co-Authored-By: Azogue' hermes-personal
        commit f https://github.com/acme/x /dev/null
        want '^Hermes$' hermes-work
        touch "$out"
      '';
}
