#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

static std::string default_socket_path() {
  const char* env = std::getenv("USBCAMV4L_CONTROL_SOCKET");
  if (env && *env) return std::string(env);
  return "/tmp/usbcamv4l-control.sock";
}

static std::string to_lower_copy(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return s;
}

static bool is_on_off_toggle(const std::string& s) {
  return s == "on" || s == "off" || s == "toggle";
}

static bool is_sync_mode(const std::string& s) {
  return s == "strict" || s == "low" || s == "auto";
}

static bool is_queue_depth(const std::string& s) {
  return s == "2" || s == "3" || s == "4";
}

static bool parse_non_negative_int(const std::string& s, int* out) {
  if (!out || s.empty()) return false;
  for (char c : s) {
    if (c < '0' || c > '9') return false;
  }
  try {
    const int v = std::stoi(s);
    if (v < 0) return false;
    *out = v;
    return true;
  } catch (...) {
    return false;
  }
}

static std::string normalize_command_token(std::string token) {
  const std::string lower = to_lower_copy(token);
  if (lower == "status" || lower == "stauts" || lower == "stats" || lower == "stat") return "status";
  if (lower == "fps" || lower == "fpps" || lower == "fpss") return "fps";
  if (lower == "rec" || lower == "record" || lower == "recc" || lower == "recrod") return "rec";
  if (lower == "sync" || lower == "sycn" || lower == "synch") return "sync";
  if (lower == "queue" || lower == "queu" || lower == "qeue") return "queue";
  if (lower == "cam" || lower == "camera" || lower == "camrea" || lower == "cemera") return "cam";
  if (lower == "reconnect" || lower == "reconect" || lower == "re-connect") return "reconnect";
  if (lower == "on" || lower == "onn") return "on";
  if (lower == "off" || lower == "of") return "off";
  if (lower == "toggle" || lower == "toggel" || lower == "toogle") return "toggle";
  if (lower == "strict" || lower == "strcit") return "strict";
  if (lower == "low" || lower == "lo") return "low";
  if (lower == "auto" || lower == "atuo") return "auto";
  return token;
}

static bool parse_camera_spec(const std::string& spec, std::string* outCmd, std::string* outErr) {
  if (!outCmd || !outErr) return false;
  const size_t c1 = spec.find(':');
  if (c1 == std::string::npos) {
    *outErr = "Invalid -c/--camera spec '" + spec +
              "'. Expected <index>:reconnect or <index>:rec:on|off|toggle.";
    return false;
  }
  const size_t c2 = spec.find(':', c1 + 1);
  const std::string idxStr = spec.substr(0, c1);
  int idx = -1;
  if (!parse_non_negative_int(idxStr, &idx)) {
    *outErr = "Invalid camera index in -c/--camera spec: '" + idxStr + "'";
    return false;
  }

  const std::string action = normalize_command_token(
      c2 == std::string::npos ? spec.substr(c1 + 1) : spec.substr(c1 + 1, c2 - (c1 + 1)));
  if (c2 == std::string::npos) {
    if (action != "reconnect") {
      *outErr = "Invalid camera action in -c/--camera spec: '" + action + "'";
      return false;
    }
    *outCmd = "cam " + std::to_string(idx) + " reconnect";
    return true;
  }

  const std::string mode = normalize_command_token(spec.substr(c2 + 1));
  if (action != "rec") {
    *outErr = "Invalid camera action in -c/--camera spec: '" + action + "'";
    return false;
  }
  if (!is_on_off_toggle(mode)) {
    *outErr = "Invalid camera rec mode in -c/--camera spec: '" + mode + "'";
    return false;
  }
  *outCmd = "cam " + std::to_string(idx) + " rec " + mode;
  return true;
}

