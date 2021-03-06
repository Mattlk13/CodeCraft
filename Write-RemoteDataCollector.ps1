function Write-RemoteDataCollector
{
    <#
    .Synopsis
        Writes a function that collects information from several machines using fan-out remoting
    .Description
        Writes a function that collects information from several machines using fan-out remoting
    .Example
        Write-RemoteDataCollector -Name 'Get-ComputerSystem' -ScriptBlock { Get-WmiObject Win32_ComputerSystem } 
    .Link
        about_Remote_Faq    
    #>
    param(
    # The name of the function to create
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
    [string]
    $Name,
    
    # A ScriptBlock of information to collect from the remote machines
    [Parameter(Mandatory=$true,Position=1)]
    [ScriptBlock]
    $ScriptBlock,
    
    # A description of the task
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $Description    
    )
    
    
    begin {
        # Get the command metadata for Invoke-Command
        $invokeCommandMetaData = [Management.Automation.CommandMetadata](Get-Command Invoke-Command)
        
        # Remove the parameters that do not exist in the parameter sets we are interested in, 
        # and a number of other parameters related to these items
        $toRemove = @($invokeCommandMetaData.Parameters.Keys | Where-Object { 
            $keys = $invokeCommandMetaData.Parameters[$_].ParameterSets | Select-Object -ExpandProperty Keys
            $keys -notcontains 'Session' -and 
            $keys -notcontains 'ComputerName' -and
            $keys -notcontains '__AllParameterSets'
        }) + 'ScriptBlock', 'AsJob', 'HideComputerName', 'InputObject', 'ArgumentList', 'JobName', 'ThrottleLimit'        
        foreach ($tr in $toRemove) {            
            $null = $invokeCommandMetaData.Parameters.Remove($tr)
        }
        
        # Make all of the remaining parameters ValueFromPipelineByPropertyName
        $invokeCommandMetaData.Parameters.Values | 
            ForEach-Object { $_.ParameterSets.Values }  |
            ForEach-Object { 
                $_.ValueFromPipelineByPropertyName = $true 
            } 
            
        # Remove the parameter sets that no longer exist from the parameters that still have them
        $invokeCommandMetaData.Parameters.Values |
            ForEach-Object {
                $null = $_.ParameterSets.Remove("FilePathComputerName")
                $null = $_.ParameterSets.Remove("FilePathRunspace")
                $null = $_.ParameterSets.Remove("FilePathUri")
                $null = $_.ParameterSets.Remove("Uri")
            }
            
        # Make the ComputerName parameter ValueFromPipeline and Position 1 (-not position 0)
        $invokeCommandMetaData.Parameters["ComputerName"].ParameterSets.Values | 
            ForEach-Object { 
                $_.ValueFromPipeline = $true 
                $_.Position = 1 
            } 
        
        # Make the Session parameter position 1
        $invokeCommandMetaData.Parameters["Session"].ParameterSets.Values | 
            ForEach-Object { 
                $_.Position = 1 
            } 
                    
        # Create a parameter block
        $parameterBlock = [Management.Automation.ProxyCommand]::GetParamBlock($invokeCommandMetaData)    

        # Create a process block
        $processBlock = {
            $params = @{
                ScriptBlock = $scriptBlock
            } + $psBoundParameters
            $null = $in.AddLast($params)    
        }

        # Create an end block
        $endBlock ={
            if ($psCmdlet.ParameterSetName -eq "Local") { 
                if ($activity) {
                    Write-Progress "Starting $Activity" " "
                }
                & $scriptBlock
                if ($activity) {
                    Write-Progress "$Activity Completed" " "
                }

            } else {
        
                $jobs = @()
                foreach ($i in $in) {
                    $jobs += Invoke-Command @i -AsJob
                    
                }

                $runningJobs = $jobs | 
                    Where-Object { $_.State -eq "Running" }
        
                while ($runningJobs) {
                    $runningJobs = @($jobs | 
                        Where-Object { $_.State -eq "Running" })
                    $jobs | Wait-Job -Timeout 1 | Out-Null
                    $percent = 100 - ($runningJobs.Count * 100 / $jobs.Count)
                    if ($activity) {
                        Write-Progress "Waiting for $Activity to Complete" "$($Jobs.COunt - $runningJobs.Count) out of $($Jobs.Count) Completed" -PercentComplete $percent
                    } else {
                        Write-Progress "Waiting for Remote Execution to Complete" "$($Jobs.COunt - $runningJobs.Count) out of $($Jobs.Count) Completed" -PercentComplete $percent
                    }
                    
                }
                
                $jobs | 
                    Receive-Job                
            }
        }
    }


    process {
        if (-not $description) { 
            $description = $Name 
        }
        
        # Only the Begin block changes, and only slightly
        $beginBlock = @"
            `$in = New-Object Collections.Generic.LinkedList[Hashtable]
            `$activity = "$description"
            `$scriptBlock = {
                $ScriptBlock
            }
"@
                     
@"
function ${Name} {
    <#
    .Synopsis
        $Description
    .Description
        $Description
    .Example
        ${Name}    
    #>
    [CmdletBinding(DefaultParameterSetName="Local")]
    param(
    $parameterBlock
    )
        
    begin {
        $beginBlock
    }
        
    process {
        $processBlock
    }
    
    end {
        $endBlock
    }
}
"@
    }
}