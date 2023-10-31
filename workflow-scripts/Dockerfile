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
        unzip

# Install Terraform
ENV TERRAFORM_VERSION=1.5.1
RUN wget --quiet https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

COPY . /
# Display installed versions
RUN terraform version && git version && mkdir -p /root/.ssh/ && ssh-keyscan "git-codecommit.${AWS_REGION}.amazonaws.com" >> /root/.ssh/known_hosts

