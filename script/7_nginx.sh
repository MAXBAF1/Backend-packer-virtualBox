#!/bin/bash
echo "[7.1]Installing nginx..."
sudo apt-get install -y nginx
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx
echo "[7.2]Configuring Nginx..."
sudo rm -rf /etc/nginx/sites-enabled/default
sudo rm -rf /etc/nginx/sites-available/default
sudo cp /tmp/resources/around.conf /etc/nginx/sites-enabled
sudo nginx -t 
sudo systemctl restart nginx