Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function Definitions (Same as before)
function Get-NetstatInfo {
    $output = netstat -ano
    $ignore_full = @('*:*', 'Address')
    $ignore_ip = @('[', '127.0.0.1', '0.0.0.0', '')
    $found_ips = @()

    $output | ForEach-Object {
        $ip_port = ($_ -split '\s+' -match '\S')[2]
        $ip = ""
        if ($ip_port -like "*:*") {
            $ip = $ip_port.Split(':')[0]
        }
        if ($found_ips -notcontains $ip_port -and $ignore_full -notcontains $ip_port -and $ignore_ip -notcontains $ip -and -not [string]::IsNullOrWhiteSpace($ip_port)) {          
            $found_ips += $ip_port
        }
    }
    return $found_ips | ForEach-Object { "GREP:$env:computername:$_:netstat" }
}

function Get-IPConfigInfo {
    $output = ipconfig /all | findstr /V Subnet
    $ips = ([regex]'\d+\.\d+\.\d+\.\d+').Matches($output) | ForEach-Object { $_.Value }
    return $ips | ForEach-Object { "GREP:$env:computername:$_:ipconfig" }
}

function Get-ARPInfo {
    $output = arp -a | findstr 'dynamic'
    $ips = ([regex]'\d+\.\d+\.\d+\.\d+').Matches($output) | ForEach-Object { $_.Value }
    return $ips | ForEach-Object { "GREP:$env:computername:$_:arp" }
}

function Get-TaskListInfo {
    $output = tasklist /v | findstr /V "===" | findstr /V "User Name"
    $found_tasks = @()

    $output | ForEach-Object {
        $parts = $_ -split '\s{3,}'
        if ($parts.Length -gt 4) {
            $task_info = "$($parts[0]):$($parts[4])"
            if ($found_tasks -notcontains $task_info) {
                $found_tasks += $task_info
            }
        }
    }
    return $found_tasks | ForEach-Object { "GREP:$env:computername:$_:tasklist" }
}

function Get-RouteInfo {
    return route print
}

function Get-NetSessionInfo {
    $output = net session | findstr /V "Computer" | findstr /V "\-\-\-\-" | findstr /V "command completed" | findstr /V "no entries"
    $ips = ([regex]'\d+\.\d+\.\d+\.\d+').Matches($output) | ForEach-Object { $_.Value }
    return $ips | ForEach-Object { "GREP:$env:computername:$_:net_session" }
}

function Get-LocalAdminsInfo {
    $output = net localgroup "Administrators" | Where-Object { $_ -and $_ -notmatch "command completed successfully" } | Select-Object -Skip 4
    $found_admins = @()

    $output | ForEach-Object {
        if ($found_admins -notcontains $_) {
            $found_admins += $_
        }
    }
    return $found_admins | ForEach-Object { "GREP:$env:computername:$_:localadmins" }
}

function Get-SystemInfo {
    $computerName = (Get-WmiObject Win32_ComputerSystem).Name
    $domain = (Get-WmiObject Win32_ComputerSystem).Domain
    $currentUser = Get-WMIObject Win32_Process | ForEach-Object {
        $owner = $_.GetOwner()
        '{0}\{1}' -f $owner.Domain, $owner.User
    } | Sort-Object | Get-Unique

    return @(
        "GREP:$env:computername:$computerName:systemname",
        "GREP:$env:computername:$domain:domain",
        "GREP:$env:computername:$currentUser:username"
    )
}

function Get-ReconInfo {
    $allInfo = @()

    $allInfo += Get-NetstatInfo
    $allInfo += Get-IPConfigInfo
    $allInfo += Get-ARPInfo
    $allInfo += Get-TaskListInfo
    $allInfo += Get-RouteInfo
    $allInfo += Get-NetSessionInfo
    $allInfo += Get-LocalAdminsInfo
    $allInfo += Get-SystemInfo

    return $allInfo
}

function Show-ReconInfoGUI {
    # Create UI Elements
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Recon Info Tool'
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240) # Light Gray Background

    # Create a title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'Network Reconnaissance Tool'
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.AutoSize = $true
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $form.Controls.Add($titleLabel)

    # Create a button to run the recon info
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Location = New-Object System.Drawing.Point(10, 50)
    $runButton.Size = New-Object System.Drawing.Size(120, 30)
    $runButton.Text = 'Run Recon'
    $runButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215) # Windows Blue
    $runButton.ForeColor = [System.Drawing.Color]::White
    $runButton.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($runButton)

    # Create a multiline textbox to display output
    $outputBox = New-Object System.Windows.Forms.TextBox
    $outputBox.Multiline = $true
    $outputBox.Location = New-Object System.Drawing.Point(10, 90)
    $outputBox.Size = New-Object System.Drawing.Size(760, 460)
    $outputBox.ScrollBars = 'Vertical'
    $outputBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $form.Controls.Add($outputBox)

    # Button Click Event Handler
    $runButton.Add_Click({
        $outputBox.Clear()

        # Run the reconnaissance function
        $output = Get-ReconInfo | Out-String

        # Display output in the textbox
        $outputBox.Text = $output -replace "\r?\n", "`r`n"  # Ensure correct new lines
    })

    # Show the form
    [void]$form.ShowDialog()
}

# Invoke the GUI
Show-ReconInfoGUI
