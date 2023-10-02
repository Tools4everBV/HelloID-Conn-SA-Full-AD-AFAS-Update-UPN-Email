<!-- Description -->
## Description
This HelloID Service Automation Delegated Form provides updates for user principal name and email on an AD user account and AFAS employee. The following options are available:
 1. Search and select the target AD user account
 2. Show basic AD user account attributes of the selected target user
 3. Enter new values for the following AD user account attributes: UserPrincipalName and EmailAddress
 4. The entered UserPrincipalName and EmailAddress are validated
 5. AD user account [UserPrincipalName and EmailAddress] and AFAS employee [EmAd] attribute are updated with new values
 6. Writing back [EmAd] in AFAS will be skiped if the employee is not found in AFAS

## Versioning
| Version | Description   | Date       |
| ------- | ------------- | ---------- |
| 1.0.0   | First release | 2023/09/26 |

<!-- TABLE OF CONTENTS -->
## Table of Contents
- [Description](#description)
- [Versioning](#versioning)
- [Table of Contents](#table-of-contents)
- [All-in-one PowerShell setup script](#all-in-one-powershell-setup-script)
  - [Getting started](#getting-started)
- [Post-setup configuration](#post-setup-configuration)
- [Manual resources](#manual-resources)
  - [Powershell data source 'AD-AFAS-account-update-upn-email-lookup-user-generate-table'](#powershell-data-source-ad-afas-account-update-upn-email-lookup-user-generate-table)
  - [Powershell data source 'AD-AFAS-account-update-upn-email-table-user-details'](#powershell-data-source-ad-afas-account-update-upn-email-table-user-details)
  - [Powershell data source 'AD-AFAS-account-update-upn-email-validate-upn'](#powershell-data-source-ad-afas-account-update-upn-email-validate-upn)
  - [Powershell data source 'AD-AFAS-account-update-upn-email-validate-email'](#powershell-data-source-ad-afas-account-update-upn-email-validate-email)
  - [Delegated form task 'AD AFAS Account - Update UPN - Email'](#delegated-form-task-ad-afas-account---update-upn---email)
- [Add another systems to update](#add-another-systems-to-update)
- [Getting help](#getting-help)
- [HelloID Docs](#helloid-docs)


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

### Powershell data source 'AD-AFAS-account-update-upn-email-table-user-details'
This Powershell data source runs an Active Directory query to select an extended list of user attributes of the selected AD user account. 

### Powershell data source 'AD-AFAS-account-update-upn-email-validate-upn'
This Powershell data source runs an Active Directory query to validate the uniqueness of the new UserPrincipalName. And will return a "Valid" or "Invalid" text. This text is used for validation in the form.

### Powershell data source 'AD-AFAS-account-update-upn-email-validate-email'
This Powershell data source runs an Active Directory query to validate the uniqueness of the new EmailAddress. The new EmailAddress is validated in EmailAddress and ProxyAddresses. And will return a "Valid" or "Invalid" text. This text is used for validation in the form.

### Delegated form task 'AD AFAS Account - Update UPN - Email'
This delegated form task will update two systems. On the AD user account the attributes UserPrincipalName, EmailAddress and ProxyAddresses will be updated (old Primairy 'SMTP:' will be replaced by a alais 'smtp:'). On the AFAS employee the attributes EmAd will be updated.

## Add another systems to update
It is possible to add another systems to update the UserPrincipalName and EmailAddress by adding them in the task script. It is also possible to send a [email](https://docs.helloid.com/en/service-automation/products/product-tasks.html#email-sends-in-powershell-product-tasks) with the task script.

## Getting help
_If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/service-automation/)_

## HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
