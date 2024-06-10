#!/bin/bash

ROOT_DIR="/opt/ceremonyclient"
BAK_DIR="/data/quilibrium/bak"
CONFIG_FILE_DIR="${ROOT_DIR}/node/.config/config.yml"

if [ "$EUID" -ne 0 ]; then
  echo "Please use sudo to run this script."
  exit
fi

# Step 1: Install cpulimit tool
echo -e "\e[1m[1/7]Installing cpulimit...\e[0m"
apt-get update -y
apt-get install -y cpulimit
echo ""

# Step 2: Configure Linux Network Device Settings
echo -e "\e[1m[2/7]Configuring network device settings...\e[0m"
# Check if net.core.rmem_max or net.core.wmem_max settings already exist
if ! grep -q "^net\.core\.rmem_max=" /etc/sysctl.conf || ! grep -q "^net\.core\.wmem_max=" /etc/sysctl.conf; then
    # If they do not exist, add the following settings
    tee -a /etc/sysctl.conf > /dev/null <<EOL
# Increase buffer sizes for better network performance
net.core.rmem_max=600000000
net.core.wmem_max=600000000
EOL
fi

# Apply the new sysctl settings
echo "Applying sysctl settings..."
sysctl -p
echo ""


# Step 3: Download the source code
echo -e "\e[1m[3/7]Downloading the source code...\e[0m"
mkdir -p /opt && cd /opt
git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git

# Checkout the release branch
echo "Switching to the release branch..."
cd ${ROOT_DIR}
git checkout -b release origin/release
echo ""

# Step 4: Setup logrotate for log management
echo -e "\e[1m[4/7]Setting up logrotate...\e[0m"
tee /etc/logrotate.d/ceremonyclient_node_logrotate > /dev/null <<EOL
${ROOT_DIR}/node/logs/sys.log {
    size 500M
    create 0644 root root
    rotate 1
    compress
    delaycompress
    missingok
    notifempty
}
EOL
echo ""

# Step 5: Start the node
echo -e "\e[1m[5/7]Starting the node...\e[0m"
echo "Create the service unit file..."
# Create the service unit file
tee /etc/systemd/system/ceremonyclient.service > /dev/null <<EOF
[Unit]
Description=Ceremony Client Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/ceremonyclient/node/release_autorun.sh

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl enable ceremonyclient
sudo systemctl start ceremonyclient

sleep 20
# Check if the service is running
sudo systemctl status ceremonyclient
echo "Setup complete. Your node should be running and logs will be rotated automatically."
echo ""

# Note: Configuration file modifications should be done after the node has started and created the config file.
# The following steps are for manual configuration after node setup.

# Step 6: Modify the configuration file manually if necessary
echo -e "\e[1m[6/7]Please modify the configuration file at ${ROOT_DIR}/node/.config/config.yml with the following settings\e[0m"
echo "To enable gRPC:"
new_listenGrpcMultiaddr="/ip4/127.0.0.1/tcp/8337"
echo "listenGrpcMultiaddr: \"${new_listenGrpcMultiaddr}\""
sed -i.bak "s|listenGrpcMultiaddr:.*|listenGrpcMultiaddr: \"$new_listenGrpcMultiaddr\"|" "$CONFIG_FILE_DIR"
echo ""

echo "To enable stats collection:"
new_statsMultiaddr="/dns/stats.quilibrium.com/tcp/443"
echo "engine:"
echo "  statsMultiaddr: \"${new_statsMultiaddr}\""
sed -i -e "/statsMultiaddr:/s|statsMultiaddr:.*|statsMultiaddr: \"$new_statsMultiaddr\"|" "$CONFIG_FILE_DIR"
echo ""

# bak config
mkdir -p ${BAK_DIR}
cp -rf ${ROOT_DIR}/node/.config ${BAK_DIR}

# Step 7: Reboot the VPS. Increase buffer sizes for better network performance 
echo -e "\e[1;34m[7/7] Please < reboot > your VPS to apply the changes.\e[0m"
