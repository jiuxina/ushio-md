[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string] $SourcePath
)

$ErrorActionPreference = 'Stop'
$taskRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..')
)
$taskSource = [System.IO.Path]::GetFullPath($SourcePath)
$taskDestination = [System.IO.Path]::Combine(
    $taskRoot, 'assets', 'milkdown_web'
)
$taskRootPrefix = $taskRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $taskSource.StartsWith($taskRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    $taskSource.StartsWith($taskDestination, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The build source must be inside this repository and outside the runtime destination.'
}
foreach ($taskEntry in @('index.html', 'pdf-math.html')) {
    $taskEntryPath = [System.IO.Path]::Combine($taskSource, $taskEntry)
    if (-not [System.IO.File]::Exists($taskEntryPath) -or
        ([System.IO.FileInfo]::new($taskEntryPath)).Length -eq 0) {
        throw "Missing runtime entry: $taskEntry"
    }
}
$taskFiles = [System.IO.Directory]::GetFiles($taskSource)
if ([System.IO.Directory]::GetDirectories($taskSource).Length -gt 0) {
    throw 'Runtime assets must be flat for MilkdownAssetServer.'
}
if ($PSCmdlet.ShouldProcess($taskDestination, "Replace runtime with $($taskFiles.Length) built files")) {
    if ([System.IO.Directory]::Exists($taskDestination)) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $taskDestination,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
        )
    }
    $null = [System.IO.Directory]::CreateDirectory($taskDestination)
    foreach ($taskFile in $taskFiles) {
        [System.IO.File]::Copy(
            $taskFile,
            [System.IO.Path]::Combine($taskDestination, [System.IO.Path]::GetFileName($taskFile)),
            $false
        )
    }
    Write-Output "Synced $($taskFiles.Length) runtime assets."
}
