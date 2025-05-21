# Use a lightweight base image
FROM alpine:latest

# Install necessary dependencies
RUN apk update && \
    apk add --no-cache \
        ca-certificates \
        git \
        openssh \
        openssl \
        wget \
        unzip \
        jq \
        yq \
        bash \
        curl # Added curl to fetch kubectl

# Install Terraform
ENV TERRAFORM_VERSION=1.5.1
RUN wget --quiet https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install kubectl
ENV KUBECTL_VERSION=v1.27.0
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Create SSH directory
RUN mkdir -p /root/.ssh/

# Copy all workflow scripts and known_hosts file
COPY . /

# Copy known_hosts to SSH directory
RUN if [ -f /known_hosts ]; then \
        cp /known_hosts /root/.ssh/known_hosts; \
        chmod 600 /root/.ssh/known_hosts; \
    fi

# Display installed versions
RUN terraform version && git version && kubectl version --client
