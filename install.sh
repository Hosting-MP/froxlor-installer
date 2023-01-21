#!/bin/sh
#---------------------------------------------------------------------
#
# Froxlor Installer
#
# Script: froxlor-install.sh
# Version: 2.0.1
# Author: Hosting-MP.de <info@hosting-mp.com>
# Description: This script will install all components needed to run
# Froxlor (https://froxlor.org) on your server.
#---------------------------------------------------------------------


######################################################################
########################## Helper Functions ##########################
######################################################################

#---------------------------------------------------------------------
# Skip all other parts of this programm
# if froxlor has been installed already
# and just run the reconfiguration utility.
#---------------------------------------------------------------------
# directory where froxlor-install.sh is located in
DIR="$(dirname "$(realpath "${0}")")"

if [ -f $DIR/INSTALLED ]; then
  ansible-playbook "${DIR}/playbook.yaml" && exit 0 || exit 1
fi

#---------------------------------------------------------------------
# Command shell
#---------------------------------------------------------------------
# Run a command in the background.
_evalBg() {
    # no hurry
    sleep 0.2
    nohup $@ >>"$LOGFILE" 2>&1 &
    wait
}


#---------------------------------------------------------------------
# Check if script is executed with root permissions
#---------------------------------------------------------------------
runAsRoot() {

  # Check if this script is run with root permissions
  if [ "$(id -u)" -ne 0 ]; then
    $echo_cmd "This script must be run as root"
    exit 1
  else
    return 0
  fi

}


#---------------------------------------------------------------------
# Check if OS is supported
#---------------------------------------------------------------------
getDistro() {
  echo "$(cat /etc/os-release | awk -F '=' '/^ID=/{print $2}' | tr -d '"')"
}
getDistroVersion() {
  echo "$(cat /etc/os-release | awk -F '=' '/^VERSION_ID=/{print $2}' | awk -F '.' '{print $1}' | tr -d '"')"
}
isOSsupported() {


  supported_distro_versions="debian12 ubuntu22 centos9 rhel9 rocky9 almalinux9 freebsd13"
  for distro in $supported_distro_versions; do
    if [ $distro = "$(getDistro)$(getDistroVersion)" ]; then
      return 0
    fi
  done
  $echo_cmd "Unsupported Operating System: $(getDistro)$(getDistroVersion)";
  exit 1

}


#---------------------------------------------------------------------
# Checking if webserver software has been preinstalled
#---------------------------------------------------------------------
checkWebServerInstalled() {

  if [ -x "$(command -v apache2)" ] || [ -x "$(command -v nginx)" ]; then
    $echo_cmd "\e[31mError choosing webserver. Maybe there is already a webserver installed.\e[0m"
    exit 1
  else
    return 0
  fi

}


#---------------------------------------------------------------------
# Checking if webserver software has been preinstalled
#---------------------------------------------------------------------
changeHostname() {
  newHostname="$1"
  newShortHostname="$(echo $newHostname | perl -ne 'print $1 if /([\w\-]+)\.[\w\-]+\..*/')" # ^[\w\-]+(?=\.[\w\-]+\.) for match only
  mainIPv4="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -Ev '^(127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})')"
  mainIPv6="$(ifconfig | grep -Eo 'inet6 (addr:)?([a-f0-9]*::?){1,7}[a-f0-9]*' | grep -Eo '([a-f0-9]*::?){1,7}[a-f0-9]*' | grep -Ev '^(fe80:|::1)')"

  sed -i -e 's/^127\.0\.0\.1.*/127.0.0.1    localhost/g' /etc/hosts
  sed -i -e 's/^::1.*/::1       localhost/g' /etc/hosts

  # it is ugly to use a temp file but perl does not support inplace editing for appends
  if [ ! -z "$mainIPv4" ]; then
    perl -ne '$c=1 if s/^'"$mainIPv4"'.*$/'"$mainIPv4"'\t\t'"$newHostname $newShortHostname"'/;print;END{print "'"$mainIPv4"'\t\t'"$newHostname $newShortHostname"'" unless $c==1}' /etc/hosts > /etc/hosts.tmp && mv /etc/hosts.tmp /etc/hosts
  fi
  if [ ! -z "$mainIPv6" ]; then
    perl -ne '$c=1 if s/^'"$mainIPv6"'.*$/'"$mainIPv6"'\t\t'"$newHostname $newShortHostname"'/;print;END{print "'"$mainIPv6"'\t\t'"$newHostname $newShortHostname"'" unless $c==1}' /etc/hosts > /etc/hosts.tmp && mv /etc/hosts.tmp /etc/hosts
  fi

  if [ "$(uname)" = 'FreeBSD' ]; then
      sed -i -e 's/^hostname=.*/hostname="'"$newHostname"'"/g' /etc/rc.conf
      hostname $newHostname
    elif [ "$(uname)" = 'Linux' ]; then
      hostnamectl set-hostname $newHostname
    else
     $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported distribution. Only Linux and FreeBSD are supported. \e[97m\e[41mX\e[0m"
  fi
}


#---------------------------------------------------------------------
# Other functions
#---------------------------------------------------------------------
genRandomPasswd() {
  lenght=$1
  echo "$(< /dev/urandom env LC_ALL=C tr -dc _A-Z-a-z-0-9 | head -c${1:-$lenght};echo;)"
  return 0
}
setEchoCmd() {
  # Define command for echo to support colors
  if [ "debian" = "$(getDistro)" ] || [ "ubuntu" = "$(getDistro)" ]; then
    echo_cmd="echo"
  else
    echo_cmd="echo -e"
  fi
}


#---------------------------------------------------------------------
# Resource handling
#---------------------------------------------------------------------
loadResource() {
  FROXLOR_TEMP_PATH=$DIR
  if [ ! -f "${FROXLOR_TEMP_PATH}/${1}.sh" ]; then
    FROXLOR_TEMP_PATH="/tmp/froxlor-installer"
    if [ ! -d $FROXLOR_TEMP_PATH ]; then
      mkdir $FROXLOR_TEMP_PATH
    fi
    wget -q -O "${ROXLOR_TEMP_PATH}/${1}.sh" "https://raw.githubusercontent.com/Hosting-MP/froxlor-installer/master/$1.sh" || logError "Failed downloading resource: ${1}" | exit 1
  fi
  . "${FROXLOR_TEMP_PATH}/${1}.sh" || logError "Failed loading resource: ${1}" | exit 1
}

cleanFiles() {
  if [ -d "/tmp/froxlor-installer/" ]; then
    rm -R /tmp/froxlor-installer/
  fi
  touch $DIR/INSTALLED
}


#---------------------------------------------------------------------
# Logger
#---------------------------------------------------------------------
getLogFile() {
  if ! [ -f $LOGFILE ]; then
    touch $LOGFILE
  else
    cat /dev/null > $LOGFILE
  fi
  return 0
}

logStatus() {
  STATUS_msg="$1"
  echo "$(date "+%d.%m.%Y %T") : $STATUS_msg" > $LOGFILE 2>&1
}

logError() {
  ERROR_msg="$1"
  $echo_cmd "\e[31mError during installation:\e[0m $ERROR_msg"
  echo "$(date "+%d.%m.%Y %T") : Error during installation: $ERROR_msg" >> $LOGFILE 2>&1
}


#---------------------------------------------------------------------
# Install Ansible
#---------------------------------------------------------------------
installAnsible() {
  if [ -x "$(command -v ansible)" ]; then
    $echo_cmd "Ansible found, continueing..."
  else
    if [ "$(uname)" = 'FreeBSD' ]; then
      if [ -x "$(command -v pkg)" ]; then
        $echo_cmd "\e[32mInstalling ansible... Please wait.\e[0m"
        echo ""
        cmd="pkg install -y py39-ansible py39-pymysql"
        _evalBg "${cmd}"
        ansible -m raw -a "pkg install -y python39 python3 python" localhost
      else
        $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported package management system  \e[97m\e[41mX\e[0m"
        $echo_cmd "\e[31mOnly supported: \e[31mpkg\e[0m"
      fi
    elif [ "$(uname)" = 'Linux' ]; then
      if [ -x "$(command -v apt-get)" ]; then
        $echo_cmd "\e[32mInstalling ansible... Please wait.\e[0m"
        echo ""
        cmd="apt-get update"
        _evalBg "${cmd}"
		cmd="apt-get install -y ansible python3-pymysql --no-install-recommends"
        _evalBg "${cmd}"
      elif [ -x "$(command -v dnf)" ]; then
        $echo_cmd "\e[32mInstalling ansible... Please wait.\e[0m"
        echo ""
        cmd="dnf install -y epel-release"
        _evalBg "${cmd}"
		cmd="dnf clean all"
        _evalBg "${cmd}"
		cmd="dnf update"
        _evalBg "${cmd}"
		cmd="dnf install -y ansible python3-PyMySQL"
        _evalBg "${cmd}"
      else
        $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported package management system  \e[97m\e[41mX\e[0m"
        $echo_cmd "\e[31mOnly supported: \e[31mapt-get and dnf\e[0m"
      fi
    else
     $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported distribution. Only Linux and FreeBSD are supported. \e[97m\e[41mX\e[0m"
     exit 1
    fi
  fi
}

#---------------------------------------------------------------------
# Install required Tools
#---------------------------------------------------------------------
installTools() {
  if [ -x "$(command -v perl)" ] && [ -x "$(command -v wget)" ] && [ -x "$(command -v ifconfig)" ]; then
    $echo_cmd "All required tools found, continueing..."
  else
    if [ "$(uname)" = 'FreeBSD' ]; then
      if [ -x "$(command -v pkg)" ]; then
        $echo_cmd "\e[32mInstalling required tools... Please wait.\e[0m"
        echo ""
		cmd="pkg install -y wget"
        _evalBg "${cmd}"
      else
        $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported package management system  \e[97m\e[41mX\e[0m"
        $echo_cmd "\e[31mOnly supported: \e[31mpkg\e[0m"
      fi
    elif [ "$(uname)" = 'Linux' ]; then
      if [ -x "$(command -v apt-get)" ]; then
        $echo_cmd "\e[32mInstalling required tools... Please wait.\e[0m"
        echo ""
        cmd="apt-get update"
        _evalBg "${cmd}"
        cmd="apt-get install -y perl wget net-tools --no-install-recommends"
        _evalBg "${cmd}"
      elif [ -x "$(command -v dnf)" ]; then
        $echo_cmd "\e[32mInstalling required tools... Please wait.\e[0m"
        echo ""
        cmd="dnf update"
        _evalBg "${cmd}"
        cmd="dnf install -y perl wget net-tools"
        _evalBg "${cmd}"
      else
        $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported package management system  \e[97m\e[41mX\e[0m"
        $echo_cmd "\e[31mOnly supported: \e[31mapt-get and dnf\e[0m"
      fi
    else
     $echo_cmd "\e[97m\e[41mX\e[0m\e[31m Unsupported distribution. Only Linux and FreeBSD are supported. \e[97m\e[41mX\e[0m"
     exit 1
    fi
  fi
}


######################################################################
############################# Pre-Checks #############################
######################################################################

#---------------------------------------------------------------------
# First make sure everything is compatible
#---------------------------------------------------------------------

setEchoCmd
runAsRoot
isOSsupported
checkWebServerInstalled


#---------------------------------------------------------------------
# Global variables
#---------------------------------------------------------------------
LOGFILE=$DIR/froxlor-installer.log
# Starting logger
getLogFile
logStatus "Starting work"

#---------------------------------------------------------------------
# Load resources
#---------------------------------------------------------------------
installTools
loadResource "installer"



######################################################################
########################### Actual Process ###########################
######################################################################



#---------------------------------------------------------------------
# Collecting data and asking user
#---------------------------------------------------------------------
ask 1


#---------------------------------------------------------------------
# Starting actual install process
#---------------------------------------------------------------------

# hostname is changed in frontend
installAnsible
ansible-playbook "${DIR}/pre-playbook.yaml" -e '{"froxlor_settings":{"webserver":"apache2","leenabled":"false"}}' || exit 1


#---------------------------------------------------------------------
# Collecting other data and wait for user to configure froxlor
#---------------------------------------------------------------------
ask 2

#---------------------------------------------------------------------
# Performing the main installation
#---------------------------------------------------------------------
ansible-playbook "${DIR}/playbook.yaml" || exit 1


#---------------------------------------------------------------------
# Finished install process
#---------------------------------------------------------------------

ask 3 # display installation has finished message
logStatus "Finished Part 2/2"
cleanFiles
exit 0