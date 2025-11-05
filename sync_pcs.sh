#!/bin/bash

echo "#####################################" >>/var/log/sn.antoniuskolleg.de/sync_pcs.sh
echo "###  $(date)  ###" >>/var/log/sn.antoniuskolleg.de/sync_pcs.sh
echo "#####################################" >>/var/log/sn.antoniuskolleg.de/sync_pcs.sh
echo "" >>/var/log/sn.antoniuskolleg.de/sync_pcs.sh



#
# wakeonlan Umleitung via Unifi
#
PATH=/usr/local/lib/linbo-scripts-ak/ssh-wol:$PATH




#echo $PATH
function linbo-do() {
  /usr/sbin/linbo-remote -b 30 -u -g linux-efi -w 60 -n -p initcache,sync:1,halt,halt | tee -a /var/log/sn.antoniuskolleg.de/sync_pcs.sh
  /usr/sbin/linbo-remote -b 30 -u -g linux-efi-p6012 -w 60 -n -p initcache,sync:1,halt,halt | tee -a /var/log/sn.antoniuskolleg.de/sync_pcs.sh
}
linbo-do 2>&1 | grep -E "(-fj-|magic)" #remove Warning

weekday="$(date "+%u")"
if [ "${weekday}" -lt 6 -a "${weekday}" -gt 1 ]; then
  sleep 3600 #60 Minuten warten
  hosts_not_synced=$(lm-devices --hosts --show-version --outdated --quiet)
  hosts_not_synced_count=$(${hosts_not_synced} | wc -l)
  if [ ${hosts_not_synced_count} -gt 0 ]; then
    echo Es wurden ${hosts_not_synced_count} Rechner nicht aktualisiert:
    echo ${hosts_not_synced}
  fi
fi
