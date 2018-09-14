# ops-gke-vault
<<<<<<< HEAD
Operations code for running HashiCorp Vault on Google Kubernetes Engine (GKE)
=======
[HashiCorp Vault](https://www.vaultproject.io) on [Google Kubernetes Engine GKE](https://cloud.google.com/kubernetes-engine) with [Terraform](https://www.terraform.io)

# IaC 'Local' Development Setup on Linux
## Install [Google Cloud SDK](https://cloud.google.com/sdk/docs/downloads-interactive#linux):
```none
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
gcloud components install kubectl beta
```
You will need your own sandbox project.
```none
gcloud config set project ops-bcurtis-sb
```
## Create Managed DNS Zone
*NOTE: You don't actually need to have a domain registrar for code to run, however it’s needed if you want to generate a usable application with DNS and a SSL certificate from Let’s Encrypt.*

```none
gcloud dns managed-zones create obs-lzy-sh --description="My Sandbox Zone" --dns-name="obs.lzy.sh"
```
## Add Record Set to Your Tools Project Zone

```none
$ gcloud dns record-sets list --zone obs-lzy-sh
NAME          TYPE  TTL    DATA
obs.lzy.sh.  NS    21600  ns-cloud-a1.googledomains.com.,ns-cloud-a2.googledomains.com.,ns-cloud-a3.googledomains.com.,ns-cloud-a4.googledomains.com.
obs.lzy.sh.  SOA   21600  ns-cloud-a1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300
```
This will show your NS record, grab the DATA and and create a NS record on your registrar. The next step needs to be completed by a user with DNS Administrator IAM role for the tools project.

```none
gcloud --project ops-tools-prod dns record-sets transaction start -z=lzy-sh
gcloud --project ops-tools-prod dns record-sets transaction add -z=lzy-sh --name="obs.lzy.sh." --type=NS --ttl=300 "ns-cloud-a1.googledomains.com." "ns-cloud-a2.googledomains.com." "ns-cloud-a3.googledomains.com." "ns-cloud-a4.googledomains.com."
gcloud --project ops-tools-prod dns record-sets transaction execute -z=lzy-sh
```

## Create Bucket for Terraform Remote State
```none
gsutil mb -p ops-bcurtis-sb -c multi_regional -l US gs://ops-bcurtis-sb_tf_state
```
## Install [Terraform](https://www.terraform.io/downloads.html):
```none
curl -O https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip
sudo unzip terraform_0.11.8_linux_amd64.zip -d /usr/local/bin
```
## Setup [Google Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default):
```none
gcloud auth application-default login
```
## Clone Project:
```none
git clone git@github.com:lzysh/ops-gke-vault.git
```
## Initialize Terraform and select workspace:
```none
cd ops-gke-vault/terraform
terraform init -backend-config="bucket=ops-bcurtis-sb_tf_state" -backend-config="project=ops-bcurtis-sb"
terraform workspace new ops-vault-$RANDOM-sb

Created and switched to workspace "ops-vault-17252-sb"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
```
> NOTE: At this point you are setup to use [remote state](https://www.terraform.io/docs/state/remote.html) in Terraform. Use the workspace name printed out in the last command as your project name going forward.
Create a `local.tfvars` file:
```none
# Google Project ID
project = "ops-vault-17252-sb"
# Billing ID
billing_id = "XXXXXX-XXXXXX-XXXXXX"
# Sandbox Folder ID (in your team hierarchy)
folder_id = "XXXXXXXXXXXX"
# Domain Name
domain = "obs.lzy.sh"
# Google Project ID for Tools
tools_project = "ops-bcurtis-sb"
```
>NOTE: The folder_id variable will be the ID of the Sanbox folder your have the proper IAM roles set on.
## Terraform Plan:
```none
terraform plan -out="plan.out" -var-file="local.tfvars"
terraform apply "plan.out"
```
It should take about 5-10 minutes for the Vault instance to be accessible. Ingress is doing its thing, DNS is being registered and SSL certificates are being created.

The URL and command to decrypt the root token are in the Terraform output.
>>>>>>> This commit should support IaC development
