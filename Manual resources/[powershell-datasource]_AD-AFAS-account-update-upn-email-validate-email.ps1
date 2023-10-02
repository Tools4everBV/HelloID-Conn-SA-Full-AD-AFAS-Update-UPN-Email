#######################################################################
# Template: RHo HelloID SA Powershell data source
# Name:     AD-AFAS-account-update-upn-email-validate-email
# Date:     26-09-2023
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources/add,-edit,-or-remove-a-powershell-data-source.html#add-a-powershell-data-source

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# global variables (Automation --> Variable libary):
# $globalVar = $globalVarName

# variables configured in form:

$emailSelectedUser = $dataSource.selectedUser.EmailAddress
$upnSelectedUser = $dataSource.selectedUser.UserPrincipalName


$upnEmailEqual = $datasource.upnEmailEqual

if ($upnEmailEqual -eq "True") {
    $emailPrefix = $datasource.upnPrefix
    $emailSuffixCurrent = $datasource.upnSuffixCurrent
    $emailSuffixNew = $datasource.upnSuffixNew
}
else {
    $emailPrefix = $datasource.emailPrefix
    $emailSuffixCurrent = $datasource.emailSuffixCurrent
    $emailSuffixNew = $datasource.emailSuffixNew
}

#endregion init

#region functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}
#endregion functions

#region lookup
try {
    if ([string]::IsNullOrEmpty($emailSuffixNew)) {
        $email = $emailPrefix + $emailSuffixCurrent
    }
    else {
        $email = $emailPrefix + $emailSuffixNew
    }

    $email = Remove-StringLatinCharacters $email

    # Define a regular expression pattern for a valid email
    $pattern = "^[a-zA-Z0-9_%+-]+(\.[a-zA-Z0-9_%+-]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if ($email -match $pattern) {
        if ($emailSelectedUser -eq $email) {
            $returnObject = @{
                text         = "Invalid | Email [$emailSelectedUser] not changed"
                emailAddress = $email
            }
        }
        else {
            $found = Get-ADUser -Filter { EmailAddress -eq $email }
            if (@($found).count -eq 0) {
                $searchLowerCaseSmtp = "smtp:$email"
                $searchUpperCaseSmtp = "SMTP:$email"
            
                $foundProxyAddresses = Get-ADUser -Filter { ProxyAddresses -eq $searchUpperCaseSmtp -or ProxyAddresses -eq $searchLowerCaseSmtp } -properties UserPrincipalName
                if ((@($foundProxyAddresses).count -gt 0) -and ($upnSelectedUser -ne $foundProxyAddresses.UserPrincipalName)) {
                    $returnObject = @{
                        text         = "Invalid | ProxyAddresses [$email] not unique"
                        emailAddress = $email
                    }
                }
                else {
                    $returnObject = @{
                        text         = "Valid | Email [$email] unique"
                        emailAddress = $email
                    }
                }
            }
            else {
                $returnObject = @{
                    text         = "Invalid | Email [$email] not unique"
                    emailAddress = $email
                }
            }   
        }
    }
    else {
        $returnObject = @{
            text         = "Invalid | Email [$email] invalid character(s) or pattern"
            emailAddress = $email
        }
    }

    Write-Output $returnObject      
}
catch {
    $ex = $PSItem
    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        
    Write-Error "Error querying data. Error Message: $($_ex.Exception.Message)" 
}
#endregion lookup
