<#
.SYNOPSIS
    Retrieves the access token for the Azure REST API.
.DESCRIPTION
    Grabs the Access Token for the Azure REST API.
    This library can accept a subscription ID for tenant identification.
    Otherwise, it takes the first subscription and uses the associated tenant ID.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    This script requires the Az.Accounts module to be installed.
#>
#Requires -Modules Az.Accounts

$Account = Connect-AzAccount
$TenantID = (Get-AzSubscription -SubscriptionId "e5b8499c-217c-4eef-b3e8-4942085b6a51").TenantId
$Tokens = $account.Context.TokenCache.ReadItems()
[CmdletBinding(DefaultParameterSetName='TenantID')]
param(
    # Accepts a user account context session, otherwise establishes its own session
    [Parameter(
        Mandatory = $false,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Account context"
    )]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.Commands.Profile.Models.Core.PSAzureProfile]$Account = (Connect-AzAccount),
    # Accepts a Tenant ID, does not require subscription id if specified
    [Parameter(
        Mandatory = $false,
        Position = 1,
        ParameterSetName = "TenantID",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Tenant ID to get access token for"
    )]
    [ValidateNotNullOrEmpty()]
    [System.Guid]$TenantID,
    # Accepts a subscription id to use as the reference to retrieve the tenant id for
    [Parameter(
        Mandatory = $false,
        Position = 1,
        ParameterSetName = "SubscriptionID",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Subscription ID to get tenant ID for tenant id extraction"
    )]
    [ValidateNotNullOrEmpty()]
    [System.Guid]$SubscriptionID = (Get-AzSubscription)[0].Id
)
$FilteredTokens = $Tokens | Where-Object -FilterScript {$_.TenantId -eq $TenantID} | Sort-Object -Property ExpiresOn -Descending


# Extract the access token
$AccessToken = $FilteredTokens[0].AccessToken


# Return the access token
return $AccessToken