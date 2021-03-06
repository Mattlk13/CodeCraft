function Write-Hashtable {
    <#
    .Synopsis
        Takes an existing Hashtable and creates the script you would need to embed to recreate the hashtable
    .Description
        Allows you to take a hashtable and create a hashtable you would embed into a script.
        Handles nested hashtables and automatically indents hashtables based off of how many times New-PowerShellHashtable is called
    .Example
        # Corrects the presentation of a PowerShell hashtable
        Write-Hashtable @{Foo='Bar';Baz='Bing';Boo=@{Bam='Blang'}}
    .ReturnValue
        [string]
    .ReturnValue
        [ScriptBlock]   
    .Link
        about_hash_tables
    #>    
    param(
    # The hashtable to turn into a script
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [PSObject]
    $InputObject,

    # Determines if a string or a scriptblock is returned
    [switch]$scriptBlock
    )

    process {
        $callstack = @(Get-PSCallStack | 
            Where-Object { $_.Command -eq "Write-Hashtable"})
        $depth = $callStack.Count
        if ($inputObject -is [Hashtable]) {
            $scriptString = ""
            $indent = $depth * 4        
            $scriptString+= "@{
"
            foreach ($kv in $inputObject.GetEnumerator()) {
                $indent = ($depth + 1) * 4
                for($i=0;$i -lt $indent; $i++) {
                    $scriptString+=" "
                }
                $keyString = $kv.Key
                if ($keyString -notlike "*.*" -and $keyString -notlike "*-*") {
                    $scriptString+="$($kv.Key)="
                } else {
                    $scriptString+="'$($kv.Key)'="
                }
                
                $value = $kv.Value
                Write-Verbose "$value"
                if ($value -is [string]) {
                    $value = "'$value'"
                } elseif ($value -is [ScriptBlock]) {
                    $value = "{$value}"
                }  elseif ($value -is [switch]) {
                    $value = if ($value) { '$true'} else { '$false' }
                } elseif ($value -is [bool]) {
                    $value = if ($value) { '$true'} else { '$false' }
                } elseif ($value -is [Object[]]) {
                    $oldOfs = $ofs 
                    $ofs = "',
$(' ' * ($indent + 4))'"
                    $value = "'$value'"
                    $ofs = $oldOfs
                } elseif ($value -is [Hashtable]) {
                    $value = "$(Write-Hashtable $value)"
                } else {
                    $value = "'$value'"
                }                                
               $scriptString+="$value
"
            }
            $indent = $depth * 4
            for($i=0;$i -lt $indent; $i++) {
                $scriptString+=" "
            }          
            $scriptString+= "}"     
            if ($scriptBlock) {
                [ScriptBlock]::Create($scriptString)
            } else {
                $scriptString
            }
        }           
   }
}       
