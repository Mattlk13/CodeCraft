function Write-ScriptCmdlet
{
    <#
    .Synopsis
        Creates a new script cmdlet
    .Description
        Creates a new script cmdlet automatically
    .Example
        Write-ScriptCmdlet New-FooBar        
    .Example
        Write-ScriptCmdlet -Name Start-ProcessAsAdministrator -FromCommand (Get-Command Start-Process) -RemoveParameter Verb -ProcessBlock {  
            $null = $psBoundParameters.Verb = "RunAs"
            Start-Process @psBoundParameters
        }
    .Example
        Write-ScriptCmdlet -Name -FromCommand (Get-Command Get-Process) -RemoveParameter Verb
    .Example
        Write-ScriptCmdlet -Name Get-Process -ProxyCommand (Get-Command Get-Process)  
    #>
    [CmdletBinding(DefaultParameterSetName="Name")]
    param(
    # Creates a proxy command from a given command.  
    # Proxy commands are a special form of Powershell command that is used 
    # to restrict the set of parameters for a given cmdlet.
    [Parameter(Mandatory=$true,
        ParameterSetName="ProxyCommand",
        ValueFromPipeline=$true,
        Position=1)]
    [Management.Automation.CommandInfo]
    [Alias('Proxy')]
    $ProxyCommand,

    # The name of the command to generate
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
    [String]
    $Name,
    
    # The parameter block to embed in the command
    [Parameter(ParameterSetName="Name")]
    [String]
    $ParameterBlock,
    
    # FromCommand allows you to create a command based off an existing command.  
    # This command wil not run the command, but it will share the same parameter
    # signature for the command.
    [Parameter(ParameterSetName="FromCommand", 
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true
        )]
    [Management.Automation.CommandInfo]
    $FromCommand,
    
    # Any additional parameters to add to the command.
    [Parameter(ParameterSetName="FromCommand",
        ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.ParameterMetaData[]]
    $AdditionalParameter,
    
    # Any parameters to remove from the command.
    [Parameter(ParameterSetName="FromCommand",
        ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName="ProxyCommand",
        ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $RemoveParameter,
    
    # The content of the begin block
    [Parameter(ParameterSetName="Name")]
    [Parameter(ParameterSetName="FromCommand")]
    [String]
    $BeginBlock,
    
    # The content of the process block
    [Parameter(ParameterSetName="Name")]
    [Parameter(ParameterSetName="FromCommand")]
    [String]
    $ProcessBlock,
    
    # The content of the end block
    [Parameter(ParameterSetName="Name")]
    [Parameter(ParameterSetName="FromCommand")]
    [string]
    $EndBlock,
    
    # The content of the help block.
    [Parameter(ParameterSetName="Name")]
    [Parameter(ParameterSetName="FromCommand")]
    [String]
    $HelpBlock
    )

    Process
    {
        Switch ($psCmdlet.ParameterSetName) {
            Name {[ScriptBlock]::Create("
function $name {
    $HelpBlock
    param(
        $ParameterBlock
    )
    begin {
        $BeginBlock
    }
    process {
        $ProcessBlock
    }
    end {
        $EndBlock
    }
}") 
            }
            ProxyCommand {
                $MetaData = New-Object Management.Automation.CommandMetaData $ProxyCommand
                foreach ($rp in $removeParameter) {
                    if (-not $rp) { continue }
                    $null = $MetaData.Parameters.Remove($rp)
                }
                foreach ($ap in $additionalParameter) {
                    if (-not $ap) { continue }
                    $null = $MetaData.Parameters.Add($ap.Name, $ap)
                }
                [ScriptBlock]::Create("
function $Name {
    $([Management.Automation.ProxyCommand]::Create($MetaData))
}")
            }
            FromCommand {
                $MetaData = New-Object Management.Automation.CommandMetaData $FromCommand
                foreach ($rp in $removeParameter) {
                    if (-not $rp) { continue }
                    $null = $MetaData.Parameters.Remove($rp)
                }
                foreach ($ap in $additionalParameter) {
                    if (-not $ap) { continue }
                    $null = $MetaData.Parameters.Add($ap.Name, $ap)
                }
                [ScriptBlock]::Create("
function $Name {
    $HelpBlock
    $([Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metaData))
    param(
        $([Management.Automation.ProxyCommand]::GetParamBlock($metaData))
    )
    
    begin {
        $BeginBlock
    }
    process {
        $ProcessBlock
    }
    end {
        $EndBlock
    }
}")
            }
        }
    }
}