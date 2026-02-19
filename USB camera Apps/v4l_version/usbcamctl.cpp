#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>

static std::string default_socket_path() {
  const char* env = std::getenv("USBCAMV4L_CONTROL_SOCKET");
  if (env && *env) return std::string(env);
  return "/tmp/usbcamv4l-control.sock";
}

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "Usage: " << argv[0]
              << " <command...>\n"
                 "Examples:\n"
                 "  usbcamctl status\n"
                 "  usbcamctl fps on\n"
                 "  usbcamctl rec toggle\n"
                 "  usbcamctl sync auto\n"
                 "  usbcamctl queue 4\n"
                 "  usbcamctl cam 0 reconnect\n";
    return 1;
  }

  std::string cmd;
  for (int i = 1; i < argc; ++i) {
    if (i > 1) cmd.push_back(' ');
    cmd += argv[i];
  }

  const std::string socketPath = default_socket_path();
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

  if (sendto(fd, cmd.data(), cmd.size(), 0,
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
