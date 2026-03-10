# HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificates, and tokens. You might also need agreements with the supplier before implementing this connector. Please contact the client's application manager to coordinate connector requirements.

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
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Requirements
1. **HelloID Environment**:
   - Set up your _HelloID_ environment.
2. **Entra ID**:
   - App registration with `API permissions` of the type `Application`:
      -  `User.ReadWrite.All`
   - The following information for the app registration is needed in HelloID:
      - `Application (client) ID`
      - `Directory (tenant) ID`
      - `Secret Value`
3. **AFAS Profit**:
   - AFAS tenant id
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

By using this delegated form, you gain the ability to update the UPN and Email in Active Directory and AFAS Profit. The following options are available:
 1. Search and select the target Active Directory user account
 2. Enter new values for the following Active Directory user account attributes: UserPrincipalName and EmailAddress
 3. The entered UserPrincipalName and EmailAddress are validated
 4. Active Directory user account [UserPrincipalName and EmailAddress] and AFAS employee [EmAd] attribute are updated with new values
 5. Writing back [EmAd] in AFAS will be skiped if the employee is not found in AFAS

#### Endpoints
AFAS Profit provides a set of REST APIs that allow you to programmatically interact with its data.. The API endpoints listed in the table below are used.

| Endpoint                      | Description   |
| ----------------------------- | ------------- |
| profitrestservices/connectors | AFAS endpoint |

#### Form Options
The following options are available in the form:

1. **Lookup user**:
   - This Powershell data source runs an Active Directory query to search for matching AD user accounts. It uses an array of Active Directory OU's specified as HelloID user-defined variable named _"ADusersSearchOU"_ to specify the search scope. This data source returns additional attributes that receive the current values for UserPrincipalName/EmailAddress.
2. **Validate UPN and Email**:
   - This Powershell data source runs an Active Directory query to validate the uniqueness of the new UserPrincipalName and EmailAddress. Both values are also validated in ProxyAddresses. And will return a "Valid" or "Invalid" text. This text is used for validation in the form.

#### Task Actions
The following actions will be performed based on user selections:

1. **Update UPN and Email in Active Directory**:
   - On the AD user account the attributes UserPrincipalName, EmailAddress and ProxyAddresses will be updated (old Primairy 'SMTP:' will be replaced by a alias 'smtp:').
2. **Update EmAd in AFAS Profit Employee**:
   - On the AFAS employee the attributes EmAd will be updated.
3. **Update EmAd in AFAS Profit User**:
   - On the AFAS employee the attributes EmAd and/or Upn will be updated.

## Connector Setup
### Variable Library - User Defined Variables
The following user-defined variables are used by the connector. Ensure that you check and set the correct values required to connect to the API.

| Setting           | Description                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------------- |
| `ADusersSearchOU` | Array of Active Directory OUs for scoping AD user accounts in the search result of this form |
| `AFASBaseUrl`     | The URL to the AFAS environment REST service                                                 |
| `AFASToken`       | The password to the P12 certificate of your service account                                  |

## Getting help
> [!TIP]
> _For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/