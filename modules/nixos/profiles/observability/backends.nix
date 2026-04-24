{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.observability;
in
{
  options.profiles.observability = {
    loki.enable = lib.mkEnableOption "Loki";
    tempo.enable = lib.mkEnableOption "Tempo";
    mimir.enable = lib.mkEnableOption "Mimir";
  };

  config = lib.mkIf cfg.enable {
    services = {
      loki = lib.mkIf cfg.loki.enable {
        enable = true;
        configuration = {
          auth_enabled = false;
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 3100;
            grpc_listen_port = 9096;
          };
          common = {
            path_prefix = "/var/lib/loki";
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };
          schema_config.configs = [
            {
              from = "2024-01-01";
              index = {
                prefix = "index_";
                period = "24h";
              };
              object_store = "filesystem";
              schema = "v13";
              store = "tsdb";
            }
          ];
          storage_config.filesystem.directory = "/var/lib/loki/chunks";
        };
      };

      tempo = lib.mkIf cfg.tempo.enable {
        enable = true;
        settings = {
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 3200;
            grpc_listen_port = 3201;
          };
          distributor.receivers.otlp.protocols = {
            grpc.endpoint = "127.0.0.1:4317";
            http.endpoint = "127.0.0.1:4318";
          };
          storage = {
            trace = {
              backend = "local";
              local.path = "/var/lib/tempo/blocks";
              wal.path = "/var/lib/tempo/wal";
            };
          };
        };
      };

      mimir = lib.mkIf cfg.mimir.enable {
        enable = true;
        configuration = {
          multitenancy_enabled = false;
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 9009;
          };
          blocks_storage = {
            backend = "filesystem";
            filesystem.dir = "/var/lib/mimir/blocks";
          };
          compactor.data_dir = "/var/lib/mimir/compactor";
          distributor.ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
          ingester.ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
          ruler_storage = {
            backend = "filesystem";
            filesystem.dir = "/var/lib/mimir/rules";
          };
          store_gateway.sharding_ring.replication_factor = 1;
          alertmanager_storage = {
            backend = "filesystem";
            filesystem.dir = "/var/lib/mimir/alertmanager";
          };
        };
      };
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.loki.enable [
      "d /var/lib/loki 0750 loki loki -"
      "d /var/lib/loki/chunks 0750 loki loki -"
    ];
  };
}
