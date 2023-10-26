# Flux CD v2 Terraform Module

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.9 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.20 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.flux2](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.flux2-sync](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.flux_system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_activate_helm_controller"></a> [activate\_helm\_controller](#input\_activate\_helm\_controller) | Defines if Helm controller should be deployed | `bool` | `true` | no |
| <a name="input_activate_image_automation_controller"></a> [activate\_image\_automation\_controller](#input\_activate\_image\_automation\_controller) | Defines if image automation controller should be activated | `bool` | `false` | no |
| <a name="input_activate_image_reflection_controller"></a> [activate\_image\_reflection\_controller](#input\_activate\_image\_reflection\_controller) | Defines if image automation controller should be activated | `bool` | `false` | no |
| <a name="input_activate_kustomize_controller"></a> [activate\_kustomize\_controller](#input\_activate\_kustomize\_controller) | Defines if Kustomize controller should be activated | `bool` | `true` | no |
| <a name="input_activate_notification_controller"></a> [activate\_notification\_controller](#input\_activate\_notification\_controller) | Defines if notification controller should be activated | `bool` | `true` | no |
| <a name="input_activate_source_controller"></a> [activate\_source\_controller](#input\_activate\_source\_controller) | Defines if source controller should be activated | `bool` | `true` | no |
| <a name="input_ca"></a> [ca](#input\_ca) | Amazon EKS Certificate authority | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Amazon EKS Cluster endpoint URL | `string` | n/a | yes |
| <a name="input_git_branch"></a> [git\_branch](#input\_git\_branch) | Git branch name to be used by Flux | `string` | `"main"` | no |
| <a name="input_git_url"></a> [git\_url](#input\_git\_url) | Git URL to be used by Flux | `string` | n/a | yes |
| <a name="input_image_automation_controller_sa_annotations"></a> [image\_automation\_controller\_sa\_annotations](#input\_image\_automation\_controller\_sa\_annotations) | Defines image automation controller SA annotations | `string` | `""` | no |
| <a name="input_image_reflection_controller_sa_annotations"></a> [image\_reflection\_controller\_sa\_annotations](#input\_image\_reflection\_controller\_sa\_annotations) | Defines image reflection controller SA annotations | `string` | `""` | no |
| <a name="input_kustomization_path"></a> [kustomization\_path](#input\_kustomization\_path) | n/a | `string` | `"Path for Kustomization directory"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Flux default Kubernetes namespace | `string` | `"flux-system"` | no |
| <a name="input_token"></a> [token](#input\_token) | Amazon EKS Cluster token | `string` | n/a | yes |
| <a name="input_values_path"></a> [values\_path](#input\_values\_path) | Path for Helm values | `string` | n/a | yes |

## Outputs

No outputs.
