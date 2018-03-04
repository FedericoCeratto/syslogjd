## syslogjd - syslog to Journald collector
# Copyright 2018 Federico Ceratto <federico.ceratto@suse.com> <federico.ceratto@gmail.com>
# Released under GPLv3. See LICENSE file.

import net,
  os,
  sets

from posix import SIGABRT, SIGINT, SIGTERM, onSignal
from strutils import parseInt, split

from morelogging import sd_journal_send

const month_names = toSet(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"])

onSignal(SIGABRT):
  ## Handle SIGABRT from systemd
  echo "<2>Received SIGABRT"
  quit(1)

var cnt = 0

onSignal(SIGINT, SIGTERM):
  echo "syslogjd exiting..."
  quit()

proc log_parsing_error(data: string, ipaddr: string) =
  let msg = "Unable to parse '" & data & "' from " & ipaddr & " " & getCurrentExceptionMsg()
  let rc = sd_journal_send(
    "PRIORITY=7",
    "SYSLOG_FACILITY=3",
    "UNIT=syslogjd.service",
    "SYSLOG_IDENTIFIER=syslogjd",
    "SYSLOGJD_INTERNAL=error",
    "MESSAGE=" & msg,
    nil
  )

type
  Log = ref object
    priority*, date*, hostname*, appname*, procid*, msgid*, msg*: string
    is_rfc5424*: bool

proc parse_log*(rawlog: string): Log =
  ## Parse raw log message
  #echo "-->" & rawlog & "<--"
  result = Log()
  if rawlog[0] != '<':
    raise newException(Exception, "Unknown format")
  let pos = rawlog.find('>')
  if pos < 2:
    raise newException(Exception, "Unknown format")
  result.priority = rawlog[1..pos-1]
  let body = rawlog[pos+1..^1]

  if body.len < 2:
    raise newException(Exception, "Unknown format")

  if body[0..1] == "1 ":
    # RFC5424
    result.is_rfc5424 = true
    (result.date, result.hostname, result.appname,
      result.procid, result.msgid, result.msg) = body[2..^1].split(' ', maxsplit=5)

  else:
    # RFC3164 or unsupported
    var month, day, hour: string
    (month, day, hour, result.hostname, result.msg) = body.split(' ', maxsplit=5)
    if not month_names.contains(month):
      raise newException(Exception, "Unknown format")

    result.date = month & " " & day & " " & hour

  # prio = facility (0..23) * 8 + severity (0..7)


proc main() =
  echo "starting syslogjd"
  let port = 514.Port
  var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.setSockOpt(OptReusePort, true)
  socket.setSockOpt(OptReuseAddr, true)
  socket.bind_addr(port)

  while true:
    var data = ""
    var ipaddr = ""
    var remote_port: Port

    let l = socket.recv_from(data, 65536, ipaddr, remote_port)
    assert l == data.len
    if l == 0:
      continue

    if data[data.high] == '\0':
      data.setLen(data.len - 1)

    try:
      let log = parse_log(data)
      if log.is_rfc5424:
        let rc = sd_journal_send(
          "SYSLOG_FACILITY=3",
          "UNIT=syslogjd.service",
          "SYSLOG_IDENTIFIER=syslogjd",

          "PRIORITY=" & log.priority,
          "TIMESTAMP=" & log.date,
          "IPADDR=" & ipaddr,
          "HOSTNAME=" & log.hostname,
          "APPNAME=" & log.appname,
          "PROCID=" & log.procid,
          "MSGID=" & log.msgid,
          "MESSAGE=" & log.msg,
          nil
        )
      else:
        let rc = sd_journal_send(
          "SYSLOG_FACILITY=3",
          "UNIT=syslogjd.service",
          "SYSLOG_IDENTIFIER=syslogjd",

          "PRIORITY=" & log.priority,
          "TIMESTAMP=" & log.date,
          "IPADDR=" & ipaddr,
          "MESSAGE=" & log.msg,
          nil
        )
    except:
      log_parsing_error(data, ipaddr)


when isMainModule:
  main()
