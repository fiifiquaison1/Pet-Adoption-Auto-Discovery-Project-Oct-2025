# Dockerfile for Fiifi Pet Adoption Auto Discovery - Staging Environment
# This containerizes the Terraform deployment for the staging environment

FROM hashicorp/terraform:1.6

# Install additional tools
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    git \
    openssh-client \
    python3 \
    py3-pip \
    aws-cli

# Set working directory
WORKDIR /workspace

# Copy Terraform configuration files
COPY . .

# Set executable permissions for scripts
RUN chmod +x *.sh 2>/dev/null || true

# Create non-root user for security
RUN addgroup -g 1000 terraform && \
    adduser -u 1000 -G terraform -s /bin/bash -D terraform

# Create directories with proper permissions
RUN mkdir -p /workspace/.terraform && \
    chown -R terraform:terraform /workspace

# Switch to non-root user
USER terraform

# Set environment variables
ENV TF_IN_AUTOMATION=true
ENV TF_CLI_ARGS_plan="-no-color"
ENV TF_CLI_ARGS_apply="-no-color"
ENV TF_CLI_ARGS_destroy="-no-color"

# Default command
CMD ["bash", "./deploy-staging.sh", "help"]