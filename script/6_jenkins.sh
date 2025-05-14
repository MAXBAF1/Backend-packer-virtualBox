#!/bin/bash
echo "[6.1]Installing jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo gpg --dearmor -o /usr/share/keyrings/jenkins.gpg
echo "deb [signed-by=/usr/share/keyrings/jenkins.gpg] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins 
echo "[6.2]Configuring jenkins..."
sudo rm -rf /var/lib/jenkins
sudo unzip -q /tmp/resources/jenkins_home_backup.zip -d /
sudo chown -R jenkins:jenkins /var/lib/jenkins
echo "[6.3]Setting up jenkins variables..."
sudo sed -i 's/HTTP_PORT=8080/HTTP_PORT=8081/' /etc/default/jenkins
sudo sed -i '/^JENKINS_ARGS=/ s/"$/ --jenkins-url=\/jenkins\/"/' /etc/default/jenkins
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl stop jenkins
sudo sed -i 's|^Environment="JENKINS_PORT=.*"|Environment="JENKINS_PORT=8081"|' /lib/systemd/system/jenkins.service
sudo sed -i 's|^#Environment="JENKINS_PREFIX=.*"|Environment="JENKINS_PREFIX=/jenkins"|' /lib/systemd/system/jenkins.service
sudo usermod -aG docker jenkins
sudo systemctl daemon-reload
sudo systemctl start jenkins
echo "[6.4]Setting up repo directory..."
sudo mkdir -p /opt/around_core/repo
sudo chown -R jenkins:jenkins /opt/around_core/repo
sudo chmod -R 755 /opt/around_core/repo