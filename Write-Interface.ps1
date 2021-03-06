function Write-Interface {
    <#
    .Synopsis
        Creates an interface implementation that is backed by a PSObject        
    .Description
        Creates an interface implementation backed by a PSObject.  All operations on the interface go straight to the PSObject, which lets you do two powerful things:
        
        - Implement interfaces in PowerShell
        - Test interfaces with a bad implementation, that does not implement certain overrides
    .Example
        Write-Interface -interface ([IDisposable]) 
    .Link
        Add-Type
    #>
    param(
    # The type of an existing interface, for example, IDisposable
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ParameterSetName="FromInterface")]
    [Type]$interface,
   
    # If set, compiles the interface
    [switch]$Compile)

process {
   # If the FromObject parameter set is used, then quickly create a cache for the loaded types so that 
   # we will not search through them each time.
   # Although all interfaces can be found with
   # [AppDomain]::CurrentDomain().GetAssemblies() | % { $_.GetTypes() } | ? { $_.IsInterface } 
   # this operation will store them as a list.
   # As each interface is encountered, we will check a hashtable of the properties & methods of 
   # each input object.  When matches are encountered, the match will be added to a list of matching interfaces.
   # After all matches are cached, each type of 
   switch ($psCmdlet.ParameterSetName) {
     FromObject {
         $loadedTypes = @{}         
     }
     FromInterface {
         if (! $interface.IsInterface) { throw "Must provide an interface" }
         $requiredAssemblies = $interface.Assembly.Location, [object].Assembly.Location, [PSObject].Assembly.Location
         $ofs = ","          
         $methodCode = ""
         foreach ($method in ($interface.GetMethods()) ) {
             $parameterList =  $method.GetParameters() | % { "$_.Name" }
             $methodCode += @"
    public $method {
        return psObj.Methods.Item("$($method.Name)").Invoke($("$parameterList".Trim())); 
    }    
"@
         }
         $propertyCode = ""
         foreach ($property in $interface.GetProperties()) {
             $propertyCode+=@"
    public $property { 
        $(if ($property.CanRead) { "
        get { return psObj.Properties.Item(`"$($property.Name)`").Value; }"
        })        
        $(if ($property.CanWrite) { "
        set { psObj.Properties.Item(`"$($property.Name)`").Value = value; }"
        })
    }
"@
         }
         
$implementationCode = @"
using System;
using $($interface.Namespace);
using System.Management.Automation;

public class PsObject$($interface.Name) : $($interface.Name){
     public PsObject$($interface.Name) (PSObject object) { psObj = object}
     $methodCode
     $propertyCode
     $eventCode
}
"@   
if ($Compile) {
    Write-Verbose "Compiling $implementationCode"
    Add-Type -TypeDefinition $implementationCode         
} else {
    $implementationCode         
}
     }
   }

}
   
} 
