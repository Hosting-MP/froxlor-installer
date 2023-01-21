#! /bin/sh

ask() {

  # File path definitions
  froxlor_cnf="$HOME/.froxlor.cnf"
  froxlor_root_cnf="$HOME/.froxroot.cnf"
  froxlor_folder="/var/www/html/froxlor"
  userdata_inc="${froxlor_folder}/lib/userdata.inc.php"

  if [ $1 -eq 1 ]; then
    # clear terminal before starting pre-installation process
    printf "\033c"

    # Installer header
    $echo_cmd "        \e[32m\e[42m#####################\e[49m\e[0m"
    $echo_cmd "        \e[32m\e[42m#\e[49m\e[0m\e[33m Froxlor Installer \e[32m\e[42m#\e[49m\e[0m"
    $echo_cmd "        \e[32m\e[42m#####################\e[49m\e[0m"
    $echo_cmd ""
    $echo_cmd ""
    $echo_cmd "\e[93m--> \e[91mCollecting data first:\e[0m"
    $echo_cmd ""
    $echo_cmd ""

    # Asking for user data
    $echo_cmd "\e[94m------------------------\e[0m"
    hostnamecmd=$(hostname -f 2> /dev/null || hostname 2> /dev/null)
    while [ "$hostname" = "" ]; do
      read -p "FQDN Hostname [$hostnamecmd]: " hostname
      if [ -z $hostname ]; then
        hostname="$hostnamecmd"
      fi
      if ! echo "$hostname" | grep -qE "[a-zA-Z0-9\-\_\+\.]+\.[a-zA-Z0-9\-\_\+\.]+\.[a-zA-Z0-9]{2,10}"; then
        $echo_cmd '\e[1;31mfailed\e[0m - \e[35mdesired format: xxx.domain.tld\e[0m'
        hostname=""
      else
        changeHostname $hostname && $echo_cmd '\e[32msuccess\e[0m' || $echo_cmd '\e[34mcommand failed - please manually update\e[0m'
      fi
    done
    $echo_cmd "\e[94m------------------------\e[0m"


    $echo_cmd "\e[93m--> \e[91mStarting the installation process!\e[0m"
    $echo_cmd ""
    
    return 0

  elif [ $1 -eq 2 ]; then
    ### pause installation process to let user continue in browser with froxlor web installer
    printf "\033c"
    $echo_cmd ""
    $echo_cmd "\e[92mFirst part of installation finished\e[0m"
    $echo_cmd ""
    $echo_cmd "Continue froxlor install in your web browser:"
    $echo_cmd "\e[4mhttp://$( wget -qO- ipv4.icanhazip.com )/froxlor\e[0m"
    $echo_cmd "\e[4mhttp://$hostname/froxlor\e[0m"
    $echo_cmd ""
    $echo_cmd ""
    if [ -f $froxlor_cnf ]; then
      froxlorunprivilegedpasswd="$(awk -F "=" '/password/ {print $2}' "$froxlor_cnf" | tr -d '\n')"
      froxlorunprivilegeduser="$(awk -F "=" '/user/ {print $2}' "$froxlor_cnf" | tr -d '\n')"
    else
      froxlorunprivilegedpasswd="$(genRandomPasswd 16)"
      froxlorunprivilegeduser="froxlor"
    fi
    if [ -f $froxlor_root_cnf ]; then
      froxlorprivilegedpasswd="$(awk -F "=" '/password/ {print $2}' "$froxlor_root_cnf" | tr -d '\n')"
      froxlorprivilegeduser="$(awk -F "=" '/user/ {print $2}' "$froxlor_root_cnf" | tr -d '\n')"
    else
      froxlorprivilegedpasswd="$(genRandomPasswd 20)"
      froxlorprivilegeduser="froxroot"
    fi
    sleep 1
    $echo_cmd "FroxlorUnprivileged: User=\e[1m$froxlorunprivilegeduser\e[0m Password=\e[1m$froxlorunprivilegedpasswd\e[0m"
    $echo_cmd "FroxlorRoot: User=\e[1m$froxlorprivilegeduser\e[0m Password=\e[1m$froxlorprivilegedpasswd\e[0m"
    $echo_cmd "Froxlor-Admin-Password: $(genRandomPasswd 12)"
    sleep 1
    $echo_cmd "Copy these to the web browser installation process. \e[5mThese passwords are mandatory and case-sensitive!\e[0m"
    $echo_cmd ""
    $echo_cmd ""
    $echo_cmd "This information will be stored at ~/.froxlor.cnf !"
    $echo_cmd ""
    $echo_cmd ""
    $echo_cmd "\e[33mOnce completed the web part of installation continue here..\e[0m"
    $echo_cmd "\e[91mDo not execute any commands despite the last step of installation tells you to do so.\e[33m Choose manual installation instead.\e[0m"

    if [ ! -f $froxlor_root_cnf ]; then
      # This is ugly but since it is used for one command only it should be ok
      if [ "$(uname)" = 'FreeBSD' ] && [ -f /root/.mysql_secret ]; then
        mysql_root_password=$(cat /root/.mysql_secret | sed -n 2p)
        # It is not good practise to reset mysql password to the same value as before but the sys admin should change it later by himself.
        mysql -u root -p$mysql_root_password --connect-expired-password <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysql_root_password';
EOF
        mysql -u root -p$mysql_root_password <<EOF
CREATE USER 'froxroot'@'localhost' IDENTIFIED BY '$froxlorprivilegedpasswd';
GRANT ALL PRIVILEGES ON * . * TO 'froxroot'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
      else
        mysql -u root <<EOF
CREATE USER 'froxroot'@'localhost' IDENTIFIED BY '$froxlorprivilegedpasswd';
GRANT ALL PRIVILEGES ON * . * TO 'froxroot'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
      fi

      cat > $froxlor_root_cnf <<EOF
[client]
# The following password is used by all standard MySQL clients
password=$froxlorprivilegedpasswd
user=froxroot
host=localhost
EOF
    fi

    sleep 2

    # wait for user to finish web part of installation to let him continue here then
    $echo_cmd "\e[94m------------------------\e[0m"
    while true; do
      read -p "Webinstallation completed so continue here? [yN]" yn
      yn=${yn:-n}
      case $yn in
        [Yy]* ) installfinished=true; break;;
        [Nn]* ) installfinished=false;;
        * ) $echo_cmd '\e[33mPlease answer \e[32m(y)es\e[33m or \e[31m(n)o\e[33m.\e[0m';;
      esac
    done
    $echo_cmd "\e[94m------------------------\e[0m"
    while [ "$froxlordatabasename" = "" ]; do
	  froxlordatabasenamecmd="$([ -f "$froxlor_cnf" ] && awk -F "=" '/database/ {print $2}' "$froxlor_cnf"  | tr -d '\n' || echo "froxlor" 2> /dev/null)"
      read -p "Froxlor database name [$froxlordatabasenamecmd]: " froxlordatabasename
      if [ -z $froxlordatabasename ]; then
        froxlordatabasename="$froxlordatabasenamecmd"
      fi
      if ! echo "$froxlordatabasename" | grep -qE "[a-zA-Z0-9\_]{2,10}"; then
        $echo_cmd '\e[1;31mfailed\e[0m - \e[35monly letters, numbers and underscore are allowed\e[0m'
        froxlordatabasename=""
      else
        $echo_cmd '\e[32msuccess\e[0m'
      fi
    done
    $echo_cmd "\e[94m------------------------\e[0m"

    if [ ! -f $froxlor_cnf ]; then
      cat > $froxlor_cnf <<EOF
