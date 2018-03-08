function Get-DbaOrphanedSecurityGroup {
<#
        .SYNOPSIS
            Get-DbaOrphanedSecurityGroup compares groups in SQL Server to groups in Active Directory and indicates if a group is not
            in SQL Server but is in Active Directory or vice versa.

        .DESCRIPTION
            This function is designed to take in a server name(s) and group name(s) or pattern(s) and determine if groups are in AD that don't exist on the
            SQL Server instance or if groups are in the SQL Server instance that aren't in AD.

            The function will return a custom object(s) that contains the group name, whether or not it's in SQL Server, and whether or not it's in Active Directory.

        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to. This can be a collection to allow the function to be executed against multiple SQL Server instances.

        .PARAMETER CmsServer
            SQL Server name or SMO object representing the SQL Server CMS server to connect to. This can be a collection and to allow the function to be executed against multiple SQL Server instances.

        .PARAMETER ExcludeSqlInstance
            SQL Server names or SMO objects representing servers to exclude.

        .PARAMETER GroupFilter
            A pattern of groups to filter results down to (e.g. ADMIN-*). This can be a collection to allow matching against multiple patterns.

        .PARAMETER SqlCredential
            Credential object used to connect to the SQL Server Instance as a different user. This can be a Windows or SQL Server account. Windows users are determined by the existence of a backslash, so if you are intending to use an alternative Windows connection instead of a SQL login, ensure it contains a backslash.

        .NOTES
            Tags: Security
            Author: Andrew Wickham (@awickham), http://www.awickham.com

            Website: http://www.awickham.com
            Copyright: (C) Andrew Wickham, andrew@awickham.com
            License: MIT https://opensource.org/licenses/MIT

        .EXAMPLE
            Get-DbaOrphanedSecurityGroup -SqlInstance SQLSERVERA -GroupFilter ADMIN-*

            Connects to a SQL Server (SQLSERVERA) and gets a list of ADMIN-* groups. Queries Active Directory for a list of ADMIN-* groups
            and compares the results.

        .EXAMPLE
            Get-DbaOrphanedSecurityGroup -CmsServer SQLCMSA -GroupFilter ADMIN-*

            Gets a list of registered CMS servers on SQLCMSA then connects to each instance and gets a list of ADMIN-* groups. Queries Active
            Directory for a list of ADMIN-* groups and compares the results.

    #>
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param (
        [parameter(ParameterSetName = 'Server', Mandatory = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,

        [parameter(ParameterSetName = 'CMS', Mandatory = $true)]
        [DbaInstanceParameter[]]$CmsServer,

        [Parameter(ParameterSetName="CMS")]
        [string[]]$ExcludeSqlInstance = @(),

        [Parameter(Mandatory = $true)]
        [string[]]$GroupFilter,

        [Alias("Credential")]
        [PSCredential]$SqlCredential
    )

    begin {
        if (-not (Get-Module -Name 'dbatools' -ListAvailable)) {
            throw "dbatools module must be installed. Run Install-Module dbatools."
        }

        Import-Module -Name 'dbatools'

        $inUseGroups = @()
        $adGroups = @()
    }

    process {
        # get servers list
        $servers = switch ($PSCmdlet.ParameterSetName) {
            'Server' {
                dbatools\Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
            }
            'CMS' {
                dbatools\Get-DbaRegisteredServer -SqlInstance $CmsServer -SqlCredential $SqlCredential | Where-Object {
                    $_.Name -notin $ExcludeSqlInstance
                }
            }
        }

        foreach ($server in $servers) {
            Write-Verbose "Getting groups from $($server.Name)"

            # default filter
            $filterBlockString = "
                `$groupParts = `$_.Name.Split('\')
                `$_.LoginType -eq 'WindowsGroup' -and `$groupParts[0] -notin (`$_.ComputerName, 'BUILTIN', 'NT SERVICE') -and ("

            # add in GroupFilter
            $filterBlockParts = @()
            foreach ($groupFilterParam in $GroupFilter) {
                $filterBlockParts += "`$groupParts[1] -like '$groupFilterParam'"
            }
            $filterBlockString += ($filterBlockParts -join ' -or ') + ')'

            $filterBlock = [ScriptBlock]::Create($filterBlockString)

            # get groups for the instance
            $inUseGroups += dbatools\Get-DbaLogin -SqlInstance $server.Name -SqlCredential $SqlCredential | Where-Object $filterBlock | Select-Object -Property @(
                @{ Name = 'Name'; Expression = { $_.Name.Split('\')[1] }}
            )
        }
        $inUseGroups = $inUseGroups | Select-Object -ExpandProperty Name -Unique

        # get groups in AD
        $filter = @()
        foreach ($filterItem in $GroupFilter) {
            $filter += "SamAccountName -like '$filterItem'"
        }
        $filterString = $filter -join ' -or '

        $adGroups = Get-AdGroup -Filter $filterString | Select-Object -ExpandProperty Name
        if ($inUseGroups -and $adGroups) {
            $compare = Compare-Object $inUseGroups $adGroups

            foreach ($group in $compare) {
                [PSCustomObject]@{
                    'Name'              = $group.InputObject
                    'InSql'             = $group.SideIndicator -eq '<='
                    'InActiveDirectory' = $group.SideIndicator -eq '=>'
                }
            }
        }
    }
}