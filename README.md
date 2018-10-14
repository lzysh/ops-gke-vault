# ops-gke-vault
Operations code for running [HashiCorp Vault](https://www.vaultproject.io) on [Google Kubernetes Engine GKE](https://cloud.google.com/kubernetes-engine) with [Terraform](https://www.terraform.io)
# IaC Development Setup on Linux

## Syntax
YAML: [yamllint](https://github.com/adrienverge/yamllint)

Terraform: [vim-terraform](https://github.com/hashivim/vim-terraform)

Markdown:
## Install Google Cloud SDK
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
gcloud --project ops-tools-prod dns record-sets transaction start -z=lzy.sh
gcloud --project ops-tools-prod dns record-sets transaction add -z=lzy.sh --name="obs.lzy.sh." --type=NS --ttl=300 "ns-cloud-a1.googledomains.com." "ns-cloud-a2.googledomains.com." "ns-cloud-a3.googledomains.com." "ns-cloud-a4.googledomains.com."
gcloud --project ops-tools-prod dns record-sets transaction execute -z=lzy.sh
```
## Create Bucket for Terraform Remote State
```none
gsutil mb -p ops-bcurtis-sb -c multi_regional -l US gs://ops-bcurtis-sb_tf_state
```
## Install Terraform
```none
curl -O https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip
sudo unzip terraform_0.11.8_linux_amd64.zip -d /usr/local/bin
```
## Setup Google Application Default Credentials
```none
gcloud auth application-default login
```
## Clone Project
```none
git clone git@github.com:lzysh/ops-gke-vault.git
```
## Initialize Terraform
```none
cd ops-gke-vault/terraform
terraform init -backend-config="bucket=ops-bcurtis-sb_tf_state" -backend-config="project=ops-bcurtis-sb"
```
> NOTE: At this point you are setup to use [remote state](https://www.terraform.io/docs/state/remote.html) in Terraform. 
Create a `local.tfvars` file and edit to fit you needs:
```none
cp local.tfvars.EXAMPLE local.tfvars
```
>NOTE: The folder_id variable will be the ID of the Sanbox folder your have the proper IAM roles set on.
## Terraform Plan & Apply for Infrastructure
```none
random=$RANDOM
team=ops
terraform workspace new vault-infra
terraform plan -out="plan.out" -var-file="local.tfvars" -var="prefix=${team}" -var="env=sb" -var="host=vault-${random}"
terraform apply "plan.out"
```
It will take about 5-10 minutes after terraform apply for the Vault instance to be accessible. Ingress is doing its thing, DNS is being propagated and SSL certificates are being issued.

The URL and command to decrypt the root token are in the Terraform output.

## Terraform Plan & Apply for Vault
```none
cd vault
terraform workspace new vault
terraform plan -out="plan.out" -var="url=`cd ..;terraform output url`" -var="root_token=`cd ..;terraform output root_token`" -var="project=`cd ..;terraform output project`"
terraform apply "plan.out"
```

## Install Vault Locally 
```none
curl -O https://releases.hashicorp.com/vault/0.11.1/vault_0.11.1_linux_amd64.zip
sudo unzip vault_0.11.1_linux_amd64.zip -d /usr/local/bin
```
## Vault Smoke Test:
```none
cd ../../test
./smoke.sh
```
## Vault Manual Testing Examples
```none
export project=`cd ../terraform;terraform output project`
export VAULT_ADDR=`cd ../terraform;terraform output url`
export VAULT_SKIP_VERIFY=true
vault login -method=gcp role=vault-testing service_account=vault-testing@${project}.iam.gserviceaccount.com project=${project}"
```
Enable KV2
```none
vault kv enable-versioning secret
```
Put/Get Secret
```none
vault kv put secret/my_team/pre-prod/api_key key=QWsDEr876d6s4wLKcjfLPxxuyRTE

vault kv get secret/my_team/pre-prod/api_key
====== Metadata ======
Key              Value
---              -----
created_time     2018-09-16T04:04:50.14260161Z
deletion_time    n/a
destroyed        false
version          1

=== Data ===
Key    Value
---    -----
key    QWsDEr876d6s4wLKcjfLPxxuyRTE
```
Put/Get Multi Value Secret
```none
vault kv put secret/my_team/pre-prod/db_info url=foo.example.com:35533 db_name=users username=admin password=passw0rd

vault kv get secret/my_team/pre-prod/db_info
====== Metadata ======
Key              Value
---              -----
created_time     2018-09-16T04:09:55.452868097Z
deletion_time    n/a
destroyed        false
version          1

====== Data ======
Key         Value
---         -----
db_name     users
password    passw0rd
url         foo.example.com:35533
username    admin
```
## Terraform Destroy
```none
cd ../terraform/vault

cd ..
terraform destroy -var-file="local.tfvars" -var="prefix=${team}" -var="env=sb" -var="host=vault-${random}"
```