static std::string normalize_option_alias(const std::string& arg) {
  const std::string lower = to_lower_copy(arg);
  if (lower == "--help" || lower == "-help" || lower == "--hlep" || lower == "--halp") return "-h";
  if (lower == "--camera" || lower == "-camera" || lower == "--cam" || lower == "-cam" ||
      lower == "--camrea" || lower == "-camrea" || lower == "--cemera" || lower == "-cemera")
    return "-c";
  if (lower == "--fps" || lower == "-fps" || lower == "--fpps" || lower == "-fpps" ||
      lower == "--fpss" || lower == "-fpss")
    return "-f";
  if (lower == "--queue" || lower == "-queue" || lower == "--queu" || lower == "-queu" ||
      lower == "--qeue" || lower == "-qeue")
    return "-q";
  if (lower == "--raw" || lower == "-raw" || lower == "--send" || lower == "-send") return "-x";
  if (lower == "--rec" || lower == "-rec" || lower == "--record" || lower == "-record" ||
      lower == "--recc" || lower == "-recc" || lower == "--recrod" || lower == "-recrod")
    return "-r";
  if (lower == "--socket" || lower == "-socket" || lower == "--sock" || lower == "-sock" ||
      lower == "--socet" || lower == "-socet")
    return "-p";
  if (lower == "--status" || lower == "-status" || lower == "--stauts" || lower == "-stauts" ||
      lower == "--stats" || lower == "-stats")
    return "-s";
  if (lower == "--sync" || lower == "-sync" || lower == "--sycn" || lower == "-sycn" ||
      lower == "--synch" || lower == "-synch")
    return "-y";
  return arg;
}

static bool parse_positional_command(const std::vector<std::string>& tokens,
                                     std::string* outCmd,
                                     std::string* outErr) {
  if (!outCmd || !outErr) return false;
  if (tokens.empty()) {
    *outErr = "No command provided.";
    return false;
  }

  std::vector<std::string> t = tokens;
  for (std::string& tok : t) tok = normalize_command_token(tok);
  const std::string& cmd = t[0];

  if (cmd == "status") {
    if (t.size() != 1u) {
      *outErr = "status takes no arguments.";
      return false;
    }
    *outCmd = "status";
    return true;
  }
  if (cmd == "fps") {
    if (t.size() != 2u || !is_on_off_toggle(t[1])) {
      *outErr = "fps requires: on|off|toggle";
      return false;
    }
    *outCmd = "fps " + t[1];
    return true;
  }
  if (cmd == "rec") {
    if (t.size() != 2u || !is_on_off_toggle(t[1])) {
      *outErr = "rec requires: on|off|toggle";
      return false;
    }
    *outCmd = "rec " + t[1];
    return true;
  }
  if (cmd == "sync") {
    if (t.size() != 2u || !is_sync_mode(t[1])) {
      *outErr = "sync requires: strict|low|auto";
      return false;
    }
    *outCmd = "sync " + t[1];
    return true;
  }
  if (cmd == "queue") {
    if (t.size() != 2u || !is_queue_depth(t[1])) {
      *outErr = "queue requires: 2|3|4";
      return false;
    }
    *outCmd = "queue " + t[1];
    return true;
  }
  if (cmd == "cam") {
    if (t.size() < 3u) {
      *outErr = "cam requires: <index> reconnect | <index> rec on|off|toggle";
      return false;
    }
    int idx = -1;
    if (!parse_non_negative_int(t[1], &idx)) {
      *outErr = "cam index must be a non-negative integer.";
      return false;
    }
    if (t[2] == "reconnect") {
      if (t.size() != 3u) {
        *outErr = "cam <index> reconnect takes no extra arguments.";
        return false;
      }
      *outCmd = "cam " + std::to_string(idx) + " reconnect";
      return true;
    }
    if (t[2] == "rec") {
      if (t.size() != 4u || !is_on_off_toggle(t[3])) {
        *outErr = "cam <index> rec requires: on|off|toggle";
        return false;
      }
      *outCmd = "cam " + std::to_string(idx) + " rec " + t[3];
      return true;
    }
    *outErr = "cam action must be reconnect or rec.";
    return false;
  }

  *outErr = "Unknown command: " + cmd;
  return false;
}

