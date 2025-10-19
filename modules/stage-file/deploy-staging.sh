#!/bin/bash

# ============================================================================
# Fiifi Pet Adoption Auto Discovery Project - Docker Staging Environment Script
# ============================================================================
# This script manages the staging environment deployment with Docker containers
# and application deployment automation
# Author: fiifiquaison1
# Date: 2025-10-19
# ============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="fiifi-pet-adoption-stage"
AWS_REGION="eu-west-3"
DOMAIN_NAME="fiifiquaison.space"
DOCKER_IMAGE_NAME="fiifi-pet-adoption-staging"
DOCKER_CONTAINER_NAME="staging-terraform"
DOCKER_NETWORK="pet-adoption-network"
MAIN_TERRAFORM_DIR="$(dirname $(dirname $SCRIPT_DIR))/vault-jenkins"

# Staging specific configuration
STAGING_IMAGE_NAME="petclinicapps"
STAGING_CONTAINER_NAME="stage-petclinic"
STAGING_PORT="8080"
NEXUS_REGISTRY_PORT="8085"
NEW_RELIC_REGION="EU"

# Function definitions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}============================================================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}============================================================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if AWS credentials are available
    if [ -z "$AWS_ACCESS_KEY_ID" ] && [ -z "$AWS_PROFILE" ] && [ ! -f "$HOME/.aws/credentials" ]; then
        print_error "AWS credentials not found. Please set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or configure AWS CLI."
        exit 1
    fi
    
    # Check if main Terraform directory exists
    if [ ! -d "$MAIN_TERRAFORM_DIR" ]; then
        print_error "Main Terraform directory not found at $MAIN_TERRAFORM_DIR"
        exit 1
    fi
    
    # Check if VPC module exists
    if [ ! -d "$MAIN_TERRAFORM_DIR/modules/vpc" ]; then
        print_error "VPC module not found at $MAIN_TERRAFORM_DIR/modules/vpc"
        exit 1
    fi
    
    # Check if userdata scripts exist
    if [ ! -f "$MAIN_TERRAFORM_DIR/jenkins-userdata-optimized.sh" ]; then
        print_error "Jenkins userdata script not found at $MAIN_TERRAFORM_DIR/jenkins-userdata-optimized.sh"
        exit 1
    fi
    
    if [ ! -f "$MAIN_TERRAFORM_DIR/vault-userdata-optimized.sh" ]; then
        print_error "Vault userdata script not found at $MAIN_TERRAFORM_DIR/vault-userdata-optimized.sh"
        exit 1
    fi
    
    print_success "All prerequisites satisfied!"
}

# Function to create Docker network
create_docker_network() {
    print_status "Creating Docker network..."
    if ! docker network ls | grep -q "$DOCKER_NETWORK"; then
        docker network create "$DOCKER_NETWORK"
        print_success "Docker network '$DOCKER_NETWORK' created!"
    else
        print_status "Docker network '$DOCKER_NETWORK' already exists."
    fi
}

# Function to build Docker image
build_docker_image() {
    print_header "Building Docker Image"
    
    print_status "Building Docker image: $DOCKER_IMAGE_NAME"
    docker build -t "$DOCKER_IMAGE_NAME:latest" .
    
    print_success "Docker image built successfully!"
}

# Function to run Docker container with Terraform commands
run_terraform_container() {
    local command="$1"
    shift
    local extra_args="$@"
    
    # Prepare AWS credentials volume mounts
    local aws_mounts=""
    if [ -f "$HOME/.aws/credentials" ]; then
        aws_mounts="-v $HOME/.aws:/home/terraform/.aws:ro"
    fi
    
    # Prepare environment variables for AWS
    local aws_env=""
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        aws_env="-e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
    fi
    if [ -n "$AWS_SESSION_TOKEN" ]; then
        aws_env="$aws_env -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN"
    fi
    if [ -n "$AWS_PROFILE" ]; then
        aws_env="$aws_env -e AWS_PROFILE=$AWS_PROFILE"
    fi
    
    # Run the container with main Terraform directory mounted
    docker run --rm -it \
        --name "$DOCKER_CONTAINER_NAME" \
        --network "$DOCKER_NETWORK" \
        -v "$MAIN_TERRAFORM_DIR:/workspace" \
        $aws_mounts \
        $aws_env \
        -e AWS_DEFAULT_REGION="$AWS_REGION" \
        -e TF_VAR_aws_region="$AWS_REGION" \
        -e TF_VAR_environment="staging" \
        "$DOCKER_IMAGE_NAME:latest" \
        bash -c "cd /workspace && $command" $extra_args
}

# Function to deploy staging infrastructure using main Terraform
deploy_staging_infrastructure() {
    print_header "Deploying Staging Infrastructure"
    
    print_status "Running Terraform deployment for staging environment..."
    
    # Create staging-specific terraform.tfvars
    run_terraform_container "cat > staging.tfvars << 'EOF'
environment = \"staging\"
domain_name = \"$DOMAIN_NAME\"
aws_region = \"$AWS_REGION\"
vpc_cidr = \"10.1.0.0/16\"
public_subnet_cidrs = [\"10.1.1.0/24\", \"10.1.2.0/24\"]
private_subnet_cidrs = [\"10.1.3.0/24\", \"10.1.4.0/24\"]
availability_zones = [\"eu-west-3a\", \"eu-west-3b\"]
EOF"
    
    # Initialize, plan and apply
    run_terraform_container "terraform init -upgrade"
    run_terraform_container "terraform validate"
    run_terraform_container "terraform plan -var-file=staging.tfvars -out=staging.tfplan"
    run_terraform_container "terraform apply staging.tfplan"
    
    print_success "Staging infrastructure deployed successfully!"
}

# Function to destroy staging infrastructure
destroy_staging_infrastructure() {
    print_header "Destroying Staging Infrastructure"
    
    print_warning "This will destroy ALL staging infrastructure!"
    read -p "Are you sure you want to continue? (yes/no): " -r
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        run_terraform_container "terraform destroy -var-file=staging.tfvars -auto-approve"
        print_success "Staging infrastructure destroyed!"
    else
        print_status "Destroy operation cancelled."
    fi
}

# Function to show staging infrastructure status
show_staging_status() {
    print_header "Staging Infrastructure Status"
    
    run_terraform_container "
        if [ -f terraform.tfstate ] && [ -s terraform.tfstate ]; then
            echo 'Current Terraform state:'
            terraform show -no-color | head -20
            echo ''
            echo 'Infrastructure outputs:'
            terraform output -no-color
        else
            echo 'No Terraform state found. Infrastructure may not be deployed.'
        fi
    "
}

# Function to show staging URLs
show_staging_urls() {
    print_header "Staging Access URLs"
    
    run_terraform_container "
        if [ -f terraform.tfstate ] && [ -s terraform.tfstate ]; then
            JENKINS_URL=\$(terraform output -raw jenkins_url 2>/dev/null || echo 'Not available')
            VAULT_URL=\$(terraform output -raw vault_url 2>/dev/null || echo 'Not available')
            JENKINS_IP=\$(terraform output -raw jenkins_public_ip 2>/dev/null || echo 'Not available')
            
            echo \"Jenkins URL: \$JENKINS_URL\"
            echo \"Vault URL: \$VAULT_URL\"
            echo \"Jenkins IP: \$JENKINS_IP\"
            echo \"Pet Clinic App: http://\$JENKINS_IP:$STAGING_PORT (when deployed)\"
            echo \"\"
            echo \"Note: It may take 5-10 minutes for services to be fully available after deployment.\"
        else
            echo 'Infrastructure not deployed. Run deploy command first.'
        fi
    "
}

# Function to create staging application deployment script
create_staging_app_script() {
    print_header "Creating Staging Application Deployment Script"
    
    local nexus_ip="$1"
    local nr_key="$2"
    local nr_acct_id="$3"
    
    if [ -z "$nexus_ip" ] || [ -z "$nr_key" ] || [ -z "$nr_acct_id" ]; then
        print_error "Missing required parameters: nexus_ip, new_relic_key, new_relic_account_id"
        print_status "Usage: create_app_script <nexus_ip> <new_relic_key> <new_relic_account_id>"
        return 1
    fi
    
    cat > "${SCRIPT_DIR}/staging-app-deploy.sh" << 'EOF'
#!/bin/bash

# ============================================================================
# Fiifi Pet Adoption Auto Discovery - Staging Application Deployment Script
# ============================================================================
# This script sets up Docker and deploys the Pet Clinic application in staging
# ============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
NEXUS_IP="NEXUS_IP_PLACEHOLDER"
NEW_RELIC_KEY="NR_KEY_PLACEHOLDER"
NEW_RELIC_ACCOUNT_ID="NR_ACCT_ID_PLACEHOLDER"
IMAGE_NAME="${NEXUS_IP}:8085/petclinicapps"
CONTAINER_NAME="stage-petclinic"
NEXUS_REGISTRY="${NEXUS_IP}:8085"

# Function to update system
update_system() {
    print_status "Updating system packages..."
    sudo yum update -y
    sudo yum upgrade -y
    print_success "System updated successfully!"
}

# Function to install Docker
install_docker() {
    print_status "Installing Docker and dependencies..."
    
    # Install Docker dependencies
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install docker-ce -y
    
    # Configure Docker daemon for insecure registry
    print_status "Configuring Docker daemon..."
    sudo tee /etc/docker/daemon.json > /dev/null << EOT
{
    "insecure-registries": ["${NEXUS_REGISTRY}"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOT
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add ec2-user to docker group
    sudo usermod -aG docker ec2-user
    
    # Restart Docker to apply configuration
    sudo systemctl restart docker
    
    print_success "Docker installed and configured successfully!"
}

# Function to create application management script
create_app_management_script() {
    print_status "Creating application management script..."
    
    sudo mkdir -p /home/ec2-user/scripts
    
    cat << 'SCRIPT_EOF' | sudo tee /home/ec2-user/scripts/manage-petclinic.sh > /dev/null
#!/bin/bash

set -e

# Configuration
IMAGE_NAME="IMAGE_NAME_PLACEHOLDER"
CONTAINER_NAME="CONTAINER_NAME_PLACEHOLDER"
NEXUS_REGISTRY="NEXUS_REGISTRY_PLACEHOLDER"
APP_PORT="8080"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to authenticate with Nexus registry
authenticate_docker() {
    print_status "Authenticating with Nexus registry..."
    echo "admin123" | docker login --username admin --password-stdin $NEXUS_REGISTRY
    if [ $? -eq 0 ]; then
        print_success "Successfully authenticated with Nexus registry"
        return 0
    else
        print_error "Failed to authenticate with Nexus registry"
        return 1
    fi
}

# Function to check for image updates
check_for_updates() {
    print_status "Checking for image updates..."
    docker pull $IMAGE_NAME 2>&1 | grep -q "Status: Image is up to date" && return 1 || return 0
}

# Function to deploy/update container
deploy_container() {
    print_status "Deploying Pet Clinic application container..."
    
    # Stop and remove existing container if running
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_status "Stopping existing container..."
        docker stop $CONTAINER_NAME || true
        docker rm $CONTAINER_NAME || true
    fi
    
    # Run new container
    print_status "Starting new container..."
    docker run -d \
        --name $CONTAINER_NAME \
        --restart unless-stopped \
        -p $APP_PORT:$APP_PORT \
        --health-cmd="curl -f http://localhost:$APP_PORT/actuator/health || exit 1" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        $IMAGE_NAME
    
    if [ $? -eq 0 ]; then
        print_success "Pet Clinic application deployed successfully!"
        print_status "Application will be available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):$APP_PORT"
    else
        print_error "Failed to deploy Pet Clinic application"
        return 1
    fi
}

# Function to check application health
check_health() {
    print_status "Checking application health..."
    if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q $CONTAINER_NAME; then
        print_success "Container is running"
        docker exec $CONTAINER_NAME curl -f http://localhost:$APP_PORT/actuator/health 2>/dev/null && \
            print_success "Application is healthy" || \
            print_error "Application health check failed"
    else
        print_error "Container is not running"
        return 1
    fi
}

# Function to view application logs
view_logs() {
    if docker ps -a --filter "name=$CONTAINER_NAME" | grep -q $CONTAINER_NAME; then
        docker logs --tail 50 -f $CONTAINER_NAME
    else
        print_error "Container $CONTAINER_NAME not found"
        return 1
    fi
}

# Main function
main() {
    case "${1:-deploy}" in
        "deploy")
            authenticate_docker && \
            if check_for_updates; then
                deploy_container
                print_success "Container updated to latest image"
            else
                print_status "Image is up to date, but deploying anyway..."
                deploy_container
            fi
            ;;
        "update")
            authenticate_docker && \
            if check_for_updates; then
                deploy_container
                print_success "Container updated to latest image"
            else
                print_status "No updates available"
            fi
            ;;
        "health")
            check_health
            ;;
        "logs")
            view_logs
            ;;
        "stop")
            docker stop $CONTAINER_NAME 2>/dev/null && print_success "Container stopped" || print_error "Failed to stop container"
            ;;
        "start")
            docker start $CONTAINER_NAME 2>/dev/null && print_success "Container started" || print_error "Failed to start container"
            ;;
        "restart")
            docker restart $CONTAINER_NAME 2>/dev/null && print_success "Container restarted" || print_error "Failed to restart container"
            ;;
        "remove")
            docker stop $CONTAINER_NAME 2>/dev/null || true
            docker rm $CONTAINER_NAME 2>/dev/null && print_success "Container removed" || print_error "Failed to remove container"
            ;;
        *)
            echo "Usage: $0 {deploy|update|health|logs|stop|start|restart|remove}"
            echo ""
            echo "Commands:"
            echo "  deploy  - Deploy/redeploy the application"
            echo "  update  - Check for updates and deploy if available"
            echo "  health  - Check application health"
            echo "  logs    - View application logs"
            echo "  stop    - Stop the container"
            echo "  start   - Start the container"
            echo "  restart - Restart the container"
            echo "  remove  - Remove the container"
            exit 1
            ;;
    esac
}

main "$@"
SCRIPT_EOF
    
    # Replace placeholders in the script
    sudo sed -i "s|IMAGE_NAME_PLACEHOLDER|${IMAGE_NAME}|g" /home/ec2-user/scripts/manage-petclinic.sh
    sudo sed -i "s|CONTAINER_NAME_PLACEHOLDER|${CONTAINER_NAME}|g" /home/ec2-user/scripts/manage-petclinic.sh
    sudo sed -i "s|NEXUS_REGISTRY_PLACEHOLDER|${NEXUS_REGISTRY}|g" /home/ec2-user/scripts/manage-petclinic.sh
    
    # Set permissions
    sudo chown -R ec2-user:ec2-user /home/ec2-user/scripts/
    sudo chmod +x /home/ec2-user/scripts/manage-petclinic.sh
    
    print_success "Application management script created at /home/ec2-user/scripts/manage-petclinic.sh"
}

# Function to install New Relic monitoring
install_newrelic() {
    if [ -n "$NEW_RELIC_KEY" ] && [ -n "$NEW_RELIC_ACCOUNT_ID" ]; then
        print_status "Installing New Relic monitoring..."
        curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
        sudo NEW_RELIC_API_KEY="$NEW_RELIC_KEY" \
            NEW_RELIC_ACCOUNT_ID="$NEW_RELIC_ACCOUNT_ID" \
            NEW_RELIC_REGION="EU" \
            /usr/local/bin/newrelic install -y
        print_success "New Relic monitoring installed successfully!"
    else
        print_warning "New Relic credentials not provided, skipping monitoring setup"
    fi
}

