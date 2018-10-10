#!/bin/bash

# Original bash 
# echo "****** install aiServer dependent package ******"
# echo "zaq12wsx" |sudo -S pip install -r requirements.txt
# echo "****** start aiServer ******"
# python manage.py runserver 0.0.0.0:8000
# echo "zaq12wsx" |sudo -S supervisorctl restart ai

# ai server auto deploy script

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ai.sh install|start|stop|restart [-p password]"
  echo "  ai.sh -h|--help (print this message)"
  echo "    <mode> - one of 'install', 'start', 'stop', 'restart'"
  echo "      - 'install' - install aiServer dependent package and start ai server"
  echo "      - 'start' - start aiServer"
  echo "      - 'stop' - stop aiServer"
  echo "      - 'restart' - restart aiServer"
  echo "    -p <password> - root password"
  echo "Note: "
  echo "  1. Run ai.sh must have root permissions and should be supervisorctl required."
  echo "  2. If you deploy for the first time, you should execute install, otherwise you should execute start or stop or restart."
}

function install () {
  echo "****** install aiServer dependent package ******"
  echo $PASSWORD |sudo -S pip install -r /opt/CNN-Classifier/requirements.txt
  if [ $? -ne 0 ]; then
    echo "ERROR !!! Unable to install aiServer dependent package"
    exit 1
    else 
      configSupervisord
      exit 1
  fi
}

function start () {
  echo $PASSWORD |sudo -S supervisorctl start ai
  if [ $? -ne 0 ]; then
    echo "ERROR !!! Unable to start aiServer"
    exit 1
  fi
}

function stop () {
  echo $PASSWORD |sudo -S supervisorctl stop ai
  if [ $? -ne 0 ]; then
    echo "ERROR !!! Unable to stop aiServer"
    exit 1
  fi
}

function restart () {
  echo $PASSWORD |sudo -S supervisorctl restart ai
  if [ $? -ne 0 ]; then
    echo "ERROR !!! Unable to restart aiServer"
    exit 1
  fi
}

# config supervisord for ai server and start ai server
function configSupervisord () {
  if [ -e "/etc/supervisord.conf" ]; then 
      grep "[program:ia]" /etc/supervisord.conf > /dev/null
      if [ $? -eq 0 ]; then
        echo "Found supervisord.conf for ai!"
        start
      else
        echo "Not found supervisord.conf for ai!"
        echo -e "[program:ai]\ncommand=python /opt/CNN-Classifier/manage.py runserver 0.0.0.0:8000" >> /etc/supervisord.conf
        supervisorctl -c /etc/supervisord.conf
        start
      fi
    else
      echo "/etc/supervisord.conf is notExist"
      echo_supervisord_conf > /etc/supervisord.conf
      echo -e "[program:ai]\ncommand=python /opt/CNN-Classifier/manage.py runserver 0.0.0.0:8000" >> /etc/supervisord.conf
      supervisorctl -c /etc/supervisord.conf
      start
  fi
} 

MODE=$1;shift

# Determine whether starting, stopping and restarting

if [ "$MODE" == "start" ]; then
  EXPMODE="Starting"
elif [ "$MODE" == "stop" ]; then
  EXPMODE="Stopping"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
elif [ "$MODE" == "install" ]; then
  EXPMODE="Installing"
else
  printHelp
  exit 1
fi

while getopts "h?p:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    p) PASSWORD=$OPTARG
    ;;
  esac
done

if [ "$MODE" == "start" ]; then
  start
elif [ "$MODE" == "stop" ]; then
  stop
elif [ "$MODE" == "restart" ]; then
  restart
elif [ "$MODE" == "install" ]; then
  configSupervisord
else
  printHelp
  exit 1
fi