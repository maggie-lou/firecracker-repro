#!/usr/bin/env bash
set -eu

# Run with `make test`.

if [[ $(id -u) != 0 ]]; then
  exec sudo "$0" "$@"
fi

API_SOCKET=/tmp/firecracker.sock
LOGFILE=/tmp/firecracker.log
SNAPSHOT_PATH=/tmp/vmstate.snap
MEM_FILE_PATH=/tmp/memory.snap

rm -f "$API_SOCKET" "$LOGFILE"
touch "$LOGFILE"

# Run firecracker in the background until the script exits
./firecracker --api-sock "$API_SOCKET" &
FIRECRACKER_PID=$!
trap 'kill -TERM $FIRECRACKER_PID $TAIL_PID' EXIT

function curlfc() {
  METHOD="$1"
  URL="$2"
  DATA="$3"

  echo "$METHOD $URL ..."
  RESPONSE=$(curl -sS -X "$METHOD" --unix-socket "$API_SOCKET" "http://localhost$URL" --data "$DATA")
  FAULT_MESSAGE=$(echo "$RESPONSE" | jq -r '.fault_message')
  if [[ "$FAULT_MESSAGE" ]]; then
    echo >&2 "fault: $FAULT_MESSAGE"
    exit 1
  fi
  echo >&2 OK
}

curlfc PUT /logger '{
  "log_path": "'$LOGFILE'"
}'

curlfc PUT /boot-source '{
  "kernel_image_path": "./vmlinux",
  "boot_args": "ro console=ttyS0 noapic reboot=k panic=1 pci=off nomodule random.trust_cpu=on i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd tsc=reliable ipv6.disable=1",
  "initrd_path": "./initrd.cpio"
}'

curlfc PUT /actions '{"action_type": "InstanceStart"}'

tail -f "$LOGFILE" &
TAIL_PID=$!

for i in $(seq 100); do
  echo "--- Round $i: Letting the VM run for a little while ..."
  sleep 1

  curlfc PATCH /vm '{"state": "Paused"}'

  rm -rf "$SNAPSHOT_PATH" "$MEM_FILE_PATH"

  curlfc PUT /snapshot/create '{
    "snapshot_type": "Full",
    "snapshot_path": "'$SNAPSHOT_PATH'",
    "mem_file_path": "'$MEM_FILE_PATH'"
  }'

  echo '--- Stopping and restarting firecracker ...'
  kill -TERM $FIRECRACKER_PID
  wait $FIRECRACKER_PID || true
  rm -f "$API_SOCKET"
  ./firecracker --api-sock "$API_SOCKET" &
  FIRECRACKER_PID=$!

  curlfc PUT /logger '{
    "log_path": "'$LOGFILE'"
  }'

  echo '--- Loading snapshot and resuming VM ...'
  curlfc PUT /snapshot/load '{
    "snapshot_path": "'$SNAPSHOT_PATH'",
    "mem_backend": {
      "backend_type": "File",
      "backend_path": "'$MEM_FILE_PATH'"
    },
    "resume_vm": true
  }'
done
