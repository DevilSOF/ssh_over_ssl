#!/bin/bash

# Warning don't use this script if you're have configured apache2
# and have files in /var/www/ or it will be removed
# This script will work on Debian, Ubuntu and probably other distros
# of the same families, although no support is offered for them. It isn't
# bulletproof but it will probably work if you simply want to setup a apache2 on
# your Debian/Ubuntu box. It has been designed to be as unobtrusive and
# universal as possible.

# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -qs "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 2
fi

if [[ -e /etc/debian_version ]]; then
	OS=debian
	GROUPNAME=nogroup
	RCLOCAL='/etc/rc.local'
else
	echo "Looks like you aren't running this installer on Debian, Ubuntu"
	exit 5
fi

if [[ -e /etc/apache2/apache2.conf ]]; then
	while :
	do
	clear
		echo "Looks like SSH over SSL is already installed"
		echo ""
		echo "What do you want to do?"
		echo "   1) Uninstall apache2"
		echo "   2) Exit"
		read -p "Select an option [1-2]: " option
		case $option in
			1) 
			clear
			echo ""
			echo "Do you really want to remove apache2? "
			echo ""
			echo "WARNING! All files from:"
			echo ""
			echo "	/etc/apache2"
			echo "	/var/www/html"
			echo ""
			echo "Will be removed!"
			echo ""
			read -p "Continue [y/n]?: " -e -i n REMOVE
			if [[ "$REMOVE" = 'y' ]]; then
				if [[ "$OS" = 'debian' ]]; then
					rm -rf /var/www/html
					apt-get remove --purge -y apache2
				else
					echo "Wrong OS Exit!"
					exit
				fi
				rm -rf /etc/apache2
				echo ""
				echo "apache2 removed!"
				exit
			else
				echo ""
				echo "Removal aborted!"
				exit
			fi
			;;
			2) exit;;
		esac
	done
fi
clear
if [[ "$OS" = 'debian' ]]; then
		apt-get update
		apt-get install apache2 -y
		openssl req -new -x509 -nodes -days 3650 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" -keyout sshoversslsrv.key -out sshoversslsrv.pem
		cp sshoversslsrv.pem /etc/ssl/certs/
		cp sshoversslsrv.key /etc/ssl/private/
		chmod 0600 /etc/ssl/private/sshoversslsrv.key
		rm -rf sshoversslsrv.pem sshoversslsrv.key
		a2enmod ssl proxy proxy_connect proxy_http alias
		a2ensite default-ssl

		if ! grep -q "\<SSLProtocol all -SSLv2\>" /etc/apache2/sites-available/default-ssl.conf; then
			sed -i '/\<SSLEngine on\>/a\    SSLProtocol all -SSLv2' /etc/apache2/sites-available/default-ssl.conf
		fi

		if ! grep -q "\SSLCertificateFile /etc/ssl/certs/sshoversslsrv.pem\>" /etc/apache2/sites-available/default-ssl.conf; then
			sed -i "s%SSLCertificateFile	/etc/ssl/certs/ssl-cert-snakeoil.pem%SSLCertificateFile /etc/ssl/certs/sshoversslsrv.pem%g" /etc/apache2/sites-available/default-ssl.conf
		fi

		if ! grep -q "\SSLCertificateKeyFile /etc/ssl/private/sshoversslsrv.key\>" /etc/apache2/sites-available/default-ssl.conf; then
			sed -i "s%SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key%SSLCertificateKeyFile /etc/ssl/private/sshoversslsrv.key%g" /etc/apache2/sites-available/default-ssl.conf
		fi

		if ! grep -q "\<Include /etc/apache2/proxytunnel/main.conf\>" /etc/apache2/sites-available/default-ssl.conf; then
			sed -i '/<\/VirtualHost\>/i  Include /etc/apache2/proxytunnel/main.conf' /etc/apache2/sites-available/default-ssl.conf
		fi

		if ! grep -q "\<Redirect\>" /etc/apache2/sites-available/000-default.conf; then
			sed -i '/\<ServerAdmin\>/i\ Redirect / https://google.com/' /etc/apache2/sites-available/000-default.conf
		fi

		mkdir -p /etc/apache2/proxytunnel/
		echo "ProxyRequests On
		AllowConnect 22
		<Proxy *>
				Order deny,allow
				Deny from all
		</Proxy>
		<Proxy 127.0.0.1>
				Order deny,allow
				Allow from all
		</Proxy>" >> /etc/apache2/proxytunnel/main.conf
		service apache2 restart
	echo ""
	echo "Finished!"
	echo "If you want to uninstall apache2, you simply need to run this script again!"
	echo ""
else
	echo "Wrong OS Exit!"
fi
