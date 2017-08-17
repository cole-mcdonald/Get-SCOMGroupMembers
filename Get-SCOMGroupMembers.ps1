function Get-SCOMGroupMembers {
    # (c)2017, Beyond Impact 2.0, LLC
    # All rights reserved
    # No claim to copyright is made for original U.S. Government Works.
    # coded by: Cole McDonald

    param (
        [Microsoft.EnterpriseManagement.Monitoring.MonitoringObjectGroup]$GroupObject,
        [System.Collections.ArrayList]$endMembers,
        [string]$ManagementServer,
        [string]$GroupName,
        [switch]$verbose
    )
    
    $oldVerbose = $VerbosePreference
    if ($verbose) {
        $VerbosePreference = "continue"
    }
    Write-Verbose "`n!!! - Calling Parameters: $ManagementServer, $GroupName, $Verbose, $($GroupObject.DisplayName) - !!!"
    write-verbose "testing for output array"
    # Initialize output array if not sent
    if (!$endMembers) {
        [system.collections.arraylist]$endMembers = @()
    }
    # If the group object is empty and is sent in by name, get the group object from SCOM
    write-verbose "Checking to see if we are using an object or need to fetch the object from SCOM"
    if (!$GroupObject) {
        write-verbose "- fetching object from SCOM"
        if (!$ManagementServer -or !$GroupName) {
            # Not enough inormation to contact SCOM
            write-verbose "- Error gathering from SCOM, returning false"
            $VerbosePreference = $oldVerbose
            return $false
        } else {
            try {
                write-verbose "- Gathering SCOM Data for $GroupName from $ManagementServer"
                $GroupObject = Get-SCOMGroup -ComputerName $ManagementServer | Where-Object DisplayName -like "*$GroupName*"
            } catch {
                write-verbose "- Error gathering from SCOM, returning false"
                $VerbosePreference = $oldVerbose
                return $false
            }
        }
    } else {
        Write-Verbose "- $($GroupObject.displayName) received as an object from the caller"
    }
    # Get members of the object
    write-verbose "Getting groups from object"
    $GroupMembers = $GroupObject.GetChildMonitoringObjectGroups()
    if ($GroupMembers.Count -gt 0) { 
        Write-Verbose "Looping through $($GroupMembers.count) Items"
        foreach ($GroupMember in $GroupMembers) {
            ## Time to get recursive with it
            $endMembers = Get-SCOMGroupMembers `
                -ManagementServer $ManagementServer `
                -GroupObject $GroupMember `
                -GroupName $GroupMember.displayname `
                -endMembers $endMembers `
                | Where-Object { $PSItem.GetType().name -eq "MonitoringObject" }
            Write-Verbose "Received $($endMembers.count) members from recursion"
        }
    }
    # Here is where we add the objects the Group knows about to the $endMembers array
    write-verbose "Getting class instances from group"
    try {
        $instances = $GroupObject `
            | Get-SCOMClassInstance -ComputerName $ManagementServer `
            | Where-Object { $PSItem.GetType().name -eq "MonitoringObject" }
        Write-Verbose "- Found $($instances.count) Instances"
        if ($instances.count -gt 0) {
            Write-Verbose "*** Adding $($instances.count) from the Group $($GroupObject.displayname)"
            $instances `
                | foreach {
                    $endMembers.Add( $PSItem )
                    write-verbose "- - $($PSItem.displayname)"
                }
        }
    } catch {
        write-verbose "- Problem fetching instances... Incorrect management server sent? $ManagementServer"
        $VerbosePreference = $oldVerbose
        return $false
    }
    # Time to return our amazing results to the caller
    Write-Verbose "Returning $($endMembers.count) to the caller"
    if ($endMembers.Count -gt 0) {
        # If not empty, Return Array
        $VerbosePreference = $oldVerbose
        # Strip out non-monitor object entries
        return $endMembers
    } else {
        # Else return $False
        $VerbosePreference = $oldVerbose
        return $false
    }
}