# HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificates, and tokens. You might also need agreements with the supplier before implementing this connector. Please contact the client's application manager to coordinate connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email/blob/main/Logo.png?raw=true">
</p>

## Description

HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email is a template designed for use with HelloID Service Automation (SA) Delegated Forms. It can be imported into HelloID and customized according to your requirements.

By using this delegated form, you can update User Principal Name (UPN) and Email attributes in Active Directory and AFAS Profit. The following options are available:

1. Search and select the target Active Directory user account
2. Enter new values for UserPrincipalName and EmailAddress
3. Validate uniqueness of UserPrincipalName and EmailAddress in Active Directory
4. Update UserPrincipalName, EmailAddress, and ProxyAddresses in Active Directory
5. Update EmAd in AFAS Employee and EmAd/Upn in AFAS User when a matching employee is found

## Getting started

### Requirements

#### Active Directory setup

Before implementing this connector, make sure the HelloID Agent runs under an account with sufficient rights to update Active Directory user attributes.

Recommended permissions:

- Account Operators rights (or equivalent delegated rights) to update:
  - UserPrincipalName
  - EmailAddress
  - ProxyAddresses

#### AFAS setup

Ensure AFAS Profit is configured with:

- AFAS tenant id
- AFAS AppConnector token
- Loaded AFAS GetConnector:
  - Tools4ever - HelloID - T4E_HelloID_Users_v2.gcn
  - https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Employees
- Built-in Profit update connectors:
  - KnEmployee
  - KnUser

#### HelloID-specific configuration

Once you have completed the Active Directory and AFAS setup, configure the following HelloID-specific requirements:

- Configure the user-defined variables listed in Connection settings
- Import and configure the delegated form and task scripts

### Connection settings

The following user-defined variables are used by the connector and should be configured in HelloID Service Automation (Automation -> Variable library).

| Variable Name   | Description                                                                                               | Required |
| --------------- | --------------------------------------------------------------------------------------------------------- | -------- |
| ADusersSearchOU | Array of Active Directory OUs used to scope user search results                                           | Yes      |
| AFASBaseUrl     | The base URL to the AFAS Profit REST API (for example: https://12345.rest.afas.online/profitrestservices) | Yes      |
| AFASToken       | The AppConnector token for AFAS Profit authentication                                                     | Yes      |

## Remarks

### Uniqueness validation

- The form validates uniqueness for UserPrincipalName and EmailAddress before updating.
- Validation checks both direct attributes and ProxyAddresses.
- The selected user itself is excluded from the uniqueness check.

### ProxyAddresses behavior

- When the primary SMTP value changes, the previous primary address (SMTP:) is converted to an alias (smtp:).
- This preserves historical aliases while setting the new primary address.

### AFAS employee matching

- AFAS updates depend on a valid EmployeeID correlation between Active Directory and AFAS.
- If no matching AFAS employee is found, AFAS updates are skipped while Active Directory updates can still proceed.

### AFAS target objects

- AFAS Employee connector updates EmAd.
- AFAS User connector updates EmAd and/or Upn.

## Development resources

### Endpoints and operations

The following operations are used by the connector:

| Operation                                     | Purpose                                                    |
| --------------------------------------------- | ---------------------------------------------------------- |
| Active Directory (Get-ADUser)                 | Search and retrieve Active Directory users                 |
| Active Directory (Set-ADUser)                 | Update UserPrincipalName, EmailAddress, and ProxyAddresses |
| {AFASBaseUrl}/connectors/T4E_HelloID_Users_v2 | Retrieve AFAS employee information                         |
| {AFASBaseUrl}/connectors/KnEmployee           | Update AFAS employee EmAd                                  |
| {AFASBaseUrl}/connectors/KnUser               | Update AFAS user EmAd and/or Upn                           |

### API and cmdlet documentation

- Active Directory Get-ADUser: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser
- Active Directory Set-ADUser: https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-aduser
- AFAS Profit REST API Documentation: https://help.afas.nl/help/NL/SE/App_Cnr_Rest_Updconnectors.htm

## Getting help
> [!TIP]
> _For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

## Additional Links

- Code: https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email
- Issues: https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email/issues
- Pull requests: https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email/pulls
- Actions: https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email/actions
- Security and quality: https://github.com/Tools4everBV/HelloID-Conn-SA-Full-AD-AFAS-Update-UPN-Email/security