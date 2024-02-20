# Define here your GitHub credentials
secret:
  create: true
  data:
    identity: ${flux_private_key}
    identity.pub: ${flux_public_key}
    known_hosts: ${known_hosts}