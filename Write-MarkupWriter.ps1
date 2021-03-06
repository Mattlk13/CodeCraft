function Write-MarkupWriter
{
    <#
    .Synopsis
        Write-MarkupWriter produces PowerShell commands that create markup
    .Description
        Write-MarkupWriter will create a single PowerShell function
        to create a single XML element, with as rich parameter binding 
        and defaults as you would like.  
        
        In this way, you can build up scripts that interact with XML with
        all of the parameter binding PowerShell has to offer.
        
        The -AttributeParameter and -ElementParameter will accept full parameter 
        declarations, like [Parameter(Manadatory=$true)]$foo.  
        
        These parameter declarations will become parameters on the new command,
        with -AttributeParameter mapping to escaped attributes, and 
        -ElementParameter mapping to cData elements.
        
        The commandname will be set implicily to "Write-${TagName}Tag"
    .Example
        Write-MarkupWriter -TagName "a" -AttributeParameter '$href', '$class' -ElementParameter InnerHtml
    #>    
    param(
    # The name of the tag
    [Parameter(Mandatory=$true)]
    [String]$TagName,    
    # -AttributeParameter defines the parameters that will provide values for an attribute.  
    [string[]]
    $AttributeParameter,
    # -ElementParameter defines the parameters that will provide values for an element
    [String[]]$ElementParameter,    
    # -CommandName allows you to define a custom command name.  If -CommandName is missing,
    # the command will be named "Write-${TagName}Tag"
    [String]$CommandName    
    )
    
    begin {
        <#
        .Synopsis
            Given a given parameter block of parameters to declare, gets the name of the parameters
        #>
        function Get-ParameterName($declartion) {
            & ([ScriptBlock]::Create("
            function foo {
                param($declartion)
            }
            (Get-Command foo).Parameters.Keys |        
                Where-Object {
                    'Verbose','Debug','ErrorAction','WarningAction',
                        'ErrorVariable','WarningVariable','OutVariable',
                        'OutBuffer' -notcontains `$_
                }
            "))
        }                
    }
    
    process 
    {        
        #region Initialize the Code to Generate
        $paramBlock = ""
        $processBlock = "" + {
            function esc($str) { [Security.SecurityElement]::Escape($str) }
            $attributeChunk =  ''
            $elementChunk = '' 
        }
        #endregion
        
        #region Generate code for the attribute parameters
        foreach ($Attribute in $AttributeParameter) {
            if (-not $attribute) { continue} 
            if (-not $attribute.Contains('$')) {
                $attribute = '$' + $attribute
            }
            $paramBlock += "$attribute,
            "        
            $paramName = Get-ParameterName $attribute  
            $processBlock += "
            if (`$psBoundParameters.ContainsKey('$paramName')) {            
                if (`$singleQuote) {
                    `$attributeChunk += `" $paramName `='`$(esc `$$paramName)'`"
                } else {
                    `$attributeChunk += `" $paramName`=```"`$(esc `$$paramName)```"`"
                }
            }"
        }
        foreach ($Element in $ElementParameter) {
            if (-not $Element) { continue} 
            if (-not $Element.Contains('$')) {
                $Element = '$' + $Element
            }

            $paramName = Get-ParameterName $Element                
            $paramBlock += "$element,
            
            "
            $processBlock += "
                `$elementChunk += `$$paramName
            "
        }
        $paramBlock += '
        [Switch]$AsXml,
        [Switch]$SingleQuote        
        '
        $processBlock += "
        
        `$xml = `"<$TagName `$AttributeChunk >
            `$ElementChunk
        </$TagName>
        `" -as [xml]
        if (`$asXml) {
            `$xml
        } else {
            `$strWrite = New-Object IO.StringWriter
            `$xml.Save(`$strWrite)
            `"`$strWrite`"            
        }
        "

        if (-not $commandName) {
            $commandName = "Write-${TagName}Tag"
        }
        $outputFunction = "
        function $commandName {
            param (
            $paramBlock
            )
            process {
                $ProcessBlock
            }                                   
        }        
        "

        $outputFunction
    }
} 
