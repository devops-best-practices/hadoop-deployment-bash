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
# Copyright Clairvoyant 2018

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
echo "Enabling Bash History Timestamps..."
cat <<EOF >/etc/profile.d/shell_history.sh
# Enable shell command history timestamps.
# CLAIRVOYANT
export HISTTIMEFORMAT="%F %T "
EOF
chown root:root /etc/profile.d/shell_history.sh
chmod 0644 /etc/profile.d/shell_history.sh
