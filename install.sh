#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please use sudo to run this script."
  exit
fi

# Step 1: Install cpulimit tool
echo "Installing cpulimit..."
apt-get update -y
apt-get install -y cpulimit

# Step 2: Configure Linux Network Device Settings
echo "Configuring network device settings..."
tee -a /etc/sysctl.conf > /dev/null <<EOL
# Increase buffer sizes for better network performance
net.core.rmem_max=600000000
net.core.wmem_max=600000000
EOL

# Apply the new sysctl settings
echo "Applying sysctl settings..."
sysctl -p

# Step 3: Download the source code
echo "Downloading the source code..."
mkdir -p /opt
cd /opt
git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git
cd /opt/ceremonyclient

# Checkout the release branch
echo "Switching to the release branch..."
git checkout -b release origin/release

# Step 4: Start the node
echo "Starting the node..."
cd /opt/ceremonyclient/node
mkdir -p /opt/ceremonyclient/node/logs

# Create the run script
echo "Creating the run script..."
cat <<EOL > run.sh
nohup bash /opt/ceremonyclient/node/release_autorun.sh > /opt/ceremonyclient/node/logs/sys.log 2>&1 & disown
EOL

chmod +x run.sh 

# Run the node
echo "Running the node..."
./run.sh

# Step 5: Setup logrotate for log management
echo "Setting up logrotate..."
tee /etc/logrotate.d/ceremonyclient_node_logrotate > /dev/null <<EOL
/opt/ceremonyclient/node/logs/sys.log {
    size 500M
    create 0644 root root
    rotate 1
    compress
    delaycompress
    missingok
    notifempty
}
EOL

echo "Setup complete. Your node should be running and logs will be rotated automatically."

# Note: Configuration file modifications should be done after the node has started and created the config file.
# The following steps are for manual configuration after node setup.

# Step 6: Modify the configuration file manually if necessary
echo "Please modify the configuration file at /opt/ceremonyclient/node/.config/config.yml with the following settings:"
echo "To enable gRPC:"
echo "listenGrpcMultiaddr: \"/ip4/127.0.0.1/tcp/8337\""
echo "To enable stats collection:"
echo "engine:"
echo "  statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\""

# Step 7: Reboot the VPS
echo "Please reboot your VPS to apply the changes."
