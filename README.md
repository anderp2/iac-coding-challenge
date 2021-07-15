# iac-coding-challenge

Overview
========
This repository contains files needed to configure Azure Devops Pipelines and Terraform script to create and destroy resources for the Coding Challenge infrastructure. 

Pre-requisites / Azure Resources Managed Outside of this deployment
===================================================================

 - Azure DevOps Agent on Linux VM
 - Service Principal with Subscription level access to create and destroy resources
 - Storage Account to save Terraform tfstate
 - Key Vault to store:
   - Azure Subscription level Service Principal Connection Secrets
   - Access Key to the Blob Storage Account for tfstate
   - Linux VM adminuser password
- az.tools Github repo with bash script for terraform apply / destroy - https://github.com/anderp2/az.tools

Azure Devops Pipeline
=====================
**Filename:**  azure-pipelines.yaml

**Usage:**  This file can be used to configure both a resource deployment and resource delete pipeline for the Coding Challenge. The resource deployment pipeline should be configured / run with an Azure Devops UI varialbe "ACTION = apply". The resource delete pipeline should be configured / run with an Azure Devops UI variable "ACTION = destroy".

**Pipeline Steps:**
1) Pull the az.tools github repo
2) Connect to and query the Azure keyvault for secret values
3) Excute az.tools/terraform.sh to apply / destroy resources in terraform deployment code

**Environment Variable List for az.tools/terrform.sh:**
 - ARM_SUBSCRIPTION_ID (keyvault variable for terraform Service Principal)
 - ARM_CLIENT_ID (keyvault variable for terraform Service Principal)
 - ARM_CLIENT_SECRET (keyvault variable for terraform Service Principal)
 - ARM_TENANT_ID (keyvault variable for terraform Service Principal)
 - ARM_ACCESS_KEY (keyvault variable for storage account blob storage for tfstate)
 - TF_VAR_resource_group (Coding Challenge Resource Group Name)
 - TF_VAR_vnet1 (Coding Challenge Virtual Network Name)
 - TF_VAR_subnet1 (Coding Challenge Subnet Name)
 - TF_VAR_adminpassword (keyvault variable for Linux VM adminuser)
 - TF_VAR_vm1_name (Coding Challenge Linux VM Name)
 - TF_VAR_vm1_size (Coding Challenge Linux VM Size ex. Standard_F2)
 - TF_VAR_vm1_publisher (Coding Challenge Linux VM Publisher ex. OpenLogic)
 - TF_VAR_vm1_sku (Coding Challenge Linux VM SKU ex. 7.7)
 - TF_VAR_vm1_offer (Coding Challenge Linux VM Offer ex. CentOS)
 - TF_VAR_vm1_version (Coding Challenge Linux VM Version ex. latest)
 - TF_VAR_failover_location (Future Use fox Coding Challenge Cosmos DB Account HA Deployment Across Regions ex. westus)
 - TF_VAR_db_type (Coding Challenge Cosmos DB type ex. sql, mongo, or gremlin)

Terraform Deployment Code
=========================
**Filename:**  terraform/deployment/main.tf   

**Usage:**  The az.tools/terraform.sh script changes into the terraform/deployments/ directory before running terraform init and terraform [apply | destroy]

**Design Decisions / Limitations:**
 -  The tfstate file is stored in an Azure Storage Account for security of sensitive data
 -  The requirement to output some variables was hampered by terraform restrictions for output on "sensitive" variables. Future work to store sensitive output in Keyvault
 -  VNET Peering is setup (in the terraform code) between the Virtual Network for the Devops Agent and Coding Challenge VM in order to execute groupadd / useradd commands during deployment of the Linux VM
 -  The Cosmos DB account is setup in westus region because eastus and eastus2 locations were reporting no resources available to configure the account 