[client]
# The following password is used by all froxlor MySQL clients
password=$froxlorunprivilegedpasswd
user=froxlor
host=localhost
database=$froxlordatabasename
EOF
    fi

    if [ ! -f $userdata_inc ]; then
      cat > $userdata_inc <<EOF
<?php
// autogenerated froxlor file

\$sql = [
        'debug' => false,
        'host' => 'localhost',
        'user' => 'froxlor',
        'password' => '$froxlorunprivilegedpasswd',
        'db' => '$froxlordatabasename',
];
\$sql_root = [
        '0' => [
                'caption' => 'Default',
                'host' => 'localhost',
                'user' => 'froxroot',
                'password' => '$froxlorprivilegedpasswd',
        ],
];
EOF
      # getting the user of the directory we just placed the config file in
      userdata_dir_owner_user="$(ls -ld "$froxlor_folder"/lib | awk '{print $3}')"
	  userdata_dir_owner_group="$(ls -ld "$froxlor_folder"/lib | awk '{print $4}')"
      chown ${userdata_dir_owner_user}:${userdata_dir_owner_group} $userdata_inc
    fi



    ### pause installation process to let user continue in browser with froxlor settings
    printf "\033c"
    $echo_cmd ""
    $echo_cmd "\e[92mSecond part of installation finished\e[0m"
    $echo_cmd ""
    $echo_cmd "Now adjust the froxlor settings in your web browser:"
    $echo_cmd "\e[4mhttp://$( wget -qO- ipv4.icanhazip.com )/froxlor/admin_settings.php\e[0m"
    $echo_cmd "\e[4mhttp://$hostname/froxlor/admin_settings.php\e[0m"
    $echo_cmd ""
    $echo_cmd ""
    sleep 1
    $echo_cmd "\e[91mDo NOT (re)build any config files or start cron.\e[0m"
    $echo_cmd "\e[91mOnly change settings: [System -> Settings]\e[0m"

    # wait for user to finish adjust settings and let him continue here then
    $echo_cmd "\e[94m------------------------\e[0m"
    while true; do
      read -p "Adjusting settings completed so continue here? [yN]" yn
      yn=${yn:-n}
      case $yn in
        [Yy]* ) settingsfinished=true; break;;
        [Nn]* ) settingsfinished=false;;
        * ) $echo_cmd '\e[33mPlease answer \e[32m(y)es\e[33m or \e[31m(n)o\e[33m.\e[0m';;
      esac
    done
    $echo_cmd "\e[94m------------------------\e[0m"

    return 0

  elif [ $1 -eq 3 ]; then

    printf "\033c"
    $echo_cmd ""
    $echo_cmd "\e[92mInstallation finished\e[0m"
    $echo_cmd ""
    $echo_cmd "You may want to 'rebuild config files' in froxlor web."
    $echo_cmd ""
    $echo_cmd ""
    $echo_cmd "\e[31mDo not forget to run mysql_secure_installation\e[0m"
    $echo_cmd ""

    php ${froxlor_folder}/bin/froxlor-cli froxlor:cron --run-task 99
	if [ -x "$(command -v apt-get)" ]; then
      service cron reload
	else
	  service crond reload
	fi

    return 0

  fi
}