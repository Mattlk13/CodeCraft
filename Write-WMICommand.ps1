function Write-WmiCommand
{
    <#
    .Synopsis
        Writes a WMI command
    .Description
        Generates the code for a new WMI function to get a class
    .Example
        # Create a function to get to Win32_Process 
        Write-WmiCommand Win32_Process
    .Example
        # Create a function to get to Win32_Process 
        Invoke-Expression (Write-WmiCommand Win32_Process)
    .Link
        Get-WmiObject
    #>
    [OutputType([string])]
    param(
    # The WMI Class to retreive
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$WMIClass, 
    # The namepace where the WMI class will be found
    #|default root\cimv2
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$Namespace = "root\cimv2"
    )
    
    process {
        #region Strip Command Metadata
        $wmiCommandMetaData = [Management.Automation.CommandMetaData](Get-Command Get-WmiObject)
        $null = $wmiCommandMetaData.Parameters.Remove('Class')
		$null = $wmiCommandMetaData.Parameters.Remove('Recurse')
		$null = $wmiCommandMetaData.Parameters.Remove('List')
		$null = $wmiCommandMetaData.Parameters.Remove('Query')
		$null = $wmiCommandMetaData.Parameters.Remove('Namespace')
		$null = $wmiCommandMetaData.Parameters.Remove('Property')
		$null = $wmiCommandMetaData.Parameters.Remove('Filter')
        $paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($wmiCommandMetaData)
        #endregion Strip Command Metadata
        
        #region Generate Function
        $functionName = "Get-$($wmiclass.Replace('_', ''))"
        
        "function $functionName {
    <#
    .Synopsis
        Gets $wmiClass from WMI
    .Description
        Gets instances of the $wmiClass in the WMI namespace $namespace
    .Example
        $functionName
    .Link
        Get-WmiObject        
    .Link
        http://CodeCraft.Start-Automating.Com
    #>
    [CmdletBinding(DefaultParameterSetName='Class')]
    param($paramBlock)

    process {
	   `$wmiParams = @{
		  Class='$wmiClass'
            Namespace='$namespace'
	   } + `$psBoundParameters
	   Get-WmiObject @wmiParams
    }
}"     
        #endregion Generate Function
    }
}
                     
