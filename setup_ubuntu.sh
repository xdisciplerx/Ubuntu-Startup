#!/bin/bash

echo "Ubuntu Server Setup & Security Script"
echo "-------------------------------------"

# Function to update and upgrade the system
update_system() {
    echo -e "\n[INFO] Updating package lists and upgrading installed packages..."
    apt update && apt upgrade -y
    apt install ufw fail2ban unattended-upgrades -y
    echo "[DONE] System updated and security tools installed."
}

# Function to create a new sudo user
create_sudo_user() {
    echo -e "\n[INFO] Creating a new user with sudo privileges."
    read -p "Enter the new username: " newuser
    adduser $newuser
    usermod -aG sudo $newuser
    echo "[DONE] User '$newuser' created and added to the sudo group."
}

# Function to configure the firewall (UFW)
setup_ufw() {
    echo -e "\n[INFO] Configuring UFW..."
    ufw allow OpenSSH
    ufw enable
    ufw status
    echo "[DONE] UFW configured."
}

# Function to configure SSH security
secure_ssh() {
    echo -e "\n[INFO] Hardening SSH security..."
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "[DONE] SSH security configured."
}

# Function to mount a CIFS share
mount_cifs_share() {
    echo -e "\n[INFO] Setting up a CIFS (Windows/Samba) network share..."
    read -p "Enter the network share path (e.g., //192.168.1.100/shared): " share_path
    read -p "Enter the local mount point (e.g., /mnt/backup): " mount_point
    read -p "Enter the share username: " share_user
    read -s -p "Enter the share password: " share_pass
    echo

    mkdir -p $mount_point
    cred_file="/etc/.smbcredentials"
    echo "username=$share_user" > $cred_file
    echo "password=$share_pass" >> $cred_file
    chmod 600 $cred_file

    echo "$share_path $mount_point cifs credentials=$cred_file,iocharset=utf8,sec=ntlm 0 0" >> /etc/fstab
    mount -a
    echo "[DONE] CIFS share mounted."
}

# Function to set up automatic backups to a CIFS share
setup_cifs_backup() {
    echo -e "\n[INFO] Setting up automatic backups to a CIFS share..."
    
    read -p "Enter the source directory to back up (e.g., /home): " source_dir
    read -p "Enter the destination mount point (e.g., /mnt/backup): " backup_mount

    if grep -qs "$backup_mount" /proc/mounts; then
        echo "[INFO] CIFS share is already mounted."
    else
        echo "[ERROR] CIFS share is not mounted! Run option 9 to mount it first."
        return
    fi

    backup_script="/usr/local/bin/cifs_backup.sh"
    echo "#!/bin/bash" > $backup_script
    echo "rsync -a --delete $source_dir $backup_mount" >> $backup_script
    chmod +x $backup_script

    echo "[INFO] Setting up a daily backup cron job..."
    cron_job="0 3 * * * root /usr/local/bin/cifs_backup.sh"
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

    echo "[DONE] Automatic daily backups configured."
}

# Function to install and configure Plex, Radarr, Sonarr, Prowlarr
install_media_server() {
    echo -e "\n[INFO] Installing Plex Media Server..."
    curl https://downloads.plex.tv/plex-keys/PlexSign.key | sudo apt-key add -
    echo "deb https://downloads.plex.tv/repo/deb public main" | sudo tee /etc/apt/sources.list.d/plexmediaserver.list
    apt update
    apt install -y plexmediaserver
    systemctl enable plexmediaserver
    systemctl start plexmediaserver
    echo "[DONE] Plex installed."

    echo -e "\n[INFO] Installing Radarr..."
    wget -qO /tmp/radarr.tar.gz https://github.com/Radarr/Radarr/releases/latest/download/Radarr.master.ubuntu.tar.gz
    mkdir -p /opt/radarr
    tar -xvzf /tmp/radarr.tar.gz -C /opt/radarr
    rm /tmp/radarr.tar.gz
    ln -s /opt/radarr/Radarr /usr/local/bin/radarr
    systemctl daemon-reload
    systemctl enable radarr
    systemctl start radarr
    echo "[DONE] Radarr installed."

    echo -e "\n[INFO] Installing Sonarr..."
    wget -qO /tmp/sonarr.tar.gz https://github.com/Sonarr/Sonarr/releases/latest/download/Sonarr.master.ubuntu.tar.gz
    mkdir -p /opt/sonarr
    tar -xvzf /tmp/sonarr.tar.gz -C /opt/sonarr
    rm /tmp/sonarr.tar.gz
    ln -s /opt/sonarr/Sonarr /usr/local/bin/sonarr
    systemctl daemon-reload
    systemctl enable sonarr
    systemctl start sonarr
    echo "[DONE] Sonarr installed."

    echo -e "\n[INFO] Installing Prowlarr..."
    wget -qO /tmp/prowlarr.tar.gz https://github.com/Prowlarr/Prowlarr/releases/latest/download/Prowlarr.master.ubuntu.tar.gz
    mkdir -p /opt/prowlarr
    tar -xvzf /tmp/prowlarr.tar.gz -C /opt/prowlarr
    rm /tmp/prowlarr.tar.gz
    ln -s /opt/prowlarr/Prowlarr /usr/local/bin/prowlarr
    systemctl daemon-reload
    systemctl enable prowlarr
    systemctl start prowlarr
    echo "[DONE] Prowlarr installed."
}

# Display the main menu
while true; do
    echo -e "\nChoose an option:"
    echo "1) Update & upgrade system"
    echo "2) Create a sudo user"
    echo "3) Configure UFW firewall"
    echo "4) Secure SSH"
    echo "5) Install Plex, Radarr, Sonarr, Prowlarr"
    echo "6) Mount CIFS share"
    echo "7) Set up automatic backups to CIFS share"
    echo "8) Exit"

    read -p "Enter your choice (1-8): " choice
    case $choice in
        1) update_system ;;
        2) create_sudo_user ;;
        3) setup_ufw ;;
        4) secure_ssh ;;
        5) install_media_server ;;
        6) mount_cifs_share ;;
        7) setup_cifs_backup ;;
        8) echo "[INFO] Exiting."; break ;;
        *) echo "[ERROR] Invalid option." ;;
    esac
done
