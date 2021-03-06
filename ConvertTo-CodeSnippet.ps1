function ConvertTo-CodeSnippet
{
    <#
    .Synopsis
        Turns PowerShell functions Visual Studio code snippets 
    .Description
        Converts simple PowerShell functions into Visual Studio code snippets.
        
        Only functions that start with a string statement which contains all
        of the parameters to the function will be convertable into a code snippet.
        Because Visual Studio code snippets do not support advanced syntax, this string
        cannot do string expansion ($() is not permitted)
        
        Parameter help and help on the command will be propogated into the code snippet,
        and certain parameter types and attributes will change the default values.
        
        If the parameter is a switch parameter or a boolean, then it will be default to true
        in the snippet.
        
        If the parameter is a numeric type, then it will default to true
        
        If the parameter is a type, it will default to the name of the command
        
        If the parameter is a string, it will default to a quoted string, unless it
        has the attribute [ValidatePattern('^[a-zA-Z_0-9]{1,}$')].  This handles most 
        legal class, property, method, and field names.  If this attribute is present,
        the default value will be an unescaped string
        
    .Example
        ConvertTo-CodeSnippet -Language CSharp -Script {
            function Write-Property { 
                #.Synopsis
                #    Writes a Property, backed by a field
                #.Description
                #    Writes a property in C#, backed by a field
                #.Example
                #    Write-Property -Property "Foo" -Field "foo" -Type [int]
                param(
                # The name of the property
                [ValidatePattern('^[a-zA-Z_0-9]{1,}$')]
                [String]
                $Property,
                
                # The name of the field
                [ValidatePattern('^[a-zA-Z_0-9]{1,}$')]
                [String]
                $Field,  

                # The Type of the property and field                      
                [Type]
                $Type
                )
                
                "
                private $Type $Field;
                
                public $Type $Property {
                    get { return this.$Field; }
                    set { this.$field = value; } 
                }
                "
            }
        }
    .Example
        function Write-Property {
            #.Synopsis
            #    Writes a Property, backed by a field
            #.Description
            #    Writes a property in C#, backed by a field
            #.Example
            #    Write-Property -Property "Foo" -Field "foo" -Type [int]
            param(
            # The name of the property
            [ValidatePattern('^[a-zA-Z_0-9]{1,}$')]
            [String]
            $Property,
            
            # The name of the field
            [ValidatePattern('^[a-zA-Z_0-9]{1,}$')]
            [String]
            $Field,  

            # The Type of the property and field                      
            [Type]
            $Type
            )
            
            "
            private $Type $Field;
            
            public $Type $Property {
                get { return this.$Field; }
                set { this.$field = value; } 
            }
            "
        }
        
        Get-Command Write-Property | ConvertTo-CodeSnippet
    #>
    [CmdletBinding(DefaultParameterSetName="Command")]
    param(
    # The command that will be converted to a code snippet
    [Parameter(ParameterSetName='Command',
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.CommandInfo]
    $Command,
    
    # A script block containing a command to turn into a code snippet
    [Parameter(ParameterSetName='ScriptBlock',
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    [ScriptBlock]
    $ScriptBlock,
     
    # The languae of the code snippet to create
    [ValidateSet("csharp", "VB", "XML", "PowerShell")]
    [String]
    $Language = "PowerShell",
    
    # The kind of the code snippet to generate.  By default, code snippets are of type "Any"
    [ValidateSet("method body", "method decl", "type decl", "page", "file", "any")]                                
    [String]
    $Kind = "Any",
    
    # If set, saves the code snippet.
    [switch]$Save        
    )
    
    process {
        if ($psCmdlet.ParameterSetName -eq "Command") {        
            $commandText = ""
            if ($command -is [Management.Automation.FunctionInfo]) {
                $commandText = $command.Definition
            } elseif ($command -is [Management.Automation.ExternalScriptInfo]) {
                $commandText = $command.ScriptContents
            }
        } elseif ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $functionOnly = Get-FunctionFromScript -ScriptBlock $psBoundParameters.ScriptBlock            
            $cmds = @()
            foreach ($f in $functionOnly) {
                . ([ScriptBlock]::Create($f))
                $matched = $f -match "function ((\w+-\w+)|(\w+))"
                if ($matched -and $matches[1]) {
                    $cmds+=Get-Command $matches[1]
                }                        
            }
            $cmds | ConvertTo-CodeSnippet            
        }

            try {
                $tokens = @([Management.Automation.PSParser]::Tokenize($commandText, [ref]$null))
            } catch {
                return
            }

            # Now we've got the tokens.  The function has to be fairly particular about it's format:
            # Nothing "complicaed" can happen after the param() block.  Specifically, it must be a string
            # that is -like each of the parameter names of the function and -notlike '*$(*)*'
            
            for ($paramStart = 0; $paramStart -lt $tokens.Count;  $paramStart++) {
                if ($tokens[$paramStart].Type -eq "Keyword" -and 
                    $tokens[$paramStart].Content -eq "Param") {
                    break
                }
            }
            
            if ($paramStart -eq $tokens.Count) {
                # No parameter block:
                # There can only be one token that is not a comment or a newline: the block of code
            } else {
                # Find the end of the grouping
                $depth =0 
                for ($start = $paramStart + 1;  $start -lt $tokens.Count; $start++) {
                    if ($tokens[$start].Type -eq "GroupStart") {
                        $depth++
                    } 
                    if ($tokens[$start].Type -eq "GroupEnd") {
                        $depth--
                    }
                    
                    if ($depth -eq 0) { 
                        break
                    }
                }
                
                if ($start -ne $tokens.Count) {
                    $start++
                    
                    # The next non-newline should be a string, so skip past newlines
                    while ($start -lt $tokens.Count -and 
                        $tokens[$start].Type -eq "Newline") {
                        $start++
                    }
                    
                    # Ok, now if it's a string, then we're in business. 
                    # If it's not, politely inform the user                    
                    if ($tokens[$start].Type -ne "String") {
                        Write-Error "Could not convert $Command into a CodeSnippet.
The first thing in the command past the parameter block must a string.  This string will become the contents of the code snippet"
                        return                        
                    
                    }
                                  

                    $stringContent = $tokens[$start].Content
                    
                    # Make sure the string doesn't contain complex expansion                
                    if ($stringContent -like '*$(*)') {
                        Write-Error "Could not convert $Command into a CodeSnippet.
Code Snippets are not running full PowerShell, and you cannot use complex string expansion within the code snippet"                        
                    }
                    
                    # Get the command metadata, then use the parameter names here to confirm that every parameter
                    # is referenced in the code snippet.  If each parameter is found, generate the XML chunk that 
                    # represents the parameter in a code snippet
                    $commandMetaData = $command -as [Management.Automation.CommandMetaData]
                    $commandHelp = $command | Get-Help
                    $commandParameters = $command.Parameters.Keys
                    $commandLiterals = ""
                    
                    # Normalize the type of embedding used in the string:                    
                    $stringContent = $stringContent -replace '\$[{]*(?<variable>\w{1,})[}]*', '${$1}'
                    
                    foreach ($commandParam in $commandParameters) {
                        # Make sure the string references the parameter
                        if ($stringContent -notlike "*`${$commandParam}*") {
                            Write-Error "Could not convert $Command into a CodeSnippet.
All parameters must be referenced within the code snippet.  Parameter $commandParam was not found"
                            return
                        }
                        
                        # Extract out help for this parameter, or supply a default
                        $helpText = $help.parameters.parameter | 
                            Where-Object { $_.Name -eq $commandParam } | 
                            ForEach-Object { $_.Description[0].Text }
                        if (-not $helpText) {
                            $helpText = "The $commandParam"
                        }
                            
                                       
                        $commandParameterType = $command.Parameters[$commandParam].ParameterType
                        $isCodeParameter = $command.Parameters[$commandParam].Attributes |
                            Where-Object { 
                                $_.TypeId -eq [System.Management.Automation.ValidatePatternAttribute] -and 
                                $_.RegexPattern -eq '^[a-zA-Z_0-9]{1,}$'
                            }
                            
                        if ( $commandParameterType -eq [string]) {
                            if ($isCodeParameter) {
                                $default = "$commandParam"
                            } else {
                                $default = "`"$commandParam`""                            
                            }
                        } elseif ($commandParameterType -eq [Type]) {
                            $default = "$commandParam"
                        } elseif ( [bool], [switch] -contains $commandParameterType) {
                            $default = "true"
                        } elseif ( [Int], [UInt32], [Double], [Float] -contains $commandParameterType ) {
                            $default = 0
                        } else {
                            $default = "`"$commandParam`""
                        }
                        
                        # Add the parameter to the literal section of the snippet
                        $commandLiterals += @"
<Literal>
    <ID>$commandParam</ID>
    <ToolTip>The Name of the Property</ToolTip>
    <Default>$default</Default>
</Literal>
"@
                        
                        
                        # Fix the parameter where it's found in the string contents
                        $stringContent = [Regex]::Replace(
                            $stringContent, "\`${$commandParam}","`$$commandParam`$",  
                            [Text.RegularExpressions.RegexOptions]"IgnoreCase, SingleLine"
                        )                        

                        
                    }

                    $commandLiterals = "<Declarations>$commandLiterals</Declarations>"

                    $description = $help.description |
                        ForEach-Object {$_.Text } 
                    
                    $synopsis = $help.Synopsis
                    
                    if (-not $synopsis) { $synopsis = "$command" }
                    if (-not $description) { $description = "$command" }
                    
$xml = @"
<CodeSnippets  xmlns="http://schemas.microsoft.com/VisualStudio/2005/CodeSnippet">
  <CodeSnippet Format="1.0.0">
    <Header>
      <Title>$Synopsis</Title>
      <Shortcut>$command</Shortcut>
      <Description>$Description</Description>
      <Author>$env:UserName</Author>
      <SnippetTypes>
        <SnippetType>Expansion</SnippetType>
      </SnippetTypes>
    </Header>
    <Snippet>   
    $commandLiterals                     
    <Code Language="$($language.ToLower())" Kind="$($kind.ToLower())">
<![CDATA[
$stringContent        
`$end`$]]>
    </Code>
    </Snippet>
  </CodeSnippet>
</CodeSnippets>
"@ -as [xml]               

                    
                    $null = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
                    if ($Save) {
                        Get-ChildItem $home\Documents -Filter "Visual Studio*" | 
                        ForEach-Object { 
                            $path = "$($_.Fullname)\Code Snippets"
                            switch ($Language) {
                                csharp {
                                    $path += "\Visual C#\My Code Snippets"
                                }
                                xml {
                                    $path += "\XML\My XML Snippets"
                                }
                            }
                            $path += "\$($command.Name).snippet"
                            
                            $xml.Save($path)
                            Get-Item $path
                        } 
                                            
                    } else {
                        $xml = [xml]$xml
                        $strWrite = New-Object IO.StringWriter
                        $xml.Save($strWrite)
                        return "$strWrite"                         
                    }
                    

                    $start++
                    while ($start -lt $tokens.Count) {
                        if ("Newline","Comment" -notcontains $tokens[$start].Type) {
                            Write-Error "The command was turned into a CodeSnippet, but part of the command will not be run.
Because code snippets are not running PowerShell, they cannot contain more complex items.
"                                                                                
                            return                        
                        }
                        $start++
                    }
                }
                
            }
            
            
            
    }
}