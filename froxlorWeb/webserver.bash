#---------------------------------------------------------------------
# Function: SetupWebServer
#    Setup WebServer so froxlor can handle it
#---------------------------------------------------------------------
setupWebServer() {

  # setting up apache2 according to froxlor config
  mkdir -p /var/customers/webs/
  mkdir -p /var/customers/logs/
  mkdir -p /var/customers/tmp
  chmod 1777 /var/customers/tmp


  if [[ "$webserverChoice" = "apache" ]]; then
    # add Lets Encrypt cases
    cat <<EOF > /etc/apache2/conf-enabled/acme.conf
Alias "/.well-known/acme-challenge" "/var/www/html/.well-known/acme-challenge"
<Directory "/var/www/html/.well-known/acme-challenge">
    Require all granted
</Directory>
EOF

    restartApache
  fi
  if [[ "$webserverChoice" = "nginx" ]]; then
  cat <<EOF > /etc/nginx/acme.conf
location /.well-known/acme-challenge {
    alias /var/www/html/.well-known/acme-challenge;

    location ~ /.well-known/acme-challenge/(.*) {
        default_type text/plain;
    }
}
EOF

    restartNginx
  fi

}