# Function to set hostname and final configuration
finalize_setup() {
    print_status "Finalizing staging environment setup..."
    
    # Set hostname
    sudo hostnamectl set-hostname stage-instance
    
    # Create a simple status script
    cat << 'STATUS_EOF' | sudo tee /home/ec2-user/scripts/staging-status.sh > /dev/null
#!/bin/bash
echo "=== Staging Environment Status ==="
echo "Hostname: $(hostname)"
echo "Docker Status: $(systemctl is-active docker)"
echo "Pet Clinic Container: $(docker ps --filter 'name=stage-petclinic' --format 'table {{.Status}}' | tail -n +2 || echo 'Not running')"
echo "Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "==================================="
STATUS_EOF
    
    sudo chmod +x /home/ec2-user/scripts/staging-status.sh
    
    print_success "Staging environment setup completed!"
    print_status "Use '/home/ec2-user/scripts/manage-petclinic.sh deploy' to deploy the Pet Clinic application"
    print_status "Use '/home/ec2-user/scripts/staging-status.sh' to check environment status"
}

# Main execution
main() {
    print_status "Starting staging environment setup..."
    
    update_system
    install_docker
    create_app_management_script
    install_newrelic
    finalize_setup
    
    print_success "Staging environment setup completed successfully!"
    print_warning "System will reboot in 10 seconds to apply all changes..."
    sleep 10
    sudo reboot
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF
    
    # Replace placeholders
    sed -i "s|NEXUS_IP_PLACEHOLDER|${nexus_ip}|g" "${SCRIPT_DIR}/staging-app-deploy.sh"
    sed -i "s|NR_KEY_PLACEHOLDER|${nr_key}|g" "${SCRIPT_DIR}/staging-app-deploy.sh"
    sed -i "s|NR_ACCT_ID_PLACEHOLDER|${nr_acct_id}|g" "${SCRIPT_DIR}/staging-app-deploy.sh"
    
    chmod +x "${SCRIPT_DIR}/staging-app-deploy.sh"
    
    print_success "Staging application deployment script created: ${SCRIPT_DIR}/staging-app-deploy.sh"
    print_status "Copy this script to your EC2 instance and run it to set up the staging environment"
}

# Function to run interactive shell in container
shell() {
    print_header "Starting Interactive Shell in Container"
    
    create_docker_network
    
    # Prepare AWS credentials volume mounts
    local aws_mounts=""
    if [ -f "$HOME/.aws/credentials" ]; then
        aws_mounts="-v $HOME/.aws:/home/terraform/.aws:ro"
    fi
    
    # Prepare environment variables for AWS
    local aws_env=""
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        aws_env="-e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
    fi
    if [ -n "$AWS_PROFILE" ]; then
        aws_env="$aws_env -e AWS_PROFILE=$AWS_PROFILE"
    fi
    
    print_status "Starting interactive bash shell in container..."
    docker run --rm -it \
        --name "$DOCKER_CONTAINER_NAME-shell" \
        --network "$DOCKER_NETWORK" \
        -v "$(pwd):/workspace" \
        -v "$(dirname $(pwd)):/workspace/.." \
        $aws_mounts \
        $aws_env \
        -e AWS_DEFAULT_REGION="$AWS_REGION" \
        "$DOCKER_IMAGE_NAME:latest" \
        bash
}

# Function to clean up Docker resources
cleanup_docker() {
    print_header "Cleaning Up Docker Resources"
    
    # Stop and remove container if running
    if docker ps -a --format "table {{.Names}}" | grep -q "$DOCKER_CONTAINER_NAME"; then
        docker rm -f "$DOCKER_CONTAINER_NAME" 2>/dev/null || true
        print_status "Removed container: $DOCKER_CONTAINER_NAME"
    fi
    
    # Remove Docker image
    if docker images --format "table {{.Repository}}" | grep -q "$DOCKER_IMAGE_NAME"; then
        docker rmi "$DOCKER_IMAGE_NAME:latest" 2>/dev/null || true
        print_status "Removed Docker image: $DOCKER_IMAGE_NAME"
    fi
    
    # Remove Docker network
    if docker network ls --format "table {{.Name}}" | grep -q "$DOCKER_NETWORK"; then
        docker network rm "$DOCKER_NETWORK" 2>/dev/null || true
        print_status "Removed Docker network: $DOCKER_NETWORK"
    fi
    
    # Remove plan files
    if [ -f "staging.tfplan" ]; then
        rm staging.tfplan
        print_status "Removed staging.tfplan"
    fi
    
    print_success "Docker cleanup completed!"
}

# Function to show help
show_help() {
    echo -e "${PURPLE}Fiifi Pet Adoption Auto Discovery - Docker Staging Environment Script${NC}"
    echo ""
    echo -e "${CYAN}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${CYAN}Infrastructure Commands:${NC}"
    echo "  build       Build Docker image for staging environment"
    echo "  deploy      Deploy the staging infrastructure using Docker"
    echo "  destroy     Destroy the staging infrastructure using Docker"
    echo "  status      Check staging infrastructure status"
    echo "  urls        Show staging access URLs"
    echo "  shell       Start interactive shell in Docker container"
    echo "  compose     Manage Docker Compose services"
    echo "  cleanup     Clean up Docker resources and temporary files"
    echo ""
    echo -e "${CYAN}Application Commands:${NC}"
    echo "  create-app-script <nexus_ip> <nr_key> <nr_account_id>"
    echo "              Create staging application deployment script"
    echo ""
    echo -e "${CYAN}Docker Compose Commands:${NC}"
    echo "  compose up       Start all services"
    echo "  compose down     Stop all services"
    echo "  compose logs     Show service logs"
    echo "  compose ps       Show running services"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 build                                    # Build the Docker image"
    echo "  $0 deploy                                   # Deploy staging infrastructure"
    echo "  $0 create-app-script 10.0.1.100 nr_key nr_account  # Create app deployment script"
    echo "  $0 shell                                    # Interactive shell in container"
    echo "  $0 urls                                     # Show Jenkins and Vault URLs"
    echo "  $0 destroy                                  # Destroy all infrastructure"
    echo "  $0 compose up                               # Start Docker Compose services"
    echo "  $0 cleanup                                  # Clean up all Docker resources"
    echo ""
    echo -e "${CYAN}Environment Variables:${NC}"
    echo "  AWS_ACCESS_KEY_ID     - AWS access key ID"
    echo "  AWS_SECRET_ACCESS_KEY - AWS secret access key"
    echo "  AWS_SESSION_TOKEN     - AWS session token (if using temporary credentials)"
    echo "  AWS_PROFILE           - AWS profile name (alternative to access keys)"
    echo ""
    echo -e "${CYAN}Prerequisites:${NC}"
    echo "  - Docker installed and running"
    echo "  - AWS credentials configured (environment variables or ~/.aws/credentials)"
    echo "  - Main Terraform configuration in parent directory"
    echo ""
    echo -e "${CYAN}Application Deployment:${NC}"
    echo "  1. Deploy infrastructure: $0 deploy"
    echo "  2. Create app script: $0 create-app-script <nexus_ip> <nr_key> <nr_account>"
    echo "  3. Copy staging-app-deploy.sh to EC2 instance"
    echo "  4. Run the script on EC2 to set up Docker and Pet Clinic app"
    echo ""
}

# Function to manage Docker Compose
manage_compose() {
    local action="$1"
    shift
    
    case "$action" in
        "up")
            print_status "Starting Docker Compose services..."
            docker-compose up -d "$@"
            ;;
        "down")
            print_status "Stopping Docker Compose services..."
            docker-compose down "$@"
            ;;
        "logs")
            docker-compose logs -f "$@"
            ;;
        "ps")
            docker-compose ps "$@"
            ;;
        "exec")
            docker-compose exec "$@"
            ;;
        *)
            print_error "Unknown compose action: $action"
            echo "Available actions: up, down, logs, ps, exec"
            exit 1
            ;;
    esac
}

# Main script logic
main() {
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    case "${1:-help}" in
        "build")
            check_prerequisites
            create_docker_network
            build_docker_image
            ;;
        "deploy")
            check_prerequisites
            create_docker_network
            build_docker_image
            deploy_staging_infrastructure
            show_staging_urls
            ;;
        "destroy")
            destroy_staging_infrastructure
            ;;
        "status")
            show_staging_status
            ;;
        "urls")
            show_staging_urls
            ;;
        "shell")
            check_prerequisites
            create_docker_network
            build_docker_image
            shell
            ;;
        "create-app-script")
            if [ $# -lt 4 ]; then
                print_error "Missing required parameters for create-app-script"
                print_status "Usage: $0 create-app-script <nexus_ip> <new_relic_key> <new_relic_account_id>"
                exit 1
            fi
            create_staging_app_script "$2" "$3" "$4"
            ;;
        "compose")
            shift
            manage_compose "$@"
            ;;
        "cleanup")
            cleanup_docker
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"