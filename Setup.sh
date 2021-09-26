#!Setup Environment
sudo apt update
sudo apt install python-pip
sudo pip install httpbin
sudo pip install guicorn
sudo apt install nginx
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-cloudflare
#!Setup cloudflared
echo 'deb http://pkg.cloudflare.com/ xenial main' |
sudo tee /etc/apt/sources.list.d/cloudflare-main.list
curl -C - https://pkg.cloudflare.com/pubkey.gpg | sudo apt-key add -
sudo apt-get update
#!Configure wildcard certificate with certbot 
mkdir /root/.secrets/
touch /root/.secrets/cloudflare.ini
echo $'dns_cloudflare_email = youremail@example.com\ndns_cloudflare_api_key = yourapikey'
sudo chmod 0700 /ubuntu/.secrets/
sudo chmod 0400 /ubuntu/.secrets/cloudflare.ini
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/cloudflare.ini -d example.com,*.example.com --preferred-challenges dns-01
#!Configure cloudflare argo tunnel
cloudflared tunnel login
cloudflared tunnel create cf-chadlau-tunnel-2
echo $'url: https://cf3.chadlau.site:443\ntunnel: <Tunnel-UUID>\ncredentials-file: /ubuntu/.cloudflared/<Tunnel-UUID>.json' >> /home/ubuntu/.cloudflared/config.yml
cloudflared tunnel route dns cf-chadlau-tunnel-2 cf3.chadlau.site3
cloudflared tunnel run cf-chadlau-tunnel-2
#!Configure Nginx and site
sudo cat <<EOF > /etc/nginx/sites-enabled/httpbin.txt
server
{
  listen 443 ssl;
  listen [::]:443 ssl;
  server_name cf.chadlau.site;

  ssl on;
    ssl_certificate /etc/letsencrypt/live/chadlau.site/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/chadlau.site/privkey.pem; # managed by Certbot

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  location /
  {
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://0.0.0.0:8000/;
  }

}
EOF
#!Switch on WSGI and Nginx
sudo gunicorn -b 8000 httpbin:app
sudo systemctl restart nginx