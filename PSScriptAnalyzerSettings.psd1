@{
    # PSAvoidUsingWriteHost is excluded deliberately, not overlooked.
    #
    # v1.0.0 replaced every Write-Host with Write-Information to satisfy this rule. CI went
    # green and two observability defects went in with it:
    #
    #   1. $InformationPreference defaults to SilentlyContinue, so nothing printed to the
    #      console at all - including "[X] CRITICAL PIPELINE FAILURE".
    #   2. Start-Transcript in PowerShell 5.1 does not capture the information stream.
    #      Measured on Windows PowerShell 5.1.26100.8972 from a non-interactive script:
    #        Write-Information -> absent from transcript
    #        Write-Host        -> captured
    #        Write-Warning     -> captured
    #
    # Defect 2 is the serious one. These scripts run unattended across reboots, and the
    # transcripts under C:\DDU are the only evidence a run happened. Silent transcripts are
    # exactly how this repository shipped code that had never been executed.
    #
    # The rule targets reusable modules, where emitting to the host breaks composability.
    # These are operator-facing runbooks whose output is meant for a human at a console and
    # for the transcript. Write-Host is the correct cmdlet here.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}
