# iac-coding-challenge

Overview
========
This repository contains files needed to configure Azure Devops Pipelines and Terraform script to create and destroy resources for the Coding Challenge infrastructure. 

Pre-requisites / Azure Resources Managed Outside of this deployment
===================================================================

 - Azure DevOps Agent on Linux VM
 - Service Principal with Subscription level access to create and destroy resources
 - Storage Account to save Terraform tfstate
 - Key Vault to store
           - Azure Subscription level Service Principal Connection Secrets
           - Access Key to the Blob Storage Account for tfstate
           - Linux VM adminuser password
- az.tools Github repo with bash script for terraform apply / destroy

Azure Devops Pipeline
=====================
**Filename**  azure-pipelines.yaml
**Usage**  This file can be used to configure both a resource deployment and resource delete pipeline for the Coding Challenge. The resource deployment pipeline should be configured / run with an Azure Devops UI varialbe "ACTION = apply". The resource delete pipeline should be configured / run with an Azure Devops UI variable ACTION = destroy.



Environment Variable List:
    ARM_SUBSCRIPTION_ID: $(kv-arm-subscription-id)
    ARM_CLIENT_ID:       $(kv-arm-client-id)
    ARM_CLIENT_SECRET:   $(kv-arm-client-secret)
    ARM_TENANT_ID:       $(kv-arm-tenant-id)
    ARM_ACCESS_KEY:      $(kv-arm-access-key)
    TF_VAR_resource_group: rg-cc-dev
    TF_VAR_vnet1: vnet1-cc-dev
    TF_VAR_subnet1: subnet1-cc-dev
    TF_VAR_adminpassword: $(kv-adminuser-password)
    TF_VAR_vm1_name: vm-cc-dev-1
    TF_VAR_vm1_size: Standard_F2
    TF_VAR_vm1_publisher: OpenLogic
    TF_VAR_vm1_sku: 7.7
    TF_VAR_vm1_offer: CentOS
    TF_VAR_vm1_version: latest
    TF_VAR_failover_location: westus
    TF_VAR_db_type: sql
