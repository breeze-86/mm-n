#!/bin/bash

ROOT_DIR="/opt/ceremonyclient"
BAK_DIR="/data/quilibrium/bak"
CONFIG_FILE_DIR="${ROOT_DIR}/node/.config/config.yml"

if [ "$EUID" -ne 0 ]; then
  echo "Please use sudo to run this script."
  exit
fi

# Step 1: Install cpulimit tool
echo "[1/7]Installing cpulimit..."
apt-get update -y
apt-get install -y cpulimit
echo ""

# Step 2: Configure Linux Network Device Settings
echo "[2/7]Configuring network device settings..."
tee -a /etc/sysctl.conf > /dev/null <<EOL
# Increase buffer sizes for better network performance
net.core.rmem_max=600000000
net.core.wmem_max=600000000
EOL

# Apply the new sysctl settings
echo "Applying sysctl settings..."
sysctl -p
echo ""


# Step 3: Download the source code
echo "[4/7]Downloading the source code..."
mkdir -p /opt && cd /opt
git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git

# Checkout the release branch
echo "Switching to the release branch..."
cd ${ROOT_DIR}
git checkout -b release origin/release
echo ""

# Step 4: Setup logrotate for log management
echo "[3/7]Setting up logrotate..."
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
echo "[5/7]Starting the node..."
cd ${ROOT_DIR}/node
mkdir -p ${ROOT_DIR}/node/logs

# Create the run script
echo "Creating the run script..."
cat <<EOL > run.sh
nohup bash ${ROOT_DIR}/node/release_autorun.sh > ${ROOT_DIR}/node/logs/sys.log 2>&1 & disown
EOL

chmod +x run.sh 

# Run the node
echo "Running the node..."
./run.sh
echo ""

echo "Setup complete. Your node should be running and logs will be rotated automatically."

# Note: Configuration file modifications should be done after the node has started and created the config file.
# The following steps are for manual configuration after node setup.

# Step 6: Modify the configuration file manually if necessary
sleep 20
echo "[6/7]Please modify the configuration file at ${ROOT_DIR}/node/.config/config.yml with the following settings:"
echo "To enable gRPC:"
echo "listenGrpcMultiaddr: \"/ip4/127.0.0.1/tcp/8337\""
new_listenGrpcMultiaddr="/ip4/127.0.0.1/tcp/8337"
sed -i.bak "s|listenGrpcMultiaddr:.*|listenGrpcMultiaddr: \"${new_listenGrpcMultiaddr}\"|" "${CONFIG_FILE_DIR}"
echo ""

echo "To enable stats collection:"
echo "engine:"
echo "  statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\""
new_statsMultiaddr="/dns/stats.quilibrium.com/tcp/443"
sed -i -e "/statsMultiaddr:/s|statsMultiaddr:.*|statsMultiaddr: \"{$new_statsMultiaddr}\"|" "${CONFIG_FILE_DIR}"
echo ""

# bak config
mkdir -p ${BAK_DIR}
cp -rf ${ROOT_DIR}/node/.config ${BAK_DIR}

# Step 7: Reboot the VPS
echo "[7/7]Please reboot your VPS to apply the changes."