static void print_help(const char* argv0) {
  const std::string socketPath = default_socket_path();
  std::cout
      << "usbcamctl - runtime control client for usbcamv4l\n\n"
      << "Usage:\n"
      << "  " << argv0 << " [OPTIONS]\n"
      << "  " << argv0 << " <command...>\n\n"
      << "Options (alphabetical):\n"
      << "  -c, --camera SPEC\n"
      << "    One-shot camera control.\n"
      << "    SPEC format: <index>:reconnect or <index>:rec:on|off|toggle.\n"
      << "  -f, --fps MODE\n"
      << "    MODE: on|off|toggle. Controls live FPS+resolution overlay.\n"
      << "  -h, --help\n"
      << "    Show this help and exit.\n"
      << "  -p, --socket PATH\n"
      << "    Control socket path. Overrides default and environment variable.\n"
      << "  -q, --queue DEPTH\n"
      << "    DEPTH: 2|3|4. Updates capture queue depth for all cameras.\n"
      << "  -r, --rec MODE\n"
      << "    MODE: on|off|toggle. Controls recording for all cameras.\n"
      << "  -s, --status\n"
      << "    Print current runtime state for all cameras.\n"
      << "  -x, --raw CMD\n"
      << "    Send raw command text directly to the control socket.\n"
      << "  -y, --sync MODE\n"
      << "    MODE: strict|low|auto.\n"
      << "    strict: force glFinish() each frame.\n"
      << "    low: force glFlush() each frame.\n"
      << "    auto: adaptive mode (switches based on stutter).\n\n"
      << "Positional command mode:\n"
      << "  status\n"
      << "  fps on|off|toggle\n"
      << "  rec on|off|toggle\n"
      << "  sync strict|low|auto\n"
      << "  queue 2|3|4\n"
      << "  cam <index> rec on|off|toggle\n"
      << "  cam <index> reconnect\n\n"
      << "Examples:\n"
      << "  " << argv0 << " status\n"
      << "  " << argv0 << " -s\n"
      << "  " << argv0 << " fps on\n"
      << "  " << argv0 << " -f on\n"
      << "  " << argv0 << " rec toggle\n"
      << "  " << argv0 << " -r toggle\n"
      << "  " << argv0 << " sync auto\n"
      << "  " << argv0 << " -y auto\n"
      << "  " << argv0 << " queue 4\n"
      << "  " << argv0 << " -q 4\n"
      << "  " << argv0 << " cam 0 reconnect\n\n"
      << "Socket:\n"
      << "  Default: " << socketPath << "\n"
      << "  Override: set USBCAMV4L_CONTROL_SOCKET\n\n"
      << "Compatibility aliases:\n"
      << "  Legacy long flags with a single dash are accepted (example: -status).\n"
      << "  Common misspellings are normalized (example: --stauts -> --status).\n\n"
      << "Notes:\n"
      << "  - usbcamv4l must be running with control enabled (default).\n"
      << "  - If usbcamv4l was started with -no-control, commands will fail.\n";
}

