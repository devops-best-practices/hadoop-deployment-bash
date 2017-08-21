#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2015

exit 1

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  service iptables save

  sed -i -e '/--dport 22/i\
  -A INPUT -p tcp -m state --state NEW -m tcp --dport 88  -j ACCEPT\
  -A INPUT -p tcp -m state --state NEW -m tcp --dport 464 -j ACCEPT\
  -A INPUT -p tcp -m state --state NEW -m tcp --dport 749 -j ACCEPT\
  -A INPUT -p udp -m udp --dport 88  -j ACCEPT\
  -A INPUT -p udp -m udp --dport 464 -j ACCEPT\
  -A INPUT -p udp -m udp --dport 749 -j ACCEPT' /etc/sysconfig/iptables

  service iptables restart
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi
