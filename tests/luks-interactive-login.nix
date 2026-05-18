{
  imports = [ ../example/luks-interactive-login.nix ];
  disko.test = {
    name = "luks-interactive-login";
    enableOCR = true;
    bootCommands = ''
      machine.wait_for_text("[Pp]assphrase for")
      machine.send_chars("secretsecret\n")
    '';
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
    '';
  };
}
