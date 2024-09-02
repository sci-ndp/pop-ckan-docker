#!/bin/sh

# Welcome message
echo "*******************************************"
echo "*  Welcome to POP Setup                    *"
echo "*  Preparing your environment              *"
echo "*******************************************"

# Function to check and install Docker
install_docker() {
    if ! command -v docker >/dev/null 2>&1
    then
        echo "Docker not found. Installing Docker..."
        sudo apt-get update
        sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "Docker is already installed. Skipping installation."
    fi
}

# Function to check and install Docker Compose
install_docker_compose() {
    if ! command -v docker-compose >/dev/null 2>&1
    then
        echo "Docker Compose not found. Installing Docker Compose..."
        sudo apt-get update
        sudo apt-get install -y docker-compose
    else
        echo "Docker Compose is already installed. Skipping installation."
    fi
}

# Function to check and install Git
install_git() {
    if ! command -v git >/dev/null 2>&1
    then
        echo "Git not found. Installing Git..."
        sudo apt-get update
        sudo apt-get install -y git
    else
        echo "Git is already installed. Skipping installation."
    fi
}

# Ensure user can run Docker and Git commands
ensure_user_permissions() {
    if ! groups | grep -q "\bdocker\b"; then
        echo "Adding user to the docker group..."
        sudo usermod -aG docker $USER
        echo "You need to log out and back in again to apply Docker group changes."
    else
        echo "User is already in the docker group. Skipping permission setup."
    fi
}

# Install necessary tools
install_docker
install_docker_compose
install_git
ensure_user_permissions

# Clone the repository
echo "Cloning the repository..."
git clone https://github.com/sci-ndp/pop-ckan-docker.git pop

# Navigate into the directory
cd pop

# Copy .env.example to .env
echo "Setting up the environment file..."
cp .env.example .env

# Ask the user for their CKAN system admin name and password
echo "Enter your CKAN_SYSADMIN_NAME:"
read ckan_name
echo "Enter your CKAN_SYSADMIN_PASSWORD:"
read ckan_password

# Get the IP address of the machine
machine_ip=$(hostname -I | awk '{print $1}')

# Replace the CKAN_SYSADMIN_NAME, CKAN_SYSADMIN_PASSWORD, and CKAN_SITE_URL in the .env file
sed -i "s/^CKAN_SYSADMIN_NAME=.*/CKAN_SYSADMIN_NAME=${ckan_name}/" .env
sed -i "s/^CKAN_SYSADMIN_PASSWORD=.*/CKAN_SYSADMIN_PASSWORD=${ckan_password}/" .env
sed -i "s|^CKAN_SITE_URL=.*|CKAN_SITE_URL=http://${machine_ip}:8443|" .env

# Run Docker Compose
echo "Building and starting the Docker containers..."
docker-compose up -d --build

# Wait for CKAN to be healthy
echo "Waiting for CKAN to be healthy..."
while [ "$(docker inspect -f '{{.State.Health.Status}}' pop-ckan-1)" != "healthy" ]; do
    sleep 5
done

# Access the CKAN container
ckan_container=$(docker ps -qf "name=pop-ckan-1")

# Find the correct location of the ckan.ini or production.ini file
ckan_ini_path=$(docker exec $ckan_container find / -name '*.ini' 2>/dev/null | grep -E '(ckan|production).ini' | head -n 1)

# Modify ckan.ini to disable user creation via web
if [ -n "$ckan_ini_path" ]; then
    echo "Modifying $ckan_ini_path to disable user creation via web..."
    docker exec $ckan_container sed -i "s/ckan.auth.create_user_via_web = true/ckan.auth.create_user_via_web = false/" $ckan_ini_path
else
    echo "Error: CKAN configuration file not found."
    exit 1
fi

# Create an API token for the CKAN sysadmin user
api_key=$(docker exec $ckan_container ckan -c $ckan_ini_path user token add $ckan_name api_key_for_admin | tail -n 1 | tr -d '\r')

# Restart the CKAN container to apply the changes
echo "Restarting the CKAN container to apply changes..."
docker restart $ckan_container

# Wait for CKAN to be healthy again after the restart
echo "Waiting for CKAN to be healthy again..."
while [ "$(docker inspect -f '{{.State.Health.Status}}' pop-ckan-1)" != "healthy" ]; do
    sleep 5
done

# Create a .txt file with the user details
info_file="ckan_user_info.txt"
echo "Creating $info_file with user details..."
echo "CKAN URL: http://${machine_ip}:8443" > $info_file
echo "CKAN_SYSADMIN_NAME: ${ckan_name}" >> $info_file
echo "CKAN_SYSADMIN_PASSWORD: ${ckan_password}" >> $info_file
echo "CKAN API Key: ${api_key}" >> $info_file

# Display the user details
echo "Setup complete! POP CKAN is now running at http://${machine_ip}:8443"
echo "User details have been saved to $info_file"
cat $info_file

