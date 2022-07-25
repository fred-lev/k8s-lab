# Kubernetes lab environment

[![Lint Code Base](https://github.com/fred-lev/k8s-gcp-lab/actions/workflows/linter.yml/badge.svg?branch=main)](https://github.com/fred-lev/k8s-gcp-lab/actions/workflows/linter.yml)

The code in this repository deploys and configure a simple kubernetes cluster running in GCP.

By default the cluster is made of 1 controller and 2 worker nodes. The number of workers can be adjusted by increasing `worker.count` in [terraform.tfvars](terraform/lab/terraform.tfvars)

The CNI plugin used by the cluster is [Calico](https://docs.projectcalico.org/about/about-calico).

## Install gcloud SDK

Refer to the doc [here](https://cloud.google.com/sdk/docs/downloads-interactive)

```console
curl https://sdk.cloud.google.com | bash
```

Provide path to `zsh` rc file to enable auto-completion.

E.g:

```console
~/.zsh.d/.zsh_path
```

Initialize your gcloud env by running:

```console
gcloud init
```

## Terraform

Retrieve personal google cloud credentials (token):

```console
gcloud auth application-default login
```

**REM:** The official doc recommend [not to use service accounts during development on local workstation](https://cloud.google.com/iam/docs/best-practices-for-using-and-managing-service-accounts#development)

Create a bucket in asia to store terraform remote state files as defined in [backend.tf](terraform/lab/backend.tf):

```console
gsutil mb -l asia gs://tf-state-k8s-lab-flev
gsutil versioning set on gs://tf-state-k8s-lab-flev
```

Set the bucket name and prefix in [backend.tf](terraform/lab/backend.tf)

Run the following command to initialize the remote backend and apply the exiting terraform config:

```bash
cd $(git rev-parse --show-toplevel)/terraform/lab
terraform init && terraform apply -auto-approve
```

**REM:** I am using `-auto-approve` here since it's a lab.

## Ansible

### for GCP compute instances

Install required python libraries:

The ansible dynamic inventory GCP module require both the requests and the google-auth libraries to be installed [requirements](bootstrap/requirements.txt)

Passlib is used to generate password hashes for the lab VM users.

```sh
cd $(git rev-parse --show-toplevel)
$(brew --prefix)/bin/python3 -mpip install -r bootstrap/requirements.txt --user
```

Enable OS login project wide

```console
gcloud compute project-info add-metadata \
    --metadata enable-oslogin=TRUE
```

Create a service account and give it the `viewer` role on the current google cloud project.
So it can be use by the dynamic inventory plugin to retrieve the details of the compute instances in the project.
The service account also needs the `osAdminLogin` to be able to use it to login as root on the VMs.

```console
export GCP_PROJECT=melodic-sunbeam-340508
cd $(git rev-parse --show-toplevel)/ansible
gcloud iam service-accounts create ansible-sa --display-name="Service Account for Ansible"
gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:ansible-sa@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/viewer
gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:ansible-sa@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/compute.osAdminLogin
gcloud iam service-accounts keys create ansible_sa_key.json --iam-account=ansible-sa@$GCP_PROJECT.iam.gserviceaccount.com
gcloud auth activate-service-account ansible-sa@$GCP_PROJECT.iam.gserviceaccount.com --key-file=ansible_sa_key.json
gcloud compute os-login ssh-keys add --key-file ~/.ssh/flevlab.pub
```

**REM:** Add `ansible_sa_key.json` , in your `.gitignore` and set `service_account_file:ansible_sa_key.json` variable in [lab_gcp.yml](ansible/inventory/lab_gcp.yml) as well as the gcloud project name if changed.

Set the following global variables in [vars.yml](ansible/inventory/group_vars/all/vars.yml)

```yaml
---
ansible_user: sa_111658XXXXXX91899
ansible_ssh_private_key_file: ~/.ssh/flevlab.pub
```

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

### Alternatively use GKE and provision a cluster using gcloud

```console
gcloud beta container --project "melodic-sunbeam-340508" clusters create "flevlab" --zone "asia-southeast1-b" --no-enable-basic-auth --cluster-version "1.20.12-gke.1500" --release-channel "stable" --machine-type "e2-medium" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --max-pods-per-node "110" --num-nodes "3" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "projects/melodic-sunbeam-340508/global/networks/default" --subnetwork "projects/melodic-sunbeam-340508/regions/asia-southeast1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --tags "flevlab" --node-locations "asia-southeast1-b"
```

Allow access from laptop pub IP

```console
MYPUBIP=$(curl -s ifconfig.me)
gcloud compute --project=melodic-sunbeam-340508 firewall-rules create lab-allow-my-pub-ip --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:22,tcp:6443,tcp:80,tcp:8080,tcp:30000-60000,icmp --source-ranges=$MYPUBIP/32
```

### Playbook for the initial cluster configuration

```bash
cd $(git rev-parse --show-toplevel)/ansible && ansible-playbook playbooks/lab.yml -i inventory
```

<!-- textlint-disable -->

The playbook does the following:

- turn off swap on all nodes
- install required packages
- install and mark hold kubeadm, kubelet and kubectl (1.20.1-00)
- initialize the controller node using kubeadm
- setup kube config on the controller
- install calico
- join the worker nodes to the cluster
- configure kubectl alias and bash completion on controller node

<!-- textlint-enable -->

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

## GitHub actions

This repository is using GH Actions to execute [super-linter](https://github.com/github/super-linter).

I am mostly interested in linting the ansible (YAML), terraform(HCL) and Markdown files in the repository using:

- ansible-lint
- markdownlint
- terrascan
- tflint
- yamlint

super-linter is an easy, low maintenance way to do it.
