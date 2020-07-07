Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -name PsGallery -InstallationPolicy Trusted
Install-Module -Name PowerShellGet -Force
Install-Module -Name Az -AllowClobber 
