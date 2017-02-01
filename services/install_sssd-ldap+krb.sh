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
# Copyright Clairvoyant 2016
#
if [ $DEBUG ]; then set -x; fi
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
YUMOPTS="-y -e1 -d1"
DATE=`date '+%Y%m%d%H%M%S'`
_TLS=no

# Function to print the help screen.
print_help () {
  echo "Authenticate via Kerberos and indentify via LDAP."
  echo ""
  echo "Usage:  $1 --domain --ldapserver --krbserver"
  echo ""
  echo "        -s|--suffix        <LDAP search base>"
  echo "        -l|--ldapserver    <LDAP server>"
  echo "        -t|--tls           # use TLS for LDAP"
  echo "        -d|--domain        <Kerberos Domain>"
  echo "        -k|--krbserver     <Kerberos server>"
  echo "        [-h|--help]"
  echo "        [-v|--version]"
  echo ""
  echo "   ex.  $1"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ `/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null` -ne 0 ]]; then
    echo "You must have root priviledges to run this program."
    exit 2
  fi
}

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHat
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n" | awk -F. '{print $1"."$2}'`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
    fi
  fi
}

## If the variable DEBUG is set, then turn on tracing.
## http://www.research.att.com/lists/ast-users/2003/05/msg00009.html
#if [ $DEBUG ]; then
#  # This will turn on the ksh xtrace option for mainline code
#  set -x
#
#  # This will turn on the ksh xtrace option for all functions
#  typeset +f |
#  while read F junk
#  do
#    typeset -ft $F
#  done
#  unset F junk
#fi

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -d|--domain)
      shift
      _DOMAIN_UPPER=`echo $1 | tr '[:lower:]' '[:upper:]'`
      _DOMAIN_LOWER=`echo $1 | tr '[:upper:]' '[:lower:]'`
      ;;
    -k|--krbserver)
      shift
      _KRBSERVER=$1
      ;;
    -l|--ldapserver)
      shift
      _LDAPSERVER=$1
      ;;
    -s|--suffix)
      shift
      _LDAPSUFFIX=$1
      ;;
    -t|--tls)
      _TLS=yes
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Script"
      echo "Version: $VERSION"
      echo "Written by: $AUTHOR"
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

# Check to see if we are on a supported OS.
# Currently only EL.
discover_os
if [ "$OS" != RedHat -a "$OS" != CentOS ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
if [ -z "$_DOMAIN_LOWER" -o -z "$_KRBSERVER" -o -z "$_LDAPSERVER" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
if [ \( "$OS" == RedHat -o "$OS" == CentOS \) -a \( i"$OSREL" == 6 -o "$OSREL" == 7 \) ]; then
  echo "** Installing software."
  yum $YUMOPTS install sssd-ldap sssd-krb5 oddjob oddjob-mkhomedir

  echo "** Writing configs..."
  cp -p /etc/krb5.conf /etc/krb5.conf.${DATE}
  cat <<EOF >/etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = $_DOMAIN_UPPER
 dns_lookup_realm = true
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
$_DOMAIN_UPPER = {
 kdc = ${_KRBSERVER}
 admin_server = ${_KRBSERVER}
}

[domain_realm]
 .${_DOMAIN_LOWER} = $_DOMAIN_UPPER
 $_DOMAIN_LOWER = $_DOMAIN_UPPER
EOF

  cp -p /etc/sssd/sssd.conf /etc/sssd/sssd.conf.${DATE}
  cat <<EOF >/etc/sssd/sssd.conf
[sssd]
domains = $_DOMAIN_LOWER
config_file_version = 2
services = nss, pam

[domain/${_DOMAIN_LOWER}]
id_provider = ldap
access_provider = simple
#access_provider = ldap
auth_provider = krb5
chpass_provider = krb5
min_id = 1000
cache_credentials = true
EOF
  if [ "$_TLS" == yes ]; then
    cat <<EOF >>/etc/sssd/sssd.conf
ldap_uri = ldaps://${_LDAPSERVER}:636/
ldap_tls_cacert = /etc/pki/tls/certs/ca-bundle.crt
ldap_id_use_start_tls = true
EOF
  else
    cat <<EOF >>/etc/sssd/sssd.conf
ldap_uri = ldap://${_LDAPSERVER}/
ldap_tls_reqcert = never
EOF
  fi
  cat <<EOF >>/etc/sssd/sssd.conf
ldap_search_base = $_LDAPSUFFIX
#ldap_schema = rfc2307bis
ldap_pwd_policy = mit_kerberos
ldap_access_filter = memberOf=cn=admin,ou=Groups,${_LDAPSUFFIX}
simple_allow_groups = admin, developer
krb5_realm = $_DOMAIN_UPPER
krb5_server = $_KRBSERVER
krb5_lifetime = 24h
krb5_renewable_lifetime = 7d
krb5_renew_interval = 1h
krb5_ccname_template = KEYRING:persistent:%U
krb5_store_password_if_offline = true
EOF
  chmod 0600 /etc/sssd/sssd.conf

  authconfig --enablesssd --enablesssdauth --enablemkhomedir --update
  service sssd start
  chkconfig sssd on
  service oddjobd start
  chkconfig oddjobd on
fi

if [ -f /etc/nscd.conf ]; then
  echo "*** Disabling NSCD caching of passwd/group/netgroup/services..."
  if [ ! -f /etc/nscd.conf-orig ]; then
    cp -p /etc/nscd.conf /etc/nscd.conf-orig
  else
    cp -p /etc/nscd.conf /etc/nscd.conf.${DATE}
  fi
  sed -e '/enable-cache[[:blank:]]*passwd/s|yes|no|' \
      -e '/enable-cache[[:blank:]]*group/s|yes|no|' \
      -e '/enable-cache[[:blank:]]*services/s|yes|no|' \
      -e '/enable-cache[[:blank:]]*netgroup/s|yes|no|' -i /etc/nscd.conf
  service nscd condrestart
  if ! service sssd status >/dev/null 2>&1; then
    service sssd restart
  fi
fi

