# IIS detection
$IIS = $false
if (Get-Service -Name W3SVC 2>$null) {
    $IIS = $true
}

if ($IIS) {
    # IIS logging
    if (Get-Service -Name W3SVC 2>$null) {
        try {
            C:\Windows\System32\inetsrv\appcmd.exe set config /section:httpLogging /dontLog:False
            Write-Host "[" -NoNewline; Write-Host "SUCCESS" -ForegroundColor Green -NoNewline; Write-Host "] IIS Logging Enabled" -ForegroundColor White
        }
        catch {
            Write-Host "[" -NoNewline; Write-Host "SUCCESS" -ForegroundColor Green -NoNewline; Write-Host "] IIS Logging failed" -ForegroundColor White
        }
    }

    # Imports the WebAdministration module
    Import-Module WebAdministration
    
    # Gets all sites under IIS:\Sites
    $sites = Get-ChildItem IIS:\Sites

    foreach ($site in $sites) {
        $siteName = $site.Name
        $siteBindings = Get-WebBinding -Name $siteName

        $isWebServer = $false
        $isFtpServer = $false

        # Checks the bindings to differentiate between web and FTP servers
        foreach ($binding in $siteBindings) {
            $bindingInformation = $binding.BindingInformation
            Write-Host "Site: $siteName - Binding: $bindingInformation"
            
            # Checks if the site is an HTTP/HTTPS web server (based on common HTTP/HTTPS ports)
            if ($bindingInformation -match ":80" -or $bindingInformation -match ":443") {
                $isWebServer = $true
                Write-Host "$siteName is an HTTP/HTTPS web server"
            }

            # Checks if the site is an FTP server (based on FTP port 21)
            if ($bindingInformation -match ":21") {
                $isFtpServer = $true
                Write-Host "$siteName is an FTP server"
            }
        }

        # Applies hardening steps for Web Server
        if ($isWebServer) {
            Write-Host "Applying Web server hardening for $siteName"

            # Set application pool privileges to minimum for application pools
            foreach ($item in (Get-ChildItem IIS:\AppPools)) { 
                $tempPath = "IIS:\AppPools\" + $item.Name
                Set-ItemProperty -Path $tempPath -Name processModel.identityType -Value 4
            }

            # Disables directory browsing for all sites using appcmd
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/directoryBrowse /enabled:"False"

            # Enables logging for all sites using appcmd
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/httpLogging /dontLog:"True" /commit:apphost
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/httpLogging /selectiveLogging:"LogAll" /commit:apphost

            # Disables anonymous authentication for all sites using Set-WebConfiguration
            Set-WebConfiguration -Filter "/system.webServer/security/authentication/anonymousAuthentication" -PSPath "IIS:\Sites\$siteName" -Value 0

            # Sets HTTP Errors statusCode to 405 for all sites
            Set-WebConfiguration -Filter "/system.webServer/httpErrors" -PSPath "IIS:\Sites\$siteName" -Value @{errorMode="Custom"; existingResponse="Replace"; statusCode=405}

            # Applies request filtering to block potentially dangerous file extensions
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/security/requestFiltering /+"fileExtensions.[fileExtension='exe',allowed='False']"
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/security/requestFiltering /+"fileExtensions.[fileExtension='bat',allowed='False']"
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/security/requestFiltering /+"fileExtensions.[fileExtension='ps1',allowed='False']"

            # Applies request filtering to block HTTP TRACE and OPTIONS
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/security/requestFiltering /+"verbs.[verb='OPTIONS',allowed='False']"
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.webServer/security/requestFiltering /+"verbs.[verb='TRACE',allowed='False']"

            # Enables Logging for IIS Web Management
            reg add "HKLM\Software\Microsoft\WebManagement\Server" /v EnableLogging /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "Enabled IIS Web Management Logging."

            # Enables Remote Management for IIS
            reg add "HKLM\Software\Microsoft\WebManagement\Server" /v EnableRemoteManagement /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "Enabled IIS Remote Management."

            # Enables IIS Admin Logging to ABO Mapper Log
            reg add "HKLM\System\CurrentControlSet\Services\IISADMIN\Parameters" /v EnableABOMapperLog /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "Enabled IIS Admin Logging to ABO Mapper Log."

            # Disables TRACE HTTP Method (Security Measure)
            reg add "HKLM\System\CurrentControlSet\Services\W3SVC\Parameters" /v EnableTraceMethod /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "Disabled TRACE HTTP Method."

            # Disables OPTIONS HTTP Method (Security Measure)
            reg add "HKLM\System\CurrentControlSet\Services\W3SVC\Parameters" /v EnableOptionsMethod /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "Disabled OPTIONS HTTP Method."

            # Requires Windows Credentials for Remote IIS Management
            reg add "HKLM\SOFTWARE\Microsoft\WebManagement\Server" /v RequiresWindowsCredentials /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "Enforced Windows Credentials for IIS Remote Management."

            # Prevents overrideMode for authentication settings (CURRENTLY LOCKS OUT USER)
            #Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication" -Name "overrideMode" -Value "Deny" -PSPath "IIS:\Sites\$siteName"

        }

        # Applies hardening steps for FTP Server
        if ($isFtpServer) {
            Write-Host "Applying FTP server hardening for $siteName"

            # Enables basic authentication for FTP
            Set-WebConfigurationProperty -pspath "IIS:\" -filter "system.applicationHost/sites/site[@name='$siteName']/ftpServer/security/authentication/basicAuthentication" -name "enabled" -value "true"

            # Disables anonymous authentication for FTP
            Set-WebConfigurationProperty -pspath "IIS:\" -filter "system.applicationHost/sites/site[@name='$siteName']/ftpServer/security/authentication/anonymousAuthentication" -name "enabled" -value "false"

            # Limits the maximum number of simultaneous FTP connections
            Set-WebConfigurationProperty -pspath "IIS:\" -filter "system.applicationHost/sites/site[@name='$siteName']/ftpServer/connections" -name "maxConnections" -value 5
            
            # Enables Central FTP Logging
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.ftpServer/log /centralLogFileMode:"Central" /commit:apphost
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.ftpServer/log /centralLogFile.enabled:"True" /commit:apphost

            # Other important file handling settings
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.applicationHost/sites /siteDefaults.ftpServer.fileHandling.keepPartialUploads:"False" /commit:apphost.ftpServer.logFile.enabled:"True" /commit:apphost
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.applicationHost/sites /siteDefaults.ftpServer.fileHandling.allowReadUploadsInProgress:"False" /commit:apphost.ftpServer.logFile.enabled:"True" /commit:apphost
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.applicationHost/sites /siteDefaults.ftpServer.fileHandling.allowReplaceOnRename:"False" /commit:apphost.ftpServer.logFile.enabled:"True" /commit:apphost

            # Limits the size of files uploaded to the FTP server
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.ftpServer/security/requestFiltering /requestLimits.maxAllowedContentLength:"1000000" /requestLimits.maxUrl:"1024" /commit:apphost
            
            # Blocks dangerous file extensions
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.ftpServer/security/requestFiltering /+"fileExtensions.[fileExtension='.bat',allowed='False']" /commit:apphost
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.ftpServer/security/requestFiltering /+"fileExtensions.[fileExtension='.exe',allowed='False']" /commit:apphost
            C:\Windows\System32\inetsrv\appcmd.exe set config $siteName -section:system.ftpServer/security/requestFiltering /+"fileExtensions.[fileExtension='.ps1',allowed='False']" /commit:apphost
        }
    }
    # Restarts IIS services to apply changes
    Write-Host "Restarting IIS services to apply changes..."
    iisreset

    Write-Host "[INFO] IIS Hardening Configurations Applied Successfully."
}


