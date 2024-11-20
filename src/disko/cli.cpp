#include <any>
#include <cstdlib>
#include <cstring>
#include <getopt.h>
#include <iostream>
#include <ostream>
#include <string>

/*help message*/
void showUsage() {
  std::cerr
      << "Disko - tool for declarative disk partitioning.\n"
      << "Usage: " << "disko2 " << "[mode] " << "<args> disko-config.nix \n\n"
      << "Modes:\n"
      << "    wipe       ->   wipe disk\n"
      << "    format     ->   create partition table and filesystems\n"
      << "    mount      ->   mount disks\n"
      << "    init       ->   initiate disks, run wipe,format,mount in "
         "sequence\n"
      << "    generate   ->   generate configuration from current disks "
         "configuration\n\n"
      << "Args:\n"
      << "    -f/--flake <path/url>    ->   define config location (default: "
         "./disko.nix)\n"
      << "    -m/--mount <path>        ->   sets path where disks should be "
         "mounted (default: /mnt)\n"
      << "--arg 'name value'           ->   arguments for nix-build\n"
      << "    -d/--dry-run             ->   show what script WOULD do\n"
      << "    --yes-wipe-everything    ->   skip safety check\n"
      << "    -v/--verbose             ->   increase verbosity of output\n"
      << "    -h/--help                ->   show this message" << std::endl;

  /* --arg name value
     pass value to nix-build. can be used to set disk-names for example
     --argstr name value
     pass value to nix-build as string
     --no-deps
     avoid adding another dependency closure to an in-memory installer
     requires all necessary dependencies to be available in the environment
   */
}

/* command-line arguments parser */
std::string disko_Mode;
std::string disko_Config;
std::string flake_Path;
std::string mount_Path = "/mnt";
std::string nix_Args;
bool dry_Run = false;
bool omit_Check = false;
bool verbose = false;

std::any parseArgs(int argc, char **argv) {

  const char *const short_opts = "f:m:dhv";
  const option long_opts[] = {
      {"flake", required_argument, nullptr, 'f'},
      {"mount", required_argument, nullptr, 'm'},
      {"dry-run", no_argument, nullptr, 'd'},
      {"yes-wipe-everything", no_argument, nullptr, 'y'},
      {"help", no_argument, nullptr, 'h'},
      {"verbose", no_argument, nullptr, 'v'},
      {"arg", required_argument, nullptr, 'a'}};

  // break program and show help message if no arguments passed:
  if (argc == 1) {
    std::cout << "No mode set!\n" << std::endl;
    showUsage();
    exit(1);
  }

  for (int ix = 1; ix < argc; ++ix) {
    // parse modes:
    if (strcmp(argv[ix], "wipe") == 0 || strcmp(argv[ix], "format") == 0 ||
        strcmp(argv[ix], "mount") == 0 || strcmp(argv[ix], "init") == 0 ||
        strcmp(argv[ix], "generate") == 0) {
      disko_Mode = argv[ix];
      break;
    }
    if (strcmp(argv[ix], "-h") == 0 || strcmp(argv[ix], "--help") == 0) {
      showUsage();
      exit(0);
    } else {
      std::cout << "No mode set!\n" << std::endl;
      showUsage();
      exit(1);
    }

    // find configuration file:
  }
  // parse additional flags
  while (true) {
    const auto arg = getopt_long(argc, argv, short_opts, long_opts, nullptr);

    if (-1 == arg)
      break;

    switch (arg) {
    case 'f':
      flake_Path = std::string(optarg);
      break;
    case 'm':
      mount_Path = std::string(optarg);
      break;
    case 'd':
      dry_Run = true;
      break;
    case 'y':
      omit_Check = true;
      break;
    case 'v':
      verbose = true;
      break;
    case 'a':
      nix_Args = std::string(optarg);
      std::cout << nix_Args << std::endl;
      break;
    case 'h':
      showUsage();
      exit(0);

    default:
      std::cerr << "An error occurred! Check --help or, if a bug, report it."
                << std::endl;
      exit(1);
    }
  }
  return disko_Mode;
  return flake_Path;
  return mount_Path;
  return nix_Args;
  return dry_Run;
  return omit_Check;
  return verbose;
}

/* main part - pass arguments to nix */
void disko_Run() {
  std::string base_Command = "nix"
                             " --extra-experimental-features"
                             "nix-command"
                             "--extra-experimental-features"
                             "flakes";

  std::cout << base_Command << std::endl;
};

int main(int argc, char *argv[]) {
  parseArgs(argc, argv);
  disko_Run();
  return 0;
}
