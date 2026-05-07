# Centralized Syncthing device registry.
#
# To get a device ID:
#   ssh <host> syncthing cli --home=/var/lib/syncthing show system | grep myID
#   or: Actions → Show ID in the web UI at localhost:8384
{
  devices = {
    main = {
      id = "GWVJIWP-VPVMQLF-JWYUCEQ-DSO67XH-E6U5FYT-I5VQ43L-2HH5NDL-IH5PNQN";
    };
  };

  folders = {
    documents = {
      path = "/persist/sync/documents";
      devices = [
        "main"
      ];
    };
    photos = {
      path = "/persist/sync/photos";
      devices = [
        "main"
      ];
    };
  };
}
