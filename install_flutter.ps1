$target = Join-Path $HOME "flutter"
if (!(Test-Path $target)) {
    Write-Host "Downloading Flutter zip..."
    $zipPath = Join-Path $HOME "flutter.zip"
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip" -OutFile $zipPath
    Write-Host "Extracting Flutter..."
    Expand-Archive -Path $zipPath -DestinationPath $HOME -Force
    Remove-Item $zipPath
}
$bin = Join-Path $target "bin"
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($path -notmatch [regex]::Escape($bin)) {
    Write-Host "Adding $bin to User PATH"
    [Environment]::SetEnvironmentVariable('Path', "$path;$bin", 'User')
}
else {
    Write-Host "Flutter bin is already in User PATH"
}
Write-Host "Flutter installation script completed successfully."
