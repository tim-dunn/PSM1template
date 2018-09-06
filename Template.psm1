#region header
#########################################


<#
        .SYNOPSIS
        PowerShell Module template file

        .NOTES
        Copyright (c) Microsoft

        Who             What        When            Why
        timdunn         v0.0.0.0    2018-09-06      Created template
#>


########################################
#endregion header
#region utility functions
########################################


function Get-ParameterString
{
    <#
            .Synopsis
            Get all parameter values passed into the calling function.

            .DESCRIPTION
            There exists currently no way to output the command line with actual values.

            $MyInvocation.Line will output the command line verbatim, so if it istarted
            with variables (as opposed to string literals), then those variable names 
            will be returned in $myInvocation.Line.

            $PSBoundParameters does not contain parameters not specified on the command
            line and use their default values.

            .PARAMETER RethrowExceptions
            By default, this function demotes terminating errors into warnings. Enabling
            this switch will still output the terminating error into a warning, but will
            also re-throw the error into the calling context.

            .EXAMPLE
            function Test-It { param ( [string]$String = 'default', [int]$Int = 20 ); Get-ParameterString }
            This will return "Test-It -String default -Int 20

            .INPUTS
            [void]

            .OUTPUTS
            [string]

            .NOTES
            // Copyright (c) Microsoft Corporation. All rights reserved.
            // Licensed under the MIT license.

            .COMPONENT
            Utility function.

            .ROLE
            Dev

            .FUNCTIONALITY
            Rehydrate the calling command line.
    #>

    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        [switch]$RethrowExceptions
    )

    Begin
    {
        [string]$functionName = $MyInvocation.MyCommand.Name

        if ( $DebugPreference -eq 'Continue' )
        {
            # we're outputting this only at -Debug level because it's a utility function
            Write-Debug -ErrorAction SilentlyContinue -Message "'$(
                $MyInvocation.Line -replace '^\s+' -replace '\s+$'
            )' started."
        }

        # we need to promote non-terminating errors to terminating ones so the try{} catch{}
        # will handle them
        $ErrorActionPreference = 'Stop'

    } #Begin

    End
    {
        try
        {
            # we need $myInvocation to get the calling function name
            [Management.Automation.InvocationInfo]$yourInvocation =
            Get-Variable -Name MyInvocation -Scope 1 -ValueOnly

            # we need the calling function name for the output, and for Get-Command data
            [string]$yourFunctionName =
            $yourInvocation.MyCommand.Name

            if ($yourFunctionName -match '\.psm1' )
            {
                throw "$functionName must be called from within a function defined in a PSModule."
            }

            # we need the Get-Command data for getting the parameters the function accepts
            [Management.Automation.FunctionInfo]$yourFunctionData =
            Get-Command -Name $yourFunctionName

            # we need $PSCmdlet to get the ParameterSetName the caller is using
            if ( !( 
                    $yourPSCmdlet = (
                        Get-Variable -Name PSCmdlet* -Scope 1 |
                        Where-Object -Property Name -EQ -Value PSCmdlet
                    ).Value
            ) )
            {
                # if the caller's $PSCmdlet isn't defined, it doesn't have 
                # [CmdletBinding()], so we'll have to put with whatever is on $line...
                $yourInvocation.Line -replace '^\s+' -replace '\s+$'
                return
            }

            # we need this array so we can match against all available parameters
            # both the ParameterSetName the caller is using, and the default set
            [string[]]$parameterSetNames = @(
                $yourPSCmdlet.ParameterSetName,
                '__AllParameterSets'
            ) |
            Where-Object -Property Length -GT 0 |
            Select-Object -Unique

            # we need this array to exclude the spam from PSH Common Parameters
            [string[]]$commonParameters = @(
                'Verbose',
                'Debug',
                'ErrorAction',
                'WarningAction',
                'InformationAction',
                'ErrorVariable',
                'WarningVariable',
                'InformationVariable',
                'OutVariable',
                'OutBuffer',
                'PipelineVariable',
                'WhatIf',
                'Confirm'
            )

            # we need this array for output. First element is the function's name.
            [Collections.ArrayList]$commandLineTokens = @(
                $yourFunctionName
            )

            $yourFunctionData.Parameters.Values |
            Where-Object -FilterScript `
            {
                # we use this to filter out all parameter data (not strings) for which
                # we want data: not Common parameters, and in the ParameterSetName(s)
                # the caller is using
                if ( $_.Name -notin $commonParameters )
                {
                    foreach ( $_parameterSetName in $_.ParameterSets.Keys )
                    {
                        if ( $_parameterSetName -in $parameterSetNames )
                        {
                            $true
                            break
                        }
                    }
                }
            } |
            ForEach-Object -Process `
            {
                [string]$parameterName = $_.Name

                $parameterValue = Get-Variable -Name $parameterName -Scope 1 -ValueOnly

                if ( $_.SwitchParameter )
                {
                    # we need to test this because [switch] parameters pass in values
                    # differently: -Confirm:$false
                    $commandLineTokens += "-${parameterName}:$parameterValue"
                }
                elseif ( $parameterValue -ne $null )
                {
                    # this builds the command line
                    $commandLineTokens += "-$parameterName"
                    $commandLineTokens += "'$parameterValue'"
                }
            }

            # this outputs the command line
            $commandLineTokens -join ' '

            return
        }

        catch
        {
            
            Write-Warning -Message "$functionName hit exception in $( $_.InvocationInfo.ScriptLineNumber )"
            
            $_ |
            Write-Warning

            if ( $RethrowExceptions )
            {
                $_
            }

            return
        }

        finally
        {
            Write-Debug -ErrorAction SilentlyContinue -Message "$functionName finished."
        }

    } # End

    # break the hash+greater-than string that terminates the blockcomment for the 
    # comment based help to expand all nested folded regoins in this function
    # until this line (in other words, the whole function.)
    #> # function Invoke-Noun
}


function test-It
{
    # .SYNOPSIS
    # Force reload this module, then execute the function under test.

    [CmdletBinding()]param()

    [bool]$verbose = [bool]$debug = $false
    if ($VerbosePreference -eq 'Continue' )
    {
        $verbose = $true
    }

    if ( $DebugPreference -eq 'Continue' )
    {
        $debug = $true
    }

    Import-Module -Force -Global -Verbose:$verbose -Debug:$debug -Name $PSCommandPath

    # function under test here
    #Do-Something -Parameter1 $parameter1 -Verbose:$verbose -Debug:$debug

}



########################################
#endregion utility functions
#region function group 1
########################################


function Invoke-Noun
{
    <#
            .Synopsis
            Short description.

            .DESCRIPTION
            Long description.

            .PARAMETER Planet
            A planet in solar system.

            .PARAMETER Moon
            Number of satellites.

            .PARAMETER Name
            Any celestial body.

            .EXAMPLE
            Invoke-Noun
            Example of how to use this cmdlet

            .EXAMPLE
            Invoke-Noun
            Another example of how to use this cmdlet

            .INPUTS
            Inputs to this cmdlet (if any)

            .OUTPUTS
            Output from this cmdlet (if any)

            .NOTES
            // Copyright (c) Microsoft Corporation. All rights reserved.
            // Licensed under the MIT license.

            .COMPONENT
            The component this cmdlet belongs to

            .ROLE
            The user role for the Help topic.

            .FUNCTIONALITY
            The intended use of the function

            .LINK
            https://social.technet.microsoft.com/Forums/scriptcenter/en-US/a180eec2-983f-4251-b753-9aa9340200d5/powershell-comment-based-help-usage-of-quotrolequot-and-quotfunctionalityquot?forum=ITCG
            Powershell comment based help - usage of "role" and "functionality"

            .LINK
            http://docproject.codeplex.com/wikipage?title=Sandcastle%20Help#MAML
            Role and Functionality are defined by MAML.
    #>

    [CmdletBinding(
            DefaultParameterSetName='Planet Parameter Set', 
            SupportsShouldProcess, 
            PositionalBinding=$false,
            HelpUri = 'http://www.microsoft.com/',
            ConfirmImpact='Medium'
    )]
    [Alias(
            'Do-Something'
    )]
    [OutputType([String])]
    Param
    (
        # Param1 help description
        [Parameter(
                Mandatory, 
                ValueFromPipeline,
                ValueFromPipelineByPropertyName, 
                #ValueFromRemainingArguments=$false,
                ParameterSetName='Planet Parameter Set', 
                Position=0
        )]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateCount( 0, 5)]
        [ValidateSet(
                'Mercury',
                'Venus',
                'Earth',
                'Mars',
                'Jupiter',
                'Saturn',
                'Neptune',
                'Uranus',
                'Pluto'
        )]
        [Alias(
                'p1'
        )] 
        $Planet,

        # Param2 help description
        [Parameter(
                ParameterSetName='Planet Parameter Set',
                Position = 10
        )]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [ValidateRange( 0, 50 )]
        [Alias(
                'p2'
        )]
        [int]
        $Moon = 0,

        # Param3 help description
        [Parameter(
                ParameterSetName='Any Object Parameter Set',
                Position=20
        )]
        [ValidatePattern( '[\w -]*' )]
        [ValidateLength( 0, 15 )]
        [Alias(
                'p3'
        )]
        [ValidateScript(
                {
                    Test-SampleNamesValue -Value $_
                }
        )]
        [String]
        $Name = $null,

        [switch]$RethrowExceptions
    )

    Begin
    {

        [string]$functionName = $MyInvocation.MyCommand.Name

        Write-LogMessage -ErrorAction SilentlyContinue -Message "'$( Get-ParameterString )' started."

    } #Begin

    Process
    {
        try
        {
            if ( $pscmdlet.ShouldProcess( 'Target', 'Operation' ) )
            {
                # Content
            }

    
        }

        catch
        {
            
            Write-Warning -Message "$functionName hit exception in $( $_.InvocationInfo.ScriptLineNumber )"
            
            $_ |
            Write-Warning

            if ( $RethrowExceptions )
            {
                throw $_
            }

            return
        }

        finally
        {

        }

    } # Process

    End
    {
        try
        {
            # Content
    
        }

        catch
        {
            
            Write-Warning -Message "$functionName hit exception in $( $_.InvocationInfo.ScriptLineNumber )"
            
            $_ |
            Write-Warning

            if ( $RethrowExceptions )
            {
                $_
            }

            return
        }

        finally
        {
            Write-LogMessage -ErrorAction SilentlyContinue -Message "$functionName finished."
        }

    } # End

    # if this ...# function Invoke-Noun line is present, break the hash+greater-than string
    # terminating the blockcomment to unfold all folded code in this function.
    #> # function Invoke-Noun
}


########################################
#endregion function group 1
#region initialization
########################################

#region externalize logging
#========================================

# in another module, I declared a ModuleName.init.ps1 script in $ScriptsToProcess 
# that defined a Write-LogMessage function so it was loaded before the PSM1s
if ( 
    Get-Command -Name Write-LogMessage* -CommandType Function |
    Where-Object -Property Name -EQ -Value Write-LogMessage

)
{
    Write-Debug -Message 'Using Write-LogMessage function.'
}
else
{
    Write-Debug -Message 'Using Write-LogMessage alias to Write-Verbose.'
    Set-Alias -Name Write-LogMessage -Value Write-Verbose
}

#========================================
#endregion externalize logging
#region dynamic [ValidateSet()]
#========================================

# this data can be pulled dynamically from some other data source or function
$script:sampleNames = @(
    'Comet',
    'Moon',
    'Sun',
    'Sputnik'
)

function Test-SampleNamesValue
{
    # .SYNOPSIS
    # Use this as a [ValidateScript()] to add [ValidateSet()] behaviour to a parameter.
    #
    # .PARAMETER Value
    # Value to test. 
    #
    # .EXAMPLE
    # function Show-It {param([ValidateScript({Test-SampleNamesValue -Value $_ })[string]$Name=$null);$Name}
    # Using this function to perform the equivalent of [ValidateSet()] on a parameter.

    param
    (
        [Parameter(
                Mandatory
        )]
        $value
    )

    # just make sure the logic returns $true on successful validation
    $value -in $script:sampleNames
}

Register-ArgumentCompleter -CommandName Invoke-Noun -ParameterName Name -ScriptBlock `
{
    # dynamically populate a parameter's tab-complete, similar to a [ValidateSet()]

    $script:sampleNames |
    Sort-Object -Unique |
    ForEach-Object -Process `
    {
        $value = "'$( $_ -replace "'", "''" )'"
        
        [Management.Automation.CompletionResult]::new( $value, $value, 'ParameterValue', ( "Group: " + $value ) )

    }
}

#========================================
#endregion dynamic [ValidateSet()]


########################################
#endregion initialization