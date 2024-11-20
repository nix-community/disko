#include <any>
#include <cstring>
#include <filesystem>
#include <getopt.h>
#include <iostream>

// define colors for beautiful (xd) output
#define RESET "\033[0m"
#define BLACK "\033[30m"              /* Black */
#define RED "\033[31m"                /* Red */
#define GREEN "\033[32m"              /* Green */
#define YELLOW "\033[33m"             /* Yellow */
#define BLUE "\033[34m"               /* Blue */
#define MAGENTA "\033[35m"            /* Magenta */
#define CYAN "\033[36m"               /* Cyan */
#define WHITE "\033[37m"              /* White */
#define BOLDBLACK "\033[1m\033[30m"   /* Bold Black */
#define BOLDRED "\033[1m\033[31m"     /* Bold Red */
#define BOLDGREEN "\033[1m\033[32m"   /* Bold Green */
#define BOLDYELLOW "\033[1m\033[33m"  /* Bold Yellow */
#define BOLDBLUE "\033[1m\033[34m"    /* Bold Blue */
#define BOLDMAGENTA "\033[1m\033[35m" /* Bold Magenta */
#define BOLDCYAN "\033[1m\033[36m"    /* Bold Cyan */
#define BOLDWHITE "\033[1m\033[37m"   /* Bold White */

/*help message*/
void showUsage() {
  std::cerr << BOLDMAGENTA "Disko" RESET " - tool for" BOLDBLUE
                           " declarative " RESET "disk partitioning.\n"
            << BOLDYELLOW "Usage: " RESET "disko2 " RED "[mode] " CYAN "<args> "
            << BLUE "-c disko-config.nix" RESET ", or\n"
            << "       disko2 " RED "[mode] " CYAN "<args> " BLUE
               "--flake github:foo/bar#disk-config\n\n"
            << BOLDRED "Modes:\n"
            << BLUE "    wipe  " RESET "     ->   " CYAN "wipe disk\n"
            << BLUE "    format  " RESET "   ->   " CYAN
                    "create partition table and filesystems\n"
            << BLUE "    mount      " RESET "->  " CYAN " mount disks\n"
            << BLUE "    init      " RESET " ->  " CYAN
                    " initiate disks, run " RESET "wipe,format,mount " CYAN
                    "in sequence\n"
            << BLUE "    generate   " RESET "-> " CYAN
                    "  generate config file from current disks "
                    "state\n\n"
            << BOLDCYAN "Args:\n"
            << YELLOW "    -f/--flake <path/url> " RESET "   ->  " GREEN
                      " define flake location\n"
            << YELLOW "    -c/--config <file.nix> " RESET "  -> " GREEN
                      "  define config file\n"
            << YELLOW "    -m/--mount <path>   " RESET "     ->  " GREEN
                      " sets path where disks should be "
                      "mounted (default: /mnt)\n"
            << YELLOW "    --arg 'name value'   " RESET "    ->  " GREEN
                      " arguments for nix-build\n"
            << YELLOW "    -d/--dry-run            " RESET " ->  " GREEN
                      " show what script WOULD do\n"
            << YELLOW "    --yes-wipe-everything   " RESET " ->  " GREEN
                      " skip safety check\n"
            << YELLOW "    -v/--verbose           " RESET "  ->  " GREEN
                      " increase verbosity of output\n"
            << YELLOW "    -h/--help          " RESET "      -> " GREEN
                      "  show this message"
            << std::endl;

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

  const char *const short_opts = "f:m:dhvc:";
  const option long_opts[] = {
      {"flake", required_argument, nullptr, 'f'},
      {"mount", required_argument, nullptr, 'm'},
      {"dry-run", no_argument, nullptr, 'd'},
      {"yes-wipe-everything", no_argument, nullptr, 'y'},
      {"help", no_argument, nullptr, 'h'},
      {"verbose", no_argument, nullptr, 'v'},
      {"arg", required_argument, nullptr, 'a'},
      {"config", required_argument, nullptr, 'c'}};

  // break program if no args set:
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
    case 'n':
      disko_Config = std::string(optarg);
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
    case '?':
      std::cerr << "Unknown option: " << char(optopt) << std::endl;
      exit(1);
    }
  }

  // check if disko_Mode and disko_Config is set and exit if variable is empty
  // or both are used:
  if ((disko_Config.empty() || !std::filesystem::exists(disko_Config)) and
      (flake_Path.empty() || !std::filesystem::exists(flake_Path))) {
    std::cerr << "Configuration file or flake is not set or does not exist."
              << std::endl;
    exit(1);
  }
  if (!disko_Config.empty() and !flake_Path.empty()) {
    std::cerr << "You cannot define both flake and config.nix file. Please "
                 "choose only one option and try again";
    exit(1);
  }

  // return values
  return disko_Config;
  return disko_Mode;
  return flake_Path;
  return mount_Path;
  return nix_Args;
  return dry_Run;
  return omit_Check;
  return verbose;
}

/* main part - pass arguments to nix */

int main(int argc, char *argv[]) {
  // get args
  parseArgs(argc, argv);

  // make a command to eval config:
  std::string nix_CMD = "nix"
                        " --extra-experimental-features"
                        " nix-command"
                        " --extra-experimental-features"
                        " flakes";
  if (!flake_Path.empty()) {
    nix_CMD += " --arg"
               " diskoFile ";
    nix_CMD += flake_Path;
  }
  std::cout << nix_CMD;
  return 0;
}
