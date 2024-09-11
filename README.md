# HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email](#helloid-conn-sa-full-ad-afas-update-upn-email)
  - [Table of contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Remarks](#remarks)
  - [Introduction](#introduction)
      - [Description](#description)
      - [Endpoints](#endpoints)
      - [Form Options](#form-options)
      - [Task Actions](#task-actions)
  - [Connector Setup](#connector-setup)
    - [Variable Library - User Defined Variables](#variable-library---user-defined-variables)
  - [Description](#description-1)
  - [All-in-one PowerShell setup script](#all-in-one-powershell-setup-script)
    - [Getting started](#getting-started)
  - [Post-setup configuration](#post-setup-configuration)
  - [Manual resources](#manual-resources)
    - [Powershell data source 'AD-AFAS-account-update-upn-email-lookup-user-generate-table'](#powershell-data-source-ad-afas-account-update-upn-email-lookup-user-generate-table)
    - [Powershell data source 'AD-AFAS-account-update-upn-email-validation'](#powershell-data-source-ad-afas-account-update-upn-email-validation)
  - [Add another systems to update](#add-another-systems-to-update)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Requirements
1. **HelloID Environment**:
   - Set up your _HelloID_ environment.
   - Install the _HelloID_ Service Automation agent (on-prem).
2. **Active Directory**:
   - Service account that is running the agent has `Account Operators` rights
3. **AFAS Profit**:
   - AFAS tennant id
   - AppConnector token
   - Loaded AFAS GetConnector
     - Tools4ever - HelloID - T4E_HelloID_Users_v2.gcn
     - https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Employees
   - Build-in Profit update connector: KnEmployee

## Remarks
- None at this time.

## Introduction

#### Description
_HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email_ is a template designed for use with HelloID Service Automation (SA) Delegated Forms. It can be imported into HelloID and customized according to your requirements. 

By using this delegated form, you gain the ability to update the UPN and Email in Active Directory and AFAS Profit.

#### Endpoints
AFAS Profit provides a set of REST APIs that allow you to programmatically interact with its data.. The API endpoints listed in the table below are used.

| Endpoint                      | Description   |
| ----------------------------- | ------------- |
| profitrestservices/connectors | AFAS endpoint |

#### Form Options
The following options are available in the form:

1. **Lookup user**:
   - This Powershell data source runs an Active Directory query to search for matching AD user accounts. It uses an array of Active Directory OU's specified as HelloID user-defined variable named _"ADusersSearchOU"_ to specify the search scope. This data source returns additional attributes that receive the current values for UserPrincipalName/EmailAddress and also split them into a prefix and a suffix for future uses.
2. **Validate UPN and Email**:
   - This Powershell data source runs an Active Directory query to validate the uniqueness of the new UserPrincipalName and EmailAddress. Both values are also validated in ProxyAddresses. And will return a "Valid" or "Invalid" text. This text is used for validation in the form.

#### Task Actions
The following actions will be performed based on user selections:

1. **Update UPN and Email in Active Directory**:
   - On the AD user account the attributes UserPrincipalName, EmailAddress and ProxyAddresses will be updated (old Primairy 'SMTP:' will be replaced by a alais 'smtp:').
2. **Update EmAd in AFAS Profit Employee**:
   - On the AFAS employee the attributes EmAd will be updated.

## Connector Setup
### Variable Library - User Defined Variables
The following user-defined variables are used by the connector. Ensure that you check and set the correct values required to connect to the API.

| Setting           | Description                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------------- |
| `ADusersSearchOU` | Array of Active Directory OUs for scoping AD user accounts in the search result of this form |
| `AFASBaseUrl`     | The URL to the AFAS environment REST service                            |
| `AFASToken`       | The password to the P12 certificate of your service account                                  |


For example, `[{ "OU": "OU=Disabled Users,OU=Training,DC=domain,DC=com"},{ "OU": "OU=Users,OU=Training,DC=domain,DC=com"}]`
For example, `https://yourtennantid.rest.afas.online/profitrestservices`


## Description
This HelloID Service Automation Delegated Form provides updates for user principal name and email on an AD user account and AFAS employee. The following options are available:
 1. Search and select the target AD user account
 2. Enter new values for the following AD user account attributes: UserPrincipalName and EmailAddress
 3. The entered UserPrincipalName and EmailAddress are validated
 4. AD user account [UserPrincipalName and EmailAddress] and AFAS employee [EmAd] attribute are updated with new values
 5. Writing back [EmAd] in AFAS will be skiped if the employee is not found in AFAS




## All-in-one PowerShell setup script
The PowerShell script "createform.ps1" contains a complete PowerShell script using the HelloID API to create the complete Form including user-defined variables, tasks and data sources.

 _Please note that this script assumes none of the required resources do exist within HelloID. The script does not contain versioning or source control_


### Getting started
Please follow the documentation steps on [HelloID Docs](https://docs.helloid.com/en/github-resources/service-automation-github-resources.html) in order to set up and run the All-in-one Powershell Script in your own environment.

 
## Post-setup configuration
After the all-in-one PowerShell script has run and created all the required resources. The following items need to be configured according to your own environment
 1. Update the following [user-defined variables](https://docs.helloid.com/en/variables/custom-variables.html)
<table>
  <tr><td><strong>Variable name</strong></td><td><strong>Example value</strong></td><td><strong>Description</strong></td></tr>
  <tr><td>ADusersSearchOU</td><td>[{ "OU": "OU=Disabled Users,OU=HelloID Training,DC=veeken,DC=local"},{ "OU": "OU=Users,OU=HelloID Training,DC=veeken,DC=local"}]</td><td>Array of Active Directory OUs for scoping AD user accounts in the search result of this form</td></tr>
  <tr><td>AFASBaseUrl</td><td>https://yourtennantid.rest.afas.online/profitrestservices</td><td>The URL to the AFAS environment REST service</td></tr>
  <tr><td>AFASToken</td><td>< token>< version>1< /version>< data>yourtoken< /data>< /token></td><td>The AppConnector token to connect to AFAS</td></tr>
</table>

## Manual resources
This Delegated Form uses the following resources in order to run

### Powershell data source 'AD-AFAS-account-update-upn-email-lookup-user-generate-table'
This Powershell data source runs an Active Directory query to search for matching AD user accounts. It uses an array of Active Directory OU's specified as HelloID user-defined variable named _"ADusersSearchOU"_ to specify the search scope. This data source returns additional attributes that receive the current values for UserPrincipalName/EmailAddress and also split them into a prefix and a suffix for future uses.

### Powershell data source 'AD-AFAS-account-update-upn-email-validation'
This Powershell data source runs an Active Directory query to validate the uniqueness of the new UserPrincipalName and EmailAddress. Both values are also validated in ProxyAddresses. And will return a "Valid" or "Invalid" text. This text is used for validation in the form.


## Add another systems to update
It is possible to add another systems to update the UserPrincipalName and EmailAddress by adding them in the task script. It is also possible to send a [email](https://docs.helloid.com/en/service-automation/products/product-tasks.html#email-sends-in-powershell-product-tasks) with the task script.

## Getting help
_If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/service-automation/)_

## HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
