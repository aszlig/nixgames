{ stdenv, curl, cacert, writeText, fetchFromGitHub, fetchpatch
, python, buildPythonPackage, pythonPackages

, email, password
}:

{ machineName, downloadName ? "Download", suffix ? "humblebundle", md5 }: let
  cafile = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  humbleAPI = buildPythonPackage rec {
    name = "humblebundle-${version}";
    version = "0.1.1";

    src = fetchFromGitHub {
      owner = "saik0";
      repo = "humblebundle-python";
      rev = version;
      sha256 = "1kcg42nh7sbjabim1pbqx14468pypznjy7fx2bv7dicy0sqd9b8j";
    };

    propagatedBuildInputs = with pythonPackages; [ requests2 ];
  };

  getDownloadURL = writeText "gethburl.py" ''
    import sys, humblebundle

    def get_products(client):
      gamekeys = client.get_gamekeys()
      for gamekey in gamekeys:
        order = hb.get_order(gamekey)
        if order.subproducts is None:
          continue
        for subproduct in order.subproducts:
          prodname = subproduct.human_name.encode('ascii', 'replace')
          downloads = [(download.machine_name, download.download_struct)
                       for download in subproduct.downloads]
          yield (prodname, downloads)

    def find_download(downloads):
      for machine_name, dstruct in sum(downloads.values(), []):
        if machine_name == """${machineName}""":
          for ds in dstruct:
            if ds.name == """${downloadName}""":
              return ds
          print >>sys.stderr, \
            """Unable to find ${downloadName} for ${machineName}!"""
          print >>sys.stderr, 'Available download types:'
          for ds in dstruct:
            print >>sys.stderr, "  " + ds.name
          raise SystemExit(1)

    hb = humblebundle.HumbleApi()
    hb.login("""${email}""", """${password}""")
    products = dict(get_products(hb))
    dstruct = find_download(products)

    if dstruct is None:
      print >>sys.stderr, """Cannot find download for ${machineName}!"""
      print >>sys.stderr, 'Available machine names:'
      for name, dstructs in sorted(products.items(), key=lambda x: x[0]):
        print >>sys.stderr, "  * " + name
        print >>sys.stderr, "    " + ', '.join(map(lambda x: x[0], dstructs))
      raise SystemExit(1)
    elif dstruct.md5 != '${md5}':
      print >>sys.stderr, \
        """MD5 for ${machineName} is not ${md5} but """ + dstruct.md5 + '.'
      raise SystemExit(1)
    else:
      print dstruct.url.web
  '';
in stdenv.mkDerivation {
  name = "${machineName}.${suffix}";
  outputHashAlgo = "md5";
  outputHash = md5;

  buildInputs = [ python humbleAPI ];

  buildCommand = ''
    url="$(python "${getDownloadURL}")"
    header "downloading $name from $url"
    ${curl}/bin/curl --cacert "${cafile}" --fail --output "$out" "$url"
    stopNest
  '';
}
