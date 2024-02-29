secret:
  create: true
  data:
    identity: |-
      ${private_key}
    identity.pub: |-
      ${public_key}
    known_hosts: |-
      ${known_hosts}
gitRepository:
  spec:
    ref:
      branch: ${git_branch}
    url: ${git_url}
kustomization:
  spec:
    path: ${kustomization_path}
