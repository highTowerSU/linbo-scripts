#!/bin/bash

LOG_DIR=${LOG_DIR:-/var/log/linbo-scripts}
LOG_FILE="${LOG_DIR}/sync_pcs.sh"

mkdir -p "${LOG_DIR}"

echo "#####################################" >>"${LOG_FILE}"
echo "###  $(date)  ###" >>"${LOG_FILE}"
echo "#####################################" >>"${LOG_FILE}"
echo "" >>"${LOG_FILE}"



#
# wakeonlan Umleitung via Unifi
#
PATH=/usr/local/lib/linbo-scripts-ak/ssh-wol:$PATH




#echo $PATH
DEFAULT_LINBO_GROUPS=("linux-efi" "linux-efi-p6012")
LINBO_GROUPS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--group)
      if [[ -z "${2:-}" ]]; then
        echo "Fehlender Gruppenname nach '$1'" >&2
        exit 1
      fi
      LINBO_GROUPS+=("$2")
      shift 2
      ;;
    --group=*)
      LINBO_GROUPS+=("${1#*=}")
      shift
      ;;
    *)
      echo "Unbekannte Option: $1" >&2
      echo "Verwendung: $0 [-g GRUPPE] [--group=GRUPPE]" >&2
      exit 1
      ;;
  esac
done

if [[ ${#LINBO_GROUPS[@]} -eq 0 ]]; then
  if [[ -n "${LINBO_DEFAULT_GROUPS:-}" ]]; then
    # shellcheck disable=SC2206
    LINBO_GROUPS=(${LINBO_DEFAULT_GROUPS})
  else
    LINBO_GROUPS=("${DEFAULT_LINBO_GROUPS[@]}")
  fi
fi

if [[ ${#LINBO_GROUPS[@]} -eq 0 ]]; then
  echo "Keine LINBO-Gruppen definiert." >&2
  exit 1
fi

echo "Synchronisiere Gruppen: ${LINBO_GROUPS[*]}" >>"${LOG_FILE}"
echo "Synchronisiere Gruppen: ${LINBO_GROUPS[*]}"

function linbo-do() {
  local group
  for group in "${LINBO_GROUPS[@]}"; do
    /usr/sbin/linbo-remote -b 30 -u -g "$group" -w 60 -n -p initcache,sync:1,halt,halt | tee -a "${LOG_FILE}"
  done
}
linbo-do 2>&1 | grep -E "(-fj-|magic)" #remove Warning

weekday="$(date "+%u")"
if [ "${weekday}" -lt 6 -a "${weekday}" -gt 1 ]; then
  sleep 3600 #60 Minuten warten
  total_hosts_not_synced=0
  hosts_not_synced_output=""

  for group in "${LINBO_GROUPS[@]}"; do
    group_hosts_not_synced=()
    mapfile -t group_hosts_not_synced < <(lm-devices --hosts --show-version --outdated --quiet --type "$group" | sed '/^$/d')
    group_hosts_count=${#group_hosts_not_synced[@]}

    if [ ${group_hosts_count} -gt 0 ]; then
      total_hosts_not_synced=$((total_hosts_not_synced + group_hosts_count))
      hosts_not_synced_output+=$'Gruppe '
      hosts_not_synced_output+="${group}"
      hosts_not_synced_output+=$':\n'
      hosts_not_synced_output+=$(printf '%s\n' "${group_hosts_not_synced[@]}")
      hosts_not_synced_output+=$'\n'
    fi
  done

  if [ ${total_hosts_not_synced} -gt 0 ]; then
    echo "Es wurden ${total_hosts_not_synced} Rechner nicht aktualisiert:"
    printf '%s' "${hosts_not_synced_output}"
  fi
fi
