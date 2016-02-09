let
  hydraURL = "https://headcounter.org/hydra";
  project = "openlab";
  jobset = "vuizvui";
  channel = "channels.generic";
  path = "channel/custom/${project}/${jobset}/${channel}/nixexprs.tar.xz";
in import "${fetchTarball "${hydraURL}/${path}"}/pkgs/games"
