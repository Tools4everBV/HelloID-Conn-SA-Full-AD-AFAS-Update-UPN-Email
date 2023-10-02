#######################################################################
# Template: RHo HelloID SA Powershell data source
# Name:     AD-AFAS-account-update-upn-email-validate-upn
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
$upnPrefix = $datasource.upnPrefix
$upnSuffixCurrent = $datasource.upnSuffixCurrent
$upnSuffixNew = $datasource.upnSuffixNew
$upnSelectedUser = $dataSource.selectedUser.UserPrincipalName

#endregion init

#region functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}
#endregion functions

#region lookup
try {
    if ([string]::IsNullOrEmpty($upnSuffixNew)) {
        $upn = $upnPrefix + $upnSuffixCurrent
    }
    else {
        $upn = $upnPrefix + $upnSuffixNew
    }

    $upn = Remove-StringLatinCharacters $upn

    # Define a regular expression pattern for a valid UPN
    $pattern = "^[a-zA-Z0-9_%+-]+(\.[a-zA-Z0-9_%+-]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if ($upn -match $pattern) {
        if ($upnSelectedUser -eq $upn) {
            $returnObject = @{
                text              = "Invalid | UPN [$upnSelectedUser] not changed"
                userPrincipalName = $upn
            }
        }
        else {
            $found = Get-ADUser -Filter { userPrincipalName -eq $upn }
    
            if (@($found).count -eq 0) {
                $returnObject = @{
                    text              = "Valid | UPN [$upn] unique"
                    userPrincipalName = $upn
                }
            }
            else {
                $returnObject = @{
                    text              = "Invalid | UPN [$upn] not unique"
                    userPrincipalName = $upn
                }
            }
            
        }
    }
    else {
        $returnObject = @{
            text              = "Invalid | UPN [$upn] invalid character(s) or pattern"
            userPrincipalName = $upn
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
