#!/bin/bash

clear
echo "----------------------------------------------------------------------------"
echo "This script will configure your PromptDesk OS installation"
echo "----------------------------------------------------------------------------"
echo ""
echo "Please be sure you have the following information to proceed:"
echo "  1. Docker Compose installed"
echo "  2. OpenAI API Key (can change to different LLM provider later)"
echo "  3. (OPTIONAL) OpenSSL installed"
echo "  4. (OPTIONAL) Domain/Subdomain pointing to your server's IP address"
echo "  5. (OPTIONAL) Email address for your SSL certificate install"
echo ""
echo "This process will take approximately 5 minutes"
echo "----------------------------------------------------------------------------"
echo "When you are ready to proceed, press Enter"
echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"

if [ -d ./promptdesk ]; then
    rm -rf ./promptdesk
fi

#check if docker compose or docker-compose is installed
if ! [ -x "$(command -v docker compose)" ]; then
    echo 'Error: docker compose is not installed. Please install docker compose and try again.' >&2
    echo 'You can find the installation guide here: https://docs.docker.com/compose/install/' >&2
    exit 1
fi

#check if openssl is installed
if ! [ -x "$(command -v openssl)" ]; then
    echo 'Error: openssl is not installed. Please install openssl and try again.' >&2
    echo 'You can find the installation guide here: https://www.openssl.org/source/' >&2
    exit 1
fi

#check if files can be written to the current directory
if [ -w . ]; then
    :
else
    echo "This directory is not writable. Please run this script in a directory where you have write permissions"
    exit 1
fi

read -r proceed

mkdir -p promptdesk && cd promptdesk &&
mkdir -p nginx

#get option of if they want to: 1) setup a domain name with ssl or 2) just keep existing setup
echo "Do you want to setup a domain name with SSL? (y/n)"
read -r setup_domain

if [ "$setup_domain" = "y" ] || [ "$setup_domain" = "Y" ]; then

    if [ ! -f ./certbot/conf/live/$domain_name/fullchain.pem ]; then

        echo "Please enter your domain name (e.g. example.com, subdomain.example.com)"
        read -r domain_name
        echo "Please enter your email address for SSL certificate install"
        read -r email_address

        cp /Users/justin/Documents/dev/promptdesk/quickstart/nginx/certbot-setup.conf ./nginx/default.conf
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sed -i "s/\2/$domain_name/g" ./nginx/default.conf
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' -e "s/\${DOMAIN}/$domain_name/g" ./nginx/default.conf
        fi

        cp /Users/justin/Documents/dev/promptdesk/quickstart/docker-compose-certbot-setup.yml ./docker-compose-certbot-setup.yml

        if [ ! -f ./certbot/conf/ssl-dhparams.pem ]; then
            curl -L --create-dirs -o ./certbot/conf/options-ssl-nginx.conf https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
            openssl dhparam -out ./certbot/conf/ssl-dhparams.pem 2048
        fi

        docker compose -f docker-compose-certbot-setup.yml run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d  $domain_name --agree-tos -m $email_address
        docker compose -f docker-compose-certbot-setup.yml run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d  $domain_name --agree-tos -m $email_address

        cp /Users/justin/Documents/dev/promptdesk/quickstart/nginx/default-ssl.conf ./nginx/default.conf
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sed -i "s/\2/$domain_name/g" ./nginx/default.conf
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' -e "s/\${DOMAIN}/$domain_name/g" ./nginx/default.conf
        fi
        cp /Users/justin/Documents/dev/promptdesk/quickstart/docker-compose-secure.yml ./docker-compose.yml

    else
        echo "Setup already exists. If you would like to reconfigure, please remove the ./promptdesk directory and run this script again."
    fi

fi

if [ "setup_domain" = "n" ] || [ "setup_domain" = "N" ]; then
    cp /Users/justin/Documents/dev/promptdesk/quickstart/nginx/default.conf ./nginx/default.conf
    cp /Users/justin/Documents/dev/promptdesk/quickstart/docker-compose.yml ./docker-compose.yml
fi

docker compose up