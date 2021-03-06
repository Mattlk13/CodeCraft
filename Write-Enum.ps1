function Write-Enum
{
    <#
    .Synopsis
        Creates a New enumerated type
    .Description
        Creates a new enumerated type from a list of strings or a dictionary of values
    .Example
        Write-Enum "Foo" "a","b","c"
    .Example
        Write-Enum  "Foo" @{"a" = 1;"b" = 2;"c" = 4} -Namespace "Bar"          
    .Link
        Add-Type
    #>
    [CmdletBinding(DefaultParameterSetName='List')]
    param(
    # The name of the enumerated type
    [Parameter(Position=0,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [string]$Name,
    # The namespace the enumerated type will be in
    [Parameter(Position=2,
        ValueFromPipelineByPropertyName=$true)]
    [string]$Namespace,
    
    # The list of potential values.  
    # If -List is used, the enumerated type will not be a flag.
    [Parameter(ParameterSetName='List',
        Position=1,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [string[]]$List,
    # A dictionary of potential values.
    # If -Dictionary is used, the enumerated type will be a flag.
    [Parameter(ParameterSetName='Value',
        Position=1,
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [Hashtable]$Dictionary
    )
    
    Process {
        if ($psCmdlet.ParameterSetName -eq 'List') {
            $enumText = $list -join ","
        } elseif ($psCmdlet.ParameterSetName -eq 'Value'){
            $enumText = ""
            foreach ($kv in $dictionary.GetEnumerator()) {
                $key  = $kv.Key
                $value = $kv.Value -as [int]
                if ($value -isnot [int]) {
                    $key = $kv.Value
                    $value = $kv.Key -as [int] 
                }
                $enumText += "
                $key = $value,"
            }
            $enumText = $enumText.TrimEnd(",") + [Environment]::NewLine
        }
            
        $text = "
            public enum $name {
                $enumText
            }"
        if ($namespace) {
            $text = "
        namespace $namespace {
            $text
        }"
        }
        return $text        
    }
    
}