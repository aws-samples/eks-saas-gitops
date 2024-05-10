# Use a lightweight base image
FROM alpine:latest

ARG aws_region
ENV AWS_REGION=$aws_region

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

COPY . /
# Display installed versions
RUN terraform version && git version && kubectl version --client && mkdir -p /root/.ssh/ && ssh-keyscan "git-codecommit.${AWS_REGION}.amazonaws.com" >> /root/.ssh/known_hosts
