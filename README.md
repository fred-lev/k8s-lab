# Kubernetes lab environment

[![Lint Code Base](https://github.com/fred-lev/k8s-gcp-lab/actions/workflows/linter.yml/badge.svg?branch=main)](https://github.com/fred-lev/k8s-gcp-lab/actions/workflows/linter.yml)

The code in this repo deploys and configure a simple kubernetes cluster running in GCP.

By default the cluster is made of 1 controller and 2 worker nodes. The number of workers can be adjusted by increasing `worker.count` in [terraform.tfvars](terraform/lab/terraform.tfvars)

The CNI plugin used by the cluster is [Calico](https://docs.projectcalico.org/about/about-calico).

## Terraform

Retrieve personal google cloud credentials (token):

```console
gcloud auth application-default login
```

**REM:** The official doc recommend [not to use service accounts during development on local workstation](https://cloud.google.com/iam/docs/best-practices-for-using-and-managing-service-accounts#development)

Create a bucket in asia to store terraform remote state files as defined in [backend.tf](terraform/lab/backend.tf):

```console
gsutil mb -l asia gs://tf-state-k8s-lab
gsutil versioning set on gs://tf-state-k8s-lab
```

Set the bucket name and prefix in [backend.tf](terraform/lab/backend.tf)

Run the following command to initialize the remote backend and apply the exiting terraform config:

```bash
cd $(git rev-parse --show-toplevel)/terraform/lab
terraform init && terraform apply -auto-approve
```

**REM:** I am using `-auto-approve` here since it's a lab.

## Ansible

### Dynamic inventory for GCP compute instances

Install required python libraries:

The ansible dynamic inventory GCP module require both the requests and the google-auth libraries to be installed [requirements](bootstrap/requirements.txt)

Passlib is used to generate password hashes for the lab VM users.

```sh
cd $(git rev-parse --show-toplevel)
$(brew --prefix)/bin/python3 -mpip install -r bootstrap/requirements.txt --user
```

Create a service account and give it the `viewer` role on the current google cloud project.
So it can be use by the dynamic inventory plugin to retrieve the details of the compute instances in the project.

```console
export GCP_PROJECT=astral-option-316701
cd $(git rev-parse --show-toplevel)/ansible
gcloud iam service-accounts create ansible-dyn-inv --display-name="Service Account for Ansible Dynamic Inventory"
gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:ansible-dyn-inv@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/viewer
gcloud iam service-accounts keys create ansible_dyn_inv_sa_key.json --iam-account=ansible-dyn-inv@$GCP_PROJECT.iam.gserviceaccount.com
```

**REM:** Add `ansible_dyn_inv_sa_key.json` , in your `.gitignore` and set `service_account_file:ansible_dyn_inv_sa_key.json` variable in [cks_project.gcp.yml](ansible/inventory/lab_gcp.yml)

Verify that you can list VM in the inventory using that service account:

```bash
cd $(git rev-parse --show-toplevel)/ansible && ansible-inventory --graph  -i inventory
```

```console
@all:
  |--@k8s_controller:
  |  |--k8s-lab-controller-01
  |--@k8s_workers:
  |  |--k8s-lab-worker-01
  |  |--k8s-lab-worker-02
  |--@ungrouped:
```

### Playbook for the initial cluster configuration

```bash
cd $(git rev-parse --show-toplevel)/ansible && ansible-playbook playbooks/lab.yml -i inventory
```

The playbook does the following:

- turn off swap on all nodes
- install required packages
- install and mark hold kubeadm, kubelet and kubectl (1.20.1-00)
- initialize the controller node using kubeadm
- setup kube config on the controller
- install calico
- join the worker nodes to the cluster
- configure kubectl alias and bash completion on controller node

### add all inventory hosts to your local workstation hosts file

```bash
cd $(git rev-parse --show-toplevel)/ansible && sudo ansible-playbook playbooks/add_nodes_etc_hosts.yml -i inventory
```

### verify the cluster state

```bash
ssh k8s-lab-controller-01
```

```bash
user@k8s-lab-controller-01:~$ k cluster-info
Kubernetes control plane is running at https://10.240.0.11:6443
KubeDNS is running at https://10.240.0.11:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

```bash
user@k8s-lab-controller-01:~$ k get nodes
NAME                    STATUS   ROLES                  AGE   VERSION
k8s-lab-controller-01   Ready    control-plane,master   30m   v1.20.1
k8s-lab-worker-01       Ready    <none>                 30m   v1.20.1
k8s-lab-worker-02       Ready    <none>                 30m   v1.20.1
```

## Github actions

This repo is using GH Actions to execute [super-linter](https://github.com/github/super-linter).

I am mostly interested in linting the ansible (YAML), terraform(HCL) and markdown files in the repo using:

- ansible-lint
- markdownlint
- terrascan
- tflint
- yamlint

super-linter is an easy, low maintenance way to do it.
