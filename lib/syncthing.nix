# Centralized Syncthing device registry.
# Shared between homeserver-vm and homeserver so both stay in sync.
#
# To get a device ID:
#   ssh <host> syncthing cli --home=/var/lib/syncthing show system | grep myID
#   or: Actions → Show ID in the web UI at localhost:8384
{
  devices = {
    homeserver = {
      id = "QVJAXRA-D3RSA5P-H4KBGHB-7RPN55M-BRTQ3CU-XT45VLH-PJEYJU6-Q4FXGQA";
    };
    main = {
      id = "GWVJIWP-VPVMQLF-JWYUCEQ-DSO67XH-E6U5FYT-I5VQ43L-2HH5NDL-IH5PNQN";
    };
  };

  folders = {
    documents = {
      path = "/persist/sync/documents";
      devices = [ "homeserver" ];
      # devices = [ "homeserver" "main" ];
    };
    photos = {
      path = "/persist/sync/photos";
      devices = [ "homeserver" ];
      # devices = [ "homeserver" "main" ];
    };
  };
}