int main(int argc, char** argv) {
  std::string socketPath = default_socket_path();
  std::string command;
  auto set_command = [&](const std::string& candidate, const char* source) -> bool {
    if (!command.empty()) {
      std::cerr << "Conflicting command sources: already have '" << command
                << "', cannot also apply " << source << ".\n";
      return false;
    }
    command = candidate;
    return true;
  };

  std::vector<std::string> normalizedArgs;
  normalizedArgs.reserve(static_cast<size_t>(argc) * 2u);
  normalizedArgs.push_back(argv[0]);
  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    const std::string lower = to_lower_copy(arg);
    if (arg == "--") {
      normalizedArgs.push_back(arg);
      for (int j = i + 1; j < argc; ++j) normalizedArgs.push_back(argv[j]);
      break;
    }
    if (lower.rfind("--camera=", 0) == 0 || lower.rfind("-camera=", 0) == 0 ||
        lower.rfind("--cam=", 0) == 0 || lower.rfind("-cam=", 0) == 0 ||
        lower.rfind("--camrea=", 0) == 0 || lower.rfind("-camrea=", 0) == 0) {
      normalizedArgs.push_back("-c");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower.rfind("--fps=", 0) == 0 || lower.rfind("-fps=", 0) == 0 ||
        lower.rfind("--fpps=", 0) == 0 || lower.rfind("-fpps=", 0) == 0) {
      normalizedArgs.push_back("-f");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower.rfind("--queue=", 0) == 0 || lower.rfind("-queue=", 0) == 0 ||
        lower.rfind("--queu=", 0) == 0 || lower.rfind("-queu=", 0) == 0) {
      normalizedArgs.push_back("-q");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower.rfind("--raw=", 0) == 0 || lower.rfind("-raw=", 0) == 0 ||
        lower.rfind("--send=", 0) == 0 || lower.rfind("-send=", 0) == 0) {
      normalizedArgs.push_back("-x");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower.rfind("--rec=", 0) == 0 || lower.rfind("-rec=", 0) == 0 ||
        lower.rfind("--record=", 0) == 0 || lower.rfind("-record=", 0) == 0 ||
        lower.rfind("--recrod=", 0) == 0 || lower.rfind("-recrod=", 0) == 0) {
      normalizedArgs.push_back("-r");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower.rfind("--socket=", 0) == 0 || lower.rfind("-socket=", 0) == 0 ||
        lower.rfind("--sock=", 0) == 0 || lower.rfind("-sock=", 0) == 0 ||
        lower.rfind("--socet=", 0) == 0 || lower.rfind("-socet=", 0) == 0) {
      normalizedArgs.push_back("-p");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower.rfind("--sync=", 0) == 0 || lower.rfind("-sync=", 0) == 0 ||
        lower.rfind("--sycn=", 0) == 0 || lower.rfind("-sycn=", 0) == 0) {
      normalizedArgs.push_back("-y");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    normalizedArgs.push_back(normalize_option_alias(arg));
  }

  std::vector<char*> argvMutable;
  argvMutable.reserve(normalizedArgs.size() + 1u);
  for (std::string& s : normalizedArgs) argvMutable.push_back(s.data());
  argvMutable.push_back(nullptr);

  opterr = 0;
  optind = 1;
  int opt = 0;
  while ((opt = getopt(static_cast<int>(normalizedArgs.size()), argvMutable.data(), "c:f:hp:q:r:sx:y:")) != -1) {
    switch (opt) {
      case 'c': {
        std::string parsed;
        std::string err;
        if (!parse_camera_spec(optarg ? optarg : "", &parsed, &err)) {
          std::cerr << err << "\n";
          return 1;
        }
        if (!set_command(parsed, "-c/--camera")) return 1;
        break;
      }
      case 'f': {
        const std::string mode = normalize_command_token(optarg ? optarg : "");
        if (!is_on_off_toggle(mode)) {
          std::cerr << "Invalid FPS mode for -f/--fps: " << mode << " (expected on|off|toggle)\n";
          return 1;
        }
        if (!set_command("fps " + mode, "-f/--fps")) return 1;
        break;
      }
      case 'h':
        print_help(argv[0]);
        return 0;
      case 'p':
        socketPath = optarg ? optarg : "";
        if (socketPath.empty()) {
          std::cerr << "Missing path for -p/--socket\n";
          return 1;
        }
        break;
      case 'q': {
        const std::string depth = optarg ? optarg : "";
        if (!is_queue_depth(depth)) {
          std::cerr << "Invalid depth for -q/--queue: " << depth << " (expected 2|3|4)\n";
          return 1;
        }
        if (!set_command("queue " + depth, "-q/--queue")) return 1;
        break;
      }
      case 'r': {
        const std::string mode = normalize_command_token(optarg ? optarg : "");
        if (!is_on_off_toggle(mode)) {
          std::cerr << "Invalid recording mode for -r/--rec: " << mode << " (expected on|off|toggle)\n";
          return 1;
        }
        if (!set_command("rec " + mode, "-r/--rec")) return 1;
        break;
      }
      case 's':
        if (!set_command("status", "-s/--status")) return 1;
        break;
      case 'x':
        if (!set_command(optarg ? optarg : "", "-x/--raw")) return 1;
        if (command.empty()) {
          std::cerr << "Missing command text for -x/--raw\n";
          return 1;
        }
        break;
      case 'y': {
        const std::string mode = normalize_command_token(optarg ? optarg : "");
        if (!is_sync_mode(mode)) {
          std::cerr << "Invalid sync mode for -y/--sync: " << mode << " (expected strict|low|auto)\n";
          return 1;
        }
        if (!set_command("sync " + mode, "-y/--sync")) return 1;
        break;
      }
      case '?':
      default:
        std::string badOpt;
        if (optind - 1 >= 0 && optind - 1 < static_cast<int>(normalizedArgs.size())) {
          badOpt = normalizedArgs[static_cast<size_t>(optind - 1)];
        }
        if (badOpt == normalizedArgs.front() &&
            optind >= 0 && optind < static_cast<int>(normalizedArgs.size())) {
          badOpt = normalizedArgs[static_cast<size_t>(optind)];
        }
        if (!badOpt.empty()) {
          std::cerr << "Unknown option: " << badOpt << "\n";
        } else {
          std::cerr << "Unknown option.\n";
        }
        std::cerr << "Use --help for usage.\n";
        return 1;
    }
  }

  if (optind < static_cast<int>(normalizedArgs.size())) {
    std::vector<std::string> positional;
    for (int i = optind; i < static_cast<int>(normalizedArgs.size()); ++i) {
      positional.push_back(normalizedArgs[static_cast<size_t>(i)]);
    }

    std::string parsed;
    std::string err;
    if (!parse_positional_command(positional, &parsed, &err)) {
      std::cerr << err << "\nUse --help for usage.\n";
      return 1;
    }
    if (!set_command(parsed, "positional arguments")) return 1;
  }

  if (command.empty()) {
    std::cerr << "No command provided.\n\n";
    print_help(argv[0]);
    return 1;
  }

  if (socketPath.size() >= sizeof(sockaddr_un{}.sun_path)) {
    std::cerr << "Socket path too long: " << socketPath << "\n";
    return 1;
  }

  const int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  if (fd < 0) {
    std::cerr << "socket() failed: " << strerror(errno) << "\n";
    return 1;
  }

  std::string clientPath = "/tmp/usbcamctl-" + std::to_string(static_cast<long long>(getpid())) + ".sock";
  bool haveBoundClient = false;
  auto try_bind_client = [&](const std::string& path) -> bool {
    if (path.size() >= sizeof(sockaddr_un{}.sun_path)) return false;
    unlink(path.c_str());
    sockaddr_un clientAddr{};
    clientAddr.sun_family = AF_UNIX;
    std::strncpy(clientAddr.sun_path, path.c_str(), sizeof(clientAddr.sun_path) - 1);
    return bind(fd, reinterpret_cast<const sockaddr*>(&clientAddr), sizeof(clientAddr)) == 0;
  };
  if (try_bind_client(clientPath)) {
    haveBoundClient = true;
  } else {
    clientPath = "./.usbcamctl-" + std::to_string(static_cast<long long>(getpid())) + ".sock";
    if (try_bind_client(clientPath)) {
      haveBoundClient = true;
    }
  }

  sockaddr_un serverAddr{};
  serverAddr.sun_family = AF_UNIX;
  std::strncpy(serverAddr.sun_path, socketPath.c_str(), sizeof(serverAddr.sun_path) - 1);

  if (sendto(fd, command.data(), command.size(), 0,
             reinterpret_cast<const sockaddr*>(&serverAddr), sizeof(serverAddr)) < 0) {
    std::cerr << "sendto() failed (" << socketPath << "): " << strerror(errno) << "\n";
    if (haveBoundClient) unlink(clientPath.c_str());
    close(fd);
    return 1;
  }

  if (!haveBoundClient) {
    std::cout << "Command sent (response unavailable: client bind failed).\n";
    close(fd);
    return 0;
  }

  pollfd pfd{};
  pfd.fd = fd;
  pfd.events = POLLIN;
  const int prc = poll(&pfd, 1, 1200);
  if (prc <= 0) {
    std::cerr << "No response from camera control socket at " << socketPath << "\n";
    unlink(clientPath.c_str());
    close(fd);
    return 1;
  }

  char buf[8192];
  const ssize_t n = recvfrom(fd, buf, sizeof(buf) - 1, 0, nullptr, nullptr);
  if (n < 0) {
    std::cerr << "recvfrom() failed: " << strerror(errno) << "\n";
    unlink(clientPath.c_str());
    close(fd);
    return 1;
  }
  buf[n] = '\0';
  std::cout << buf;

  unlink(clientPath.c_str());
  close(fd);
  return 0;
}
