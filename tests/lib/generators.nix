{
  nixpkgs,
  system,
  ...
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  gen = import ../../lib/generators.nix { inherit lib; };

  failures = lib.runTests {
    testStringAttribute = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.write";
          label = "target";
          body = {
            url = "http://loki:3100";
          };
        }
      ];
      expected = "loki.write \"target\" {\n  url = \"http://loki:3100\"\n}";
    };

    testBoolAttribute = {
      expr = gen.toAlloyHCL [
        {
          type = "x";
          label = "y";
          body = {
            debug = false;
            enabled = true;
          };
        }
      ];
      expected = "x \"y\" {\n  debug = false\n  enabled = true\n}";
    };

    testNestedBlock = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.write";
          label = "target";
          body = {
            endpoint = gen.nestedBlock {
              url = "http://loki:3100";
            };
          };
        }
      ];
      expected = "loki.write \"target\" {\n  endpoint {\n    url = \"http://loki:3100\"\n  }\n}";
    };

    testRefInList = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.source.journal";
          label = "systemd";
          body = {
            forward_to = [ (gen.ref "loki.write.target.receiver") ];
          };
        }
      ];
      expected = "loki.source.journal \"systemd\" {\n  forward_to = [loki.write.target.receiver]\n}";
    };

    testInlineObject = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.source.journal";
          label = "systemd";
          body = {
            labels = {
              job = "systemd-journal";
            };
          };
        }
      ];
      expected = "loki.source.journal \"systemd\" {\n  labels = {\n    job = \"systemd-journal\",\n  }\n}";
    };

    testMultipleComponents = {
      expr = gen.toAlloyHCL [
        {
          type = "a";
          label = "1";
          body = {
            x = "1";
          };
        }
        {
          type = "b";
          label = "2";
          body = {
            y = "2";
          };
        }
      ];
      expected = "a \"1\" {\n  x = \"1\"\n}\n\nb \"2\" {\n  y = \"2\"\n}";
    };

    testDeepNestedBlock = {
      expr = gen.toAlloyHCL [
        {
          type = "loki.write";
          label = "target";
          body = {
            endpoint = gen.nestedBlock {
              basic_auth = gen.nestedBlock {
                password_file = "/run/secrets/pw";
                username = "user";
              };
              url = "http://loki";
            };
          };
        }
      ];
      expected = "loki.write \"target\" {\n  endpoint {\n    basic_auth {\n      password_file = \"/run/secrets/pw\"\n      username = \"user\"\n    }\n    url = \"http://loki\"\n  }\n}";
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "lib-generators-tests" { } "touch $out"
else
  throw "lib/generators.nix tests failed:\n${lib.generators.toPretty { } failures}"
