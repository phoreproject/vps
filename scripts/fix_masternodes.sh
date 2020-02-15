#!/bin/bash

fixMasternode() {
  echo "Starting recovery for masternode $1..."
  echo "Stopping masternode $1"
  systemctl stop phore_n$1
  echo "Changing directory"
  cd /var/lib/masternodes/phore$1
  myDir=$(pwd)
  echo $myDir
  echo "Removing blockchain files"
  rm -rf blocks chainstate sporks zerocoin peers.dat
  mv debug.log debug.old
  echo "Downloading latest snapshot"
  wget https://github.com/phoreproject/Phore/releases/download/v1.6.3/PhoreSnapshot.tgz
  tar zxvf PhoreSnapshot.tgz
  rm PhoreSnapshot.tgz
  chown -R masternode:masternode blocks chainstate sporks zerocoin
  echo "Restarting masternode $1"
  systemctl start phore_n$1
  echo "Waiting for masternode initialization"
  sleep 120
  echo "Waiting for hot node status..."
  sed '/activation/q' <(tail -n 0 -f debug.log)
  echo "Masternode $1 is recovered, please start masternode from wallet."
  cd
}

checkStatus() {
  #echo "checkStatus $1"
  statusCommand="/usr/local/bin/phore-cli -conf=/etc/masternodes/phore_n$1.conf masternode status 2>&1"
  #echo $statusCommand
  mnStatus="$(eval $statusCommand)"
  #echo "$mnStatus"
  case $mnStatus in
    *"Masternode successfully started"*)
      echo "Masternode $1 successfully started"
      echo "Nothing to be done."
    ;;
    *"activation"*)
      echo "Masternode $1 waiting for remote activation"
      echo "Please start masternode from wallet and try again"
    ;;
    error*"not a masternode"*)
      echo "Masternode $1 is not a masternode"
      fixMasternode $1
    ;;
    *"Node just started"*)
      echo "Masternode $1 just started."
      fixMasternode $1
    ;;
    *"connect to server"*)
      echo "Masternode $1: Couldn't connect to server"
      fixMasternode $1
    ;;
    *)
      echo "Masternode $1: Could not determine status"
    ;;
  esac
}

for index in {1..9}
do
  if [ -e /etc/systemd/system/multi-user.target.wants/phore_n$index.service ]
  then
    echo "Checking mn$index"
     checkStatus $index
  fi
done