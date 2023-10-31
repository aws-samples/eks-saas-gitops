# TODO List

- Create secret to be able to clone and push to the GitHub Repository

```bash
kubectl create secret generic github-ssh-key --from-file=ssh-privatekey=PATH_TO_PRIVATE_KEY --from-literal=ssh-privatekey.mode=0600 -nargo-workflows
```