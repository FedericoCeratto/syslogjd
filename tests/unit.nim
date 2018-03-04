## syslogjd - syslog to Journald collector - unit tests
# Copyright 2018 Federico Ceratto <federico.ceratto@suse.com> <federico.ceratto@gmail.com>
# Released under GPLv3. See LICENSE file.

import unittest

from syslogjd import parse_log

suite "test":
  test "syslog":
    # generated by syslog
    let log = parse_log "<13>Mar  3 12:31:53 hostname kernel: foo"
    check log.priority == "13"

  test "logger":
    # generated by /usr/bin/logger
    let log = parse_log "<5>Mar  4 15:31:53 username: msg"
    check log.priority == "5"

suite "test RFC3164":
  test "1":
    let log = parse_log "<13>Feb  5 17:32:18 10.0.0.99 Use the BFG!"

  test "2":
    let log = parse_log "<34>Oct 11 22:14:15 mymachine su: 'su root' failed for lonvick on /dev/pts/8"


suite "test RFC5424":
  test "0":
    discard parse_log """<10>1 tstamp hostname appname procid msgid [foo="bar"]"""
    discard parse_log """<10>1 tstamp hostname appname procid msgid msg"""
    let log = parse_log """<10>1 tstamp hostname appname procid msgid [foo="bar"] msg"""
    check log.priority == "10"
    check log.hostname == "hostname"
    check log.appname == "appname"
    check log.procid == "procid"
    check log.msgid == "msgid"
    check log.msg == """[foo="bar"] msg"""

  test "1":
    # <pri>ver yyyy-mm-ddThh:mm:ss[.mils+00:00] hostname appname msg
    const raw = """<13>1 2018-02-07T22:00:07.164183+00:00 hostname appname - - [timeQuality tzKnown="1" isSynced="1" syncAccuracy="166500"] Test message"""
    let log = parse_log raw
    check log.is_rfc5424
    check log.priority == "13"
    check log.hostname == "hostname"
    check log.appname == "appname"

  test "2":
    const raw = """<14>1 2020-01-01T05:10:20.841485+01:00 myserver syslogtest 5252 some_unique_msgid - \xef\xbb\xbfHi"""
    let log = parse_log raw
    check log.is_rfc5424
    check log.priority == "14"

  test "3":
    const raw = """<14>1 2000-01-01T17:11:11.111111+06:00 testhostname my_appname 111 - -"""
    let log = parse_log raw
    check log.is_rfc5424

  test "4":
    const raw = """<34>1 2003-10-11T22:14:15.003Z mymachine.example.com su - ID47 - BOM'su root' failed for lonvick on /dev/pts/8"""
    let log = parse_log raw
    check log.is_rfc5424
    check log.priority == "34"

  test "5":
    const raw = """<165>1 2003-08-24T05:14:15.000003-07:00 192.0.2.1 myproc 8710 - - %% It's time to make the do-nuts."""
    let log = parse_log raw
    check log.is_rfc5424
    check log.priority == "165"
    check log.hostname == "192.0.2.1"

  test "6":
    const raw = """<165>1 2003-10-11T22:14:15.003Z mymachine.example.com evntslog - ID47 [exampleSDID@32473 iut="3" eventSource= "Application" eventID="1011"] BOMAn"""
    let log = parse_log raw
    check log.is_rfc5424
    check log.priority == "165"

  test "unsupported":
    const raw = """<165>2 2003-10-11T22:14:15.003Z mymachine.example.com evntslog """
    expect Exception:
      let log = parse_log raw