#!/bin/bash
echo "==> Disabling apt.daily.service & apt-daily-upgrade.service"
systemctl stop apt-daily.timer apt-daily-upgrade.timer
systemctl mask apt-daily.timer apt-daily-upgrade.timer
systemctl stop apt-daily.service apt-daily-upgrade.service
systemctl mask apt-daily.service apt-daily-upgrade.service
systemctl daemon-reload
# install packages and upgrade
echo "==> Updating list of repositories"
apt-get -y update
if [[ $UPDATE =~ true || $UPDATE =~ 1 || $UPDATE =~ yes ]]; then
    apt-get -y dist-upgrade
fi
apt-get -y install --no-install-recommends build-essential linux-headers-generic
apt-get -y install --no-install-recommends ssh nfs-common vim curl git
# Disable the release upgrader
#echo "==> Disabling the release upgrader"
#sed -i 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades
echo "==> Removing the release upgrader"
apt-get -y purge ubuntu-release-upgrader-core
rm -rf /var/lib/ubuntu-release-upgrader
rm -rf /var/lib/update-manager
# Clean up the apt cache
apt-get -y autoremove --purge
apt-get -y clean
# Remove grub timeout and splash screen
sed -i -e '/^GRUB_TIMEOUT=/aGRUB_RECORDFAIL_TIMEOUT=0' \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet nosplash"/' \
    /etc/default/grub
update-grub
# SSH tweaks
echo "UseDNS no" >> /etc/ssh/sshd_config
# User tweaks
echo "${SSH_USERNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$SSH_USERNAME
echo "==> Starting installation of all components"
echo "==> Searching for installation scripts"
find / -name '1_update.sh' 2>/dev/null || echo "1_update.sh not found anywhere"
find /tmp -type d 2>/dev/null | grep script || echo "No script directory found in /tmp"
ls -la /tmp || echo "Empty /tmp directory"
echo "==> Creating backup of scripts"
mkdir -p /root/script-backup
if [ -d "/tmp/script" ]; then
    cp -r /tmp/script/* /root/script-backup/
    chmod +x /root/script-backup/*.sh
    echo "Scripts copied to backup location"
else
    echo "ERROR: /tmp/script directory not found!"
fi
export DEBIAN_FRONTEND=noninteractive
echo "==> Executing installation scripts"
for script in 1_update.sh 2_java.sh 3_maven.sh 4_docker.sh 5_env.sh 6_jenkins.sh 7_nginx.sh; do
    if [ -f "/root/script-backup/$script" ]; then
        echo "Running $script..."
        bash /root/script-backup/$script
        echo "$script completed"
    else
        echo "ERROR: Script $script not found in backup location"
    fi
done
echo "==> All installation scripts completed"
# reboot
echo "====> Shutting down the SSHD service and rebooting..."
systemctl stop sshd.service
nohup shutdown -r now < /dev/null > /dev/null 2>&1 &
sleep 120
exit 0