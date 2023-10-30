#######################################################################
# Template: RHo HelloID SA Powershell data source
# Name:     AD-AFAS-account-update-upn-email-validation
# Date:     24-10-2023
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources/add,-edit,-or-remove-a-powershell-data-source.html#add-a-powershell-data-source

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$outputText = [System.Collections.Generic.List[PSCustomObject]]::new()


# global variables (Automation --> Variable libary):
# $globalVar = $globalVarName

# variables configured in form:
$upnEmailEqual = $datasource.upnEmailEqual
$userSID = $dataSource.selectedUser.SID

$upnCurrent = $dataSource.selectedUser.UserPrincipalName
$upnPrefixNew = $datasource.upnPrefix
$upnSuffixCurrent = $datasource.upnSuffixCurrent
$upnSuffixNew = $datasource.upnSuffixNew
if ([string]::IsNullOrEmpty($upnSuffixNew)) {
    $upnNew = $upnPrefixNew + $upnSuffixCurrent
}
else {
    $upnNew = $upnPrefixNew + $upnSuffixNew
}

if ($upnEmailEqual -eq "True") {
    $emailOrUpnNew = $upnNew
}
else {
    $emailCurrent = $dataSource.selectedUser.EmailAddress
    $emailPrefixNew = $datasource.emailPrefix
    $emailSuffixCurrent = $datasource.emailSuffixCurrent
    $emailSuffixNew = $datasource.emailSuffixNew
    if ([string]::IsNullOrEmpty($emailSuffixNew)) {
        $emailOrUpnNew = $emailPrefixNew + $emailSuffixCurrent
    }
    else {
        $emailOrUpnNew = $emailPrefixNew + $emailSuffixNew
    }
}

#endregion init

#region functions
# function Remove-StringLatinCharacters {
#     PARAM ([string]$String)
#     [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
# }
#endregion functions

#region lookup
try {
    if ($upnCurrent -eq $upnNew) {
        $outputText.Add([PSCustomObject]@{
                Message  = "UPN [$upnCurrent] not changed"
                IsError  = $true
                Property = "UPN"
            })
    }

    if (($emailCurrent -eq $emailOrUpnNew)) {
        $outputText.Add([PSCustomObject]@{
                Message  = "Email [$emailCurrent] not changed"
                IsError  = $true
                Property = "Email"
            })
    }
    
    # $upnNew = Remove-StringLatinCharacters $upnNew
    # $emailOrUpnNew = Remove-StringLatinCharacters $emailOrUpnNew

    # $pattern = "^[a-zA-Z0-9_%+-]+(\.[a-zA-Z0-9_%+-]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    # if (-not($upnNew -match $pattern)) {
    #     $outputText.Add([PSCustomObject]@{
    #             Message  = "UPN [$upnNew] invalid character(s) or pattern"
    #             IsError  = $true
    #             Property = "UPN"
    #         })
    # }

    # if ((-not($emailOrUpnNew -match $pattern))) {
    #     $outputText.Add([PSCustomObject]@{
    #             Message  = "Email [$emailOrUpnNew] invalid character(s) or pattern"
    #             IsError  = $true
    #             Property = "Email"
    #         })
    # }

    if (-not($outputText.isError -contains - $true)) {
        write-information "no errors"
        
        if ($upnEmailEqual -eq "True") {
            $searchUpperCase = "SMTP:$upnNew"
            $searchLowerCase = "smtp:$upnNew"
    
            $adUserParams = @{
                # Filter     = { (EmailAddress -eq $upnNew -or ProxyAddresses -eq SMTP:$upnNew -or ProxyAddresses -eq smtp:$upnNew -or userPrincipalName -eq $upnNew) -and (SID -ne $userSID) }
                Filter     = { (EmailAddress -eq $upnNew -or ProxyAddresses -eq $searchUpperCase -or ProxyAddresses -eq $searchLowerCase -or userPrincipalName -eq $upnNew) -and (SID -ne $userSID) }
                Properties = 'ProxyAddresses', 'userPrincipalName', 'EmailAddress'
            }
        }
        else { 
            $searchUpperCaseUPN = "SMTP:$upnNew"
            $searchLowerCaseUPN = "smtp:$upnNew"
            $searchUpperCaseEmail = "SMTP:$emailOrUpnNew"
            $searchLowerCaseEmail = "smtp:$emailOrUpnNew"

            $adUserParams = @{
                Filter     = { (EmailAddress -eq $emailOrUpnNew -or ProxyAddresses -eq $searchUpperCaseUPN -or ProxyAddresses -eq $searchLowerCaseUPN -or ProxyAddresses -eq $searchUpperCaseEmail -or ProxyAddresses -eq $searchLowerCaseEmail -or userPrincipalName -eq $upnNew) -and (SID -ne $userSID) }
                Properties = 'ProxyAddresses', 'userPrincipalName', 'EmailAddress'
            }
        }

        $found = Get-ADUser @adUserParams

        write-information "FOUND [$($found | Convertto-json)]"


        foreach ($record in $found) {
            if ($record.UserPrincipalName -eq $upnNew) {
                $outputText.Add([PSCustomObject]@{
                        Message  = "UPN [$upnNew] not unique, found on [$($record.Name)]"
                        IsError  = $true
                        Property = "UPN"
                    })
            }
            if ($record.EmailAddress -eq $emailOrUpnNew) {
                $outputText.Add([PSCustomObject]@{
                        Message  = "Email [$emailOrUpnNew] not unique, found on [$($record.Name)]"
                        IsError  = $true
                        Property = "Email"
                    })
            }
            elseif (($record.ProxyAddresses -eq "SMTP:$emailOrUpnNew") -or ($record.ProxyAddresses -eq "smtp:$emailOrUpnNew")) {
                $outputText.Add([PSCustomObject]@{
                        Message  = "ProxyAddress [$emailOrUpnNew] not unique, found on [$($record.Name)]"
                        IsError  = $true
                        Property = "ProxyAddress"
                    })
            }
            elseif (($record.ProxyAddresses -eq "SMTP:$upnNew") -or ($record.ProxyAddresses -eq "smtp:$upnNew") -and ($upnNew -ne $emailOrUpnNew)) {
                $outputText.Add([PSCustomObject]@{
                        Message  = "ProxyAddress [$upnNew] not unique, found on [$($record.Name)]"
                        IsError  = $true
                        Property = "ProxyAddress"
                    })
            }
            
            # Write-Information "UserPrincipalName [$($record.UserPrincipalName)]"
            # Write-Information "EmailAddress [$($record.EmailAddress)]"
            # Write-Information "ProxyAddresses [$($record.ProxyAddresses)]"
            # Write-Information "DistinguishedName [$($record.DistinguishedName)]"
        }

        # if (-not($outputText.Property -contains "UPN")) {
        #     $outputText.Add([PSCustomObject]@{
        #             Message  = "UPN [$upnNew] unique"
        #             IsError  = $false
        #             Property = "UPN"
        #         })
        # }
        # if (-not($outputText.Property -contains "Email")) {
        #     $outputText.Add([PSCustomObject]@{
        #             Message  = "Email [$emailOrUpnNew] unique"
        #             IsError  = $false
        #             Property = "Email"
        #         })
        # }
        # if (-not($outputText.Property -contains "ProxyAddress")) {
        #     $outputText.Add([PSCustomObject]@{
        #             Message  = "ProxyAddress [$emailOrUpnNew] unique"
        #             IsError  = $false
        #             Property = "ProxyAddress"
        #         })
        # }
    }

    if ($outputText.isError -contains - $true) {
        $outputMessage = "Invalid"
    }
    else {
        $outputMessage = "Valid"
        $outputText.Add([PSCustomObject]@{
                Message  = "UPN [$upnNew] unique"
                IsError  = $false
                Property = "UPN"
            })
        $outputText.Add([PSCustomObject]@{
                Message  = "Email [$emailOrUpnNew] unique"
                IsError  = $false
                Property = "Email"
            })
    }

    foreach ($text in $outputText) {
        $outputMessage += " | " + $($text.Message)
    }

    $returnObject = @{
        text              = $outputMessage
        userPrincipalName = $upnNew
        emailAddress      = $emailOrUpnNew
    }

    Write-Output $returnObject      
}
catch {
    $ex = $PSItem
    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        
    Write-Error "Error querying data. Error Message: $($_ex.Exception.Message)" 
}
#endregion lookup
