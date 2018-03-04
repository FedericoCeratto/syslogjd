# Package

version       = "0.1.0"
author        = "Federico Ceratto"
description   = "Syslog to journald / systemd collector"
license       = "GPLv3"

# Dependencies

requires "nim >= 0.17.2", "morelogging"

skipDirs = @["tests"]

bin       = @["syslogjd"]

task build_deb, "build deb package":
  exec "dpkg-buildpackage -us -uc -b"

task install_deb, "install deb package":
  exec "sudo debi"

task build_rpm, "build rpm package":
  exec "rpmbuild syslogjd.spec"
