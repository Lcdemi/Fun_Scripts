param(
    [Parameter()]
    [String]$filepath 
)

try {
    [string[]]$AllowUsers = Get-Content $filepath
} catch {
    Write-Host "[ERROR] Unable to get list of users"
    exit 1
}

Function Set-Password([string]$UserName, [SecureString]$Password, [SecureString]$Password2) {
    $pwd1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    $pwd2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password2))

    if ($pwd1_text -cne $pwd2_text) {
        Write-Host "[ERROR] Passwords don't match" 
        exit
    } else {
        Set-LocalUser -Name $UserName -Password $Password
        Write-Host "[INFO] Password set for" $UserName
    }
}

Function Secure([string[]]$UserList) {
    $LocalUsers = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='True' and name!='$Env:Username'"
    foreach ($LocalUser in $LocalUsers) {
        if ($LocalUser.Name -in $UserList) {
            Write-Host "[INFO] Securing $($LocalUser.name)"
            $LocalUser | Set-LocalUser -PasswordNeverExpires $false -UserMayChangePassword $true -AccountNeverExpires
            Write-Host "[" -NoNewline; Write-Host "SUCCESS" -ForegroundColor Green -NoNewline; Write-Host "] $($LocalUser.name) Secured" -ForegroundColor White
        }
    }
}

while ($true) {
    Write-Host "Options:"
    Write-Host "1. Change passwords for all users in list"
    Write-Host "2. Change password for current user"
    Write-Host "3. Secure all users in list"
    Write-Host "4. Exit"
    $option = Read-Host "Enter an option"
    
    if ($option -eq '1') {
        Clear-Host
        $Password = Read-Host -AsSecureString "Password"
        $Password2 = Read-Host -AsSecureString "Confirm Password"
        foreach ($user in $AllowUsers) {
            Set-Password -UserName $user -Password $Password -Password2 $Password2
        }
    } elseif ($option -eq '2') {
        Clear-Host
        $Password = Read-Host -AsSecureString "Password"
        $Password2 = Read-Host -AsSecureString "Confirm Password"
        Set-Password -UserName $Env:UserName -Password $Password -Password2 $Password2
    } elseif ($option -eq '3') {
        Secure -UserList $AllowUsers
    } elseif ($option -eq '4') {
        exit 0
    } else {
        Write-Host "Invalid option, try again"
    }
}