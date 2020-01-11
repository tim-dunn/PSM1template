#region header
#########################################


<#
    .SYNOPSIS
    PowerShell Module template file

    .DESCRIPTION
    A place for me to stash my debugging functions.

    .NOTES
    Copyright (c) Microsoft

    Who             What        When            Why
    timdunn         v0.0.0.0    2018-09-06      Created template
#>


########################################
#endregion header
#region debugging functions
########################################


function Out-Parameters
{
    <#
        .synopsis
        Output parameters supplied to calling function.

        .description
        For logging or debugging, it is often useful to dump the paramters with which the function
        was called. Unfortunatley, $PSBoundParameters does not report defalut parameter values.
        Additionally, because of variable scoping, it can be difficult to use shared code to get
        parameter values.

        This provides a best-effort attempt to display the parameters supplied to the calling function.

        .parameter FunctionName
        Optional (but highly recommended!) parameter used to specify the calling function. If not
        supplied, this function will use $MyInvocation value(s) from increasing scope to attempt to
        determine the calling function name, but that can be highly brittle.

        .parameter Parameters
        Optional (but highly recommended!) parameter into which to specify $PSBoundParameters from
        the calling function. Again, if not supplied, this function will use Get-Variable to
        attempt to obtain $PSBoundParameters from the calling scope, but this can be highly brittle
        with the variety of ways a function can be invoked, defined, etc.

        .parameter Scope
        Value passed to Get-Variable -Scope parameter to get parameter values from the calling function.

        .parameter AsObject
        Return [hashtable] of supplied parameters. Default is to return string array of parameters,
        sorted by name.

        .example
        function Test-It { [cmdletbinding()] param ( $a, $b, $c ); Out-Parameters -FunctionName Test-It -Parameters $PSBoundParameters }

        Using it in a function to output the [string[]] array to STDOUT

        .example
        Test-It -a 3 -c $false -Verbose

        Example of sample output to STDOUT:

        Name                           Value
        ----                           -----
        a                              3
        c                              False
        Verbose                        True

        .example
        function Test-It { [cmdletbinding()] param ( $a, $b, $c ); $myParameters = Out-Parameters -FunctionName Test-It -Parameters $PSBoundParameters -AsObject }

        Using it in a function to save parameters to [hashtable] for later processing
    #>

    [CmdletBinding()]

    param
    (
        [hashtable]$Parameters = @{ },

        [string]$FunctionName = '',

        [int]$Scope = 1,

        [switch]$AsObject
    )

    if ( !$Parameters )
    {
        # try to get it, but ... no guarantees.
        $Parameters = Get-Variable -ValueOnly -ErrorAction SilentlyContinue -Name PSBoundParameters -Scope $scope
    }

    if ( !$FunctionName )
    {
        # try to get it, but ... no guarantees.

        if ( [Management.Automation.InvocationInfo]$_myinvocation =
            Get-Variable -ValueOnly -ErrorAction SilentlyContinue -Name MyInvocation -Scope $Scope )
        {
            $FunctionName = $_myInvocation.MyCommand.Name
        }

        # increase it by one because we need the paramters of the function named $FUNCTIONAME, not the
        # variables in scope containing the $MYINVOCATION variable containing the calling function name

        $scope++

        if ( !$FunctionName )
        {
            # if we didn't get anything back, then it's time to bail
            break
        }

        if (
            Get-Command -CommandType Function -Name $functionName* |
            Where-Object -Property Name -EQ $FunctionName
        )
        {
            # if we hit a function (as opposed to, say a .PSM1) call it good. Yes, sometimes the
            #parent-scope MyInvocation returns the .PSM1 file name. #WhiskeyTangoFoxtrot?
            break
        }
    }

    if ( !$FunctionName )
    {
        # if we failed, punt. It's the calling function's problem.
        throw 'Out-Parameters -FunctionName not specified and cannot be determined. Required.'
    }

    ( Get-Command -Name $FunctionName -CommandType Function ).Parameters.Keys |
    ForEach-Object -Process `
    {
        # get the parameters the calling function (or what we hope is the calling function)

        $value = Get-Variable -Name $_* -Scope $Scope -ErrorAction SilentlyContinue |
        Where-Object -Property Name -EQ -Value $_ |
        Select-Object -ExpandProperty Value

        if ( $value )
        {
            $Parameters.$_ = $value
        }
    }

    if ( $AsObject )
    {
        # return the [hashtable], because that's what the calling funciton expects
        return $Parameters
    }

    # otherwise, dump it out as [string[]]
    # we're doing all these stringops because we want to display the parameters ordered by name
    # this will make debugging easier if we compare one log from "this works" with the failing one
    $parameterStrings = (
        $Parameters |
        Out-String
    ) -split '[\r\n]+' -notmatch '^\s*$' -replace '\s+$'

    if ( $parameterStrings.count -gt 2 )
    {
        # first two lines are the headers
        $parameterStrings[ 0, 1 ]

        $parameterStrings[ 2 ..( $parameterStrings.Count - 1 ) ] |
        Sort-Object
    }

    #> # function Out-Parameters
}


function Write-VerboseParameters
{
    <#
        .synopsis
        Write parameters supplied to calling function.

        .description
        For logging or debugging, it is often useful to dump the paramters with which the function
        was called. Unfortunatley, $PSBoundParameters does not report defalut parameter values.
        Additionally, because of variable scoping, it can be difficult to use shared code to get
        parameter values.

        This provides a best-effort attempt to display the parameters supplied to the calling function.

        .parameter FunctionName
        Optional (but highly recommended!) parameter used to specify the calling function. If not
        supplied, this function will use $MyInvocation value(s) from increasing scope to attempt to
        determine the calling function name, but that can be highly brittle.

        .parameter Parameters
        Optional (but highly recommended!) parameter into which to specify $PSBoundParameters from
        the calling function. Again, if not supplied, this function will use Get-Variable to
        attempt to obtain $PSBoundParameters from the calling scope, but this can be highly brittle
        with the variety of ways a function can be invoked, defined, etc.

        .parameter Scope
        Value passed to Get-Variable -Scope parameter to get parameter values from the calling function.

        .example
        function Test-It { param ( $a, $b, $c ); Write-VerboseParameters -FunctionName Test-It -Parameters $PSBoundParameters}

        Using it in a function to output the [string[]] array to VERBOSE

        .example
        Test-It -a 3 -c $false -Verbose

        Example of sample output to VERBOSE:

        VERBOSE: Test-It was called with the following parameters:
        Name                           Value
        ----                           -----
        a                              3
        c                              False
        Verbose                        True
    #>

    [CmdletBinding()]

    param
    (
        [hashtable]$Parameters = @{ },

        [string]$FunctionName = $null,

        [int]$Scope = 1
    )

    if ( !$Parameters )
    {
        # try to get it, but ... no guarantees.
        $Parameters = Get-Variable -ValueOnly -ErrorAction SilentlyContinue -Name PSBoundParameters -Scope $scope
    }

    if ( !$FunctionName )
    {
        # try to get it, but ... no guarantees.

        if ( [Management.Automation.InvocationInfo]$_myinvocation =
            Get-Variable -ValueOnly -ErrorAction SilentlyContinue -Name MyInvocation -Scope $Scope )
        {
            $FunctionName = $_myInvocation.MyCommand.Name
        }

        # increase it by one because we need the paramters of the function named $FUNCTIONAME, not the
        # variables in scope containing the $MYINVOCATION variable containing the calling function name

        $scope++

        if ( !$FunctionName )
        {
            # if we didn't get anything back, then it's time to bail
            break
        }

        if (
            Get-Command -CommandType Function -Name $functionName* |
            Where-Object -Property Name -EQ $FunctionName
        )
        {
            # if we hit a function (as opposed to, say a .PSM1) call it good. Yes, sometimes the
            #parent-scope MyInvocation returns the .PSM1 file name. #WhiskeyTangoFoxtrot?
            break
        }
    }

    if ( !$FunctionName )
    {
        # if we failed, punt. It's the calling function's problem.
        throw 'Out-Parameters -FunctionName not specified and cannot be determined. Required.'
    }

    [string]$parameterStrings = ( Out-Parameters -Parameters $Parameters -FunctionName $FunctionName -Scope 2 ) -join "`n"

    "$functionName called with the following parameters:`n$parameterStrings" |
    Write-Verbose

    #> # function Write-VerboseParameter
}


function Write-WarningException
{
    <#
        .SYNOPSIS
        Normalize error formatting.

        .PARAMETER FunctionName
        Function (or other string indicating context) in which error occurred.

        .PARAMETER ErrorRecord
        [Management.Automation.ErrorRecord] object containing exception.

        .EXAMPLE
        try { ... } catch { Write-WarningException -FunctionName $functionName -ErrorRecord $_ -Folder $errLogDir }
    #>

    [CmdletBinding()]

    param
    (
        [string]$FunctionName = '',

        [Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$Folder = $( [IO.Path]::GetTempFileName() -replace '\.tmp$' )
    )

    if ( !$FunctionName )
    {
        # try to get it, but ... no guarantees.

        if ( [Management.Automation.InvocationInfo]$_myinvocation =
            Get-Variable -ValueOnly -ErrorAction SilentlyContinue -Name MyInvocation -Scope $Scope )
        {
            $FunctionName = $_myInvocation.MyCommand.Name
        }

        # increase it by one because we need the paramters of the function named $FUNCTIONAME, not the
        # variables in scope containing the $MYINVOCATION variable containing the calling function name

        $scope++

        if ( !$FunctionName )
        {
            # if we didn't get anything back, then it's time to bail
            break
        }

        if (
            Get-Command -CommandType Function -Name $functionName* |
            Where-Object -Property Name -EQ $FunctionName
        )
        {
            # if we hit a function (as opposed to, say a .PSM1) call it good. Yes, sometimes the
            #parent-scope MyInvocation returns the .PSM1 file name. #WhiskeyTangoFoxtrot?
            break
        }
    }

    Write-Warning -Message "$FunctionName threw exception:"
    $ErrorRecord |
    Write-Warning

    # save exception as PSObject as CliXml for later investigation
    $errorCliXmlPath = "$FolderName\${functionName}_Error_" +
    "$( Get-Date -Format 'yyyy-MM-dd_HH-mm-ss_fff' ).CliXml" -replace '>'

    Write-Warning -Message "Saving `$ErrorRecord to '$errorCliXmlPath'"
    New-Item -Force -Path $errorCliXmlPath -ItemType File |
    Select-Object -ExpandProperty FullName |
    Write-Verbose

    $ErrorRecord |
    Export-Clixml -Path $errorCliXmlPath

    # give detailed stacktrace data.
    $ErrorRecord.ErrorDetails_ScriptStackTrace -split '[\r\n]+' |
    ForEach-Object -Process `
    {
        # reformat stack trace output so we can copy-paste them as Set-PSBreakpoint parameters.
        [string]$line = $_ -replace '<(Begin|Process|End|ScriptBlock)>, (.*\\.*): line (\d+)',
        "<`$1> -Script `$2 -Line `$3"

        Write-Warning -Message "    $line"
    }

    #> # function Receive-CaughtException
}


########################################
#endregion debugging functions
#region utility functions
########################################


function Test-Command
{
    <#
        .synopsis
        Does command exist?

        .parameter Name
        Name of command. Mandatory.

        .parameter CommandType
        Type of command.

        .parameter AsObject
        Return the [Management.Automation.CommandInfo] object
    #>

    [CmdletBinding()]

    param (
        [string]$Name = $( throw '-Name not specified. Required.' ),

        [Management.Automation.CommandTypes]$CommandType = 'All',

        [switch]$AsObject
    )

    [Management.Automation.CommandInfo]$commandInfo =
    Get-Command -CommandType $CommandType -Name $Name* |
    Where-Object -Property Name -EQ -Value $Name

    if ( $AsObject )
    {
        return $commandInfo
    }

    $commandInfo -as [bool]

    #> # function Test-Command
}


function Write-Null
{

    <#
        .synopsis
        Suppress Write-Host

        .description
        Alias Write-Host to this to suppress it in other scripts.

        .example
        Set-Alias -Scope Global -Name Write-Host -Value Write-Null
        #>

}


function Write-StandardOut
{
    <#
        .synopsis
        Redirect Write-Host to STDOUT

        .description
        Alias Write-Host to this to send output to STDOUT

        .example
        Set-Alias -Scope Global -Name Write-Host -Value Write-StandardOut
    #>

    begin
    {
        [switch]$inPipeline = $false
    }

    process
    {
        if ( $input.Value )
        {
            # $input -as [bool] is always $true, so we have to look at $input.Value
            # to determine if we're being called in pipeline or not

            $input

            if ( !$inPipeline )
            {
                $inPipeline = $true
            }
        }
    }

    end
    {
        if ( !$inPipeline )
        {
            $args
        }
    }

    #> # function Write-StandardOut
}


function Write-ProgressPipeline
{
    <#
        .SYNOPSIS
        Provide a Write-Progress for a long-running pipeline for signs of life.

        .PARAMETER InputObject
        Data stream to count.

        .PARAMETER Activity
        Write-Progress -Activity parameter value.

        .PARAMETER StatusSuffix
        Write-Progress -Status will be populated with a running count of objects passed through.
        This will be appened to give an indication of what type of objects are being counted.

        .PARAMETER TotalObjects
        If provided, this function will specify a -PercentComplete to Write-Progress

        .PARAMETER Interval
        How often to update the Write-Progress, expressed in terms of the count of objects
        to pass through before sending another Write-Progress call.

        .PARAMETER ID
        Write-Progress -Id Parameter value.

        .PARAMETER BreadCrumb
        Not used, but included so the function can accept -BreadCrumb parameter if called with it.

        .PARAMETER Initialize
        Output a 'starting condition' message: dummy Write-Verbose, dummy Write-Progress to indicate starting state.

        .EXAMPLE
        $kustoData | Write-Progress -Activity Get-KustoIpamAllocationsData -StatusSuffix 'IPAM allocation records processed' -TotalObjects $kustoData.Count -Interval 1000 -Id $writeProgressId

        Writes the following as Write-Progress to update the user on current progres at a given
        point in the Get-KustoIpamAllocationsData function.

        Get-KustoIpamAllocationsData
        26000 / 34973 (74%) IPAM allocation records processed
        [ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo                          ]
        Current time: 15:23:46  Elapsed time: 00:08:21  Expected completion: 15:26:36

        Writes the following as to [Verbose] stream (visible if user specified -Verbose)

        Get-KustoIpamAllocationsData 26000 / 34973 (74%) IPAM allocation records processed
        Current time: 15:23:46  Elapsed time: 00:08:21  Expected completion: 15:26:36
    #>

    [CmdletBinding()]

    param
    (
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [PSCustomObject[]]$InputObject,

        [string]$Activity = ' ',

        [string]$StatusSuffix = 'objects processed',

        [uint32]$TotalObjects = 0,

        [ValidateRange( 1, 1MB )]
        [uint16]$Interval = 1000,

        [uint16]$Id = 0,

        [string[]]$BreadCrumb,

        [switch]$Initialize
    )

    begin
    {
        # this is an internal function, so we don't need the $functionName nor $BreadCrumb
        [uint32]$i = 0

        [DateTime]$startTime = Get-Date

        if ( !$Initialize )
        {
            [HashTable]$writeProgressPipelineParameters =
            @{
                Initialize   = $true
                InputObject  = 1
                Activity     = $Activity
                StatusSuffix = $StatusSuffix
                TotalObjects = $TotalObjects
                Interval     = $Interval
                Id           = $Id
            }

            # start it off with a noop record so the screen doesn't freeze until the first
            # interval count is reached.
            Write-ProgressPipeline @writeProgressPipelineParameters
        }

        if ( $TotalObjects )
        {
            [uint16]$fieldWidth = "$TotalObjects".Length
        }
    }

    process
    {
        if ( $Initialize )
        {
            [DateTime]$now = Get-Date

            [TimeSpan]$elapsedTime = $now - $startTime

            # trying to set $elapsedTimeMessage works on interactive console, but when run as scheduled task:
            #
            # ForEach-Object : Cannot overwrite variable elapsedTimeMessage because the variable has
            # been optimized. Try using the New-Variable or Set-Variable cmdlet (without any aliases),
            # or dot-source the command that you are using to set the variable.
            #
            # ... so , we're going to call Set-Variable instead.
            ' Current time: {3}  Elapsed time: {0:00}:{1:00}:{2:00}' -f `
            @(
                $elapsedTime.TotalHours
                $elapsedTime.Minutes
                $elapsedTime.Seconds
                ( Get-Date -Format 'HH:mm:ss' )
            ) |
            Set-Variable -Force -Name elapsedTimeMessage

            [HashTable]$writeProgressParameters =
            @{
                Activity = "$Activity "
                Id       = $Id
            }

            if ( $TotalObjects )
            {
                $writeProgressParameters.Status = "{0,$fieldWidth} / $TotalObjects (0%) $StatusSuffix" -f $i
                $writeProgressParameters.PercentComplete = 0
            }
            else
            {
                $writeProgressParameters.Status = "$i $StatusSuffix"
            }

            $writeProgressParameters.CurrentOperation = "$elapsedTimeMessage  Expected completion: ??:??:??"

            Write-Verbose -Message ( "$Activity $( $writeProgressParameters.Status )`n    $elapsedTimeMessage " )
            Write-Progress @writeProgressParameters

            return

        } #  if ( $Initialize )

        $InputObject |
        ForEach-Object -Process `
        {
            $i++

            if ( !( $i % $Interval ) )
            {
                [DateTime]$now = Get-Date

                [TimeSpan]$elapsedTime = $now - $startTime

                ' Current time: {3}  Elapsed time: {0:00}:{1:00}:{2:00}' -f `
                @(
                    $elapsedTime.TotalHours
                    $elapsedTime.Minutes
                    $elapsedTime.Seconds
                    ( Get-Date -Format 'HH:mm:ss' )
                ) |
                Set-Variable -Force -Name elapsedTimeMessage

                [HashTable]$writeProgressParameters =
                @{
                    Activity = "$Activity "
                    Id       = $Id
                }

                if ( $TotalObjects )
                {
                    # if we have a count of the total objects in the pipeline, we can estimate
                    # when we'll be done

                    # -PercentComplete
                    [int]$percentComplete = ( 100 * $i / $TotalObjects ) % 101
                    $writeProgressParameters.Status = "{0,$fieldWidth} / $TotalObjects ($percentComplete%) $StatusSuffix" -f $i
                    $writeProgressParameters.PercentComplete = $percentComplete

                    # -CurrentOperation will give an estimate as to when it completes
                    [double]$totalMilliSeconds = $elapsedTime.TotalMilliseconds

                    [int]$toDoCount = $TotalObjects - $i

                    if ( $toDoCount )
                    {
                        if ( $toDoCount -le 0 )
                        {
                            return
                        }

                        # this is an empirical formula (translation: trial and error) to try to
                        # compensate for irregularities in sampling data. the theory behind it
                        # is that the larger the individual operation takes to do, the greater
                        # the chance that the aggregation of the remaining operations will take
                        # longer than the single sample. however, the fewer remaining operations
                        # remain to do, the lower the overall effect of this estimated skew.
                        #
                        # or, you can just treat it like I do: it works, so I don't care why.
                        #
                        # for pulling IPAM records, it allows 35 samples of 1000 records per sample
                        # across ~35000 records to have an estimated end-of-processing [DateTime]
                        # to be consistent within 2 minutes of the actual time.
                        [double]$fudgeFactor = ( 1 + [Math]::Log10( [Math]::Log10( [Math]::Log( $toDoCount ) ) ) ) / $i / 1000

                        [double]$secondsToAdd = $totalMilliSeconds * $toDoCount * $fudgeFactor

                        if ( $secondsToAdd -gt 0 )
                        {
                            # usually, we'll need to update the banner

                            try
                            {
                                [DateTime]$expectedCompletion = $now.AddSeconds( $secondsToAdd )
                            }
                            catch
                            {
                                Write-Debug -Message $secondsToAdd
                                $_ |
                                Write-Warning
                                $secondsToAdd = 0
                            }

                        } # if ( $secondsToAdd -gt 0 )
                        else
                        {
                            [DateTime]$expectedCompletion = $now
                        }

                    } # if ( $toDoCount )
                    else
                    {
                        $secondsToAdd = 0
                        [DateTime]$expectedCompletion = $now
                    }

                    if ( $secondsToAdd -le 0 )
                    {
                        [DateTime]$expectedCompletion = $now
                    }

                    $elapsedTimeMessage += '  Expected completion: {0:00}:{1:00}:{2:00}' -f `
                    @(
                        $expectedCompletion.Hour
                        $expectedCompletion.Minute
                        $expectedCompletion.Second
                    )

                } # if ( $TotalObjects )
                else
                {
                    $writeProgressParameters.Status = "$i $StatusSuffix"
                }

                $writeProgressParameters.CurrentOperation = $elapsedTimeMessage

                Write-Verbose -Message ( "$Activity $( $writeProgressParameters.Status )`n    $elapsedTimeMessage " )
                Write-Progress @writeProgressParameters

            } # if ( !( $i % $Interval ) )

            $_

        } # $InputObject |

    }

    end
    {
        if ( !$Initialize )
        {
            # we want the Write-Progress bar to persist after we initialize it
            Write-Progress -Status ' ' -Activity ' ' -Id $Id -Completed
        }
    }

    #> # function Write-ProgressPipeline
}


########################################
#endregion utility functions
#region function group 1
########################################


$null = @'
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
        DefaultParameterSetName = 'Planet Parameter Set',
        SupportsShouldProcess,
        PositionalBinding = $false,
        HelpUri = 'http://www.microsoft.com/',
        ConfirmImpact = 'Medium'
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
            ParameterSetName = 'Planet Parameter Set',
            Position = 0
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
            ParameterSetName = 'Planet Parameter Set',
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
            ParameterSetName = 'Any Object Parameter Set',
            Position = 20
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

'@


########################################
#endregion initialization
<#

#>