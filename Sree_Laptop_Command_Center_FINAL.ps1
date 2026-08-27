# FINAL DESKTOP WINDOW BUILD - native movable/resizable Windows frame`r`n#Requires -Version 5.1
#Requires -RunAsAdministrator
# SREE LAPTOP COMMAND CENTER - TRANSPARENT FUTURISTIC PREMIUM
# Comprehensive error handling, UI transparency, and robust logging included.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = 'Continue'
$script:RunningTask = $null

$ReportDir = Join-Path $env:USERPROFILE 'Desktop\Sree_Laptop_Reports'
$BackupDir = Join-Path $env:USERPROFILE 'Sree_Laptop_Backup'
New-Item -ItemType Directory -Force -Path $ReportDir,$BackupDir | Out-Null
$LogFile = Join-Path $ReportDir 'Command_Center_Log.txt'

# Comprehensive logging utility for debugging
function Write-Log([string]$Message) {
    $line = "$(Get-Date -Format 'dd/MM/yyyy hh:mm:ss tt') | $Message"
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    if ($script:ActivityBox) {
        $script:ActivityBox.Text = ($line + "`r`n" + $script:ActivityBox.Text)
    }
}

function Confirm-Action([string]$Message) {
    [System.Windows.MessageBox]::Show($Message, 'Command Center', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -eq [System.Windows.MessageBoxResult]::Yes
}

function Show-Info([string]$Title,[string]$Message) {
    [System.Windows.MessageBox]::Show($Message,$Title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Run-Command([string]$Title,[string]$Command,[bool]$NeedsConfirmation=$false) {
    if ($NeedsConfirmation -and -not (Confirm-Action "Run $Title?`r`n`r`nThis operation can change Windows or installed files.")) { return }

    Write-Log "START: $Title"
    $safe = $Title -replace '[^A-Za-z0-9_-]','_'
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $out = Join-Path $ReportDir "${stamp}_${safe}.txt"
    $err = "${out}.error.txt"

    try {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
        $p = Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -WindowStyle Hidden
        $script:RunningTask = [pscustomobject]@{ Process=$p; Title=$Title; Output=$out; Error=$err }
        $script:Status.Text = "RUNNING | $Title"
    } catch {
        Write-Log "ERROR: Failed to start process for $Title. $($_.Exception.Message)"
        Show-Info 'Command Error' $_.Exception.Message
    }
}

function Open-Setting([string]$Uri,[string]$Title) {
    try { Start-Process $Uri; Write-Log "OPENED: $Title" } catch { Show-Info 'Unable to open' $_.Exception.Message }
}
function Open-SystemTool([string]$File,[string]$Title) {
    try { Start-Process $File; Write-Log "OPENED: $Title" } catch { Show-Info 'Unable to open' $_.Exception.Message }
}

function Safe-BatteryReport {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $battery) {
        Write-Log 'Battery report skipped: no battery detected.'
        return Show-Info 'Battery Report' 'No Windows battery device was detected.'
    }
    $path = Join-Path $ReportDir 'Battery_Report.html'
    powercfg /batteryreport /output "$path" | Out-Null
    if (Test-Path $path) { Start-Process $path; Write-Log "Battery report created: $path" }
}

function Backup-Folder([string]$Source,[string]$Destination,[string]$Title) {
    if (-not (Test-Path $Source)) { return Show-Info $Title "Source folder not found:`r`n$Source" }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $exclude = "`"$BackupDir`""
    Run-Command $Title "robocopy `"$Source`" `"$Destination`" /E /Z /R:2 /W:2 /XJ /FFT /XD $exclude" $true
}


function Create-SystemReport {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $path = Join-Path $ReportDir "Complete_System_Report_$stamp.txt"
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
            Select-Object DeviceID,VolumeName,@{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}}
        $phys = Get-PhysicalDisk -ErrorAction SilentlyContinue |
            Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size
        $net = Get-NetIPConfiguration -ErrorAction SilentlyContinue
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue

        @(
            "SREE LAPTOP COMMAND CENTER - COMPLETE SYSTEM REPORT"
            "Generated: $(Get-Date -Format 'dd/MM/yyyy hh:mm:ss tt')"
            ""
            "=== COMPUTER ==="
            "Computer Name : $env:COMPUTERNAME"
            "User Name     : $env:USERNAME"
            "Manufacturer  : $($cs.Manufacturer)"
            "Model         : $($cs.Model)"
            "System Type   : $($cs.SystemType)"
            ""
            "=== WINDOWS ==="
            "OS            : $($os.Caption)"
            "Version       : $($os.Version)"
            "Build         : $($os.BuildNumber)"
            "Architecture  : $($os.OSArchitecture)"
            "Last Boot     : $($os.LastBootUpTime)"
            ""
            "=== CPU ==="
            "Name          : $($cpu.Name)"
            "Cores         : $($cpu.NumberOfCores)"
            "Logical CPUs  : $($cpu.NumberOfLogicalProcessors)"
            ""
            "=== MEMORY ==="
            "Total GB      : $([math]::Round($os.TotalVisibleMemorySize/1MB,2))"
            "Free GB       : $([math]::Round($os.FreePhysicalMemory/1MB,2))"
            ""
            "=== LOGICAL DISKS ==="
            ($disks | Out-String)
            "=== PHYSICAL DISKS ==="
            ($phys | Out-String)
            "=== NETWORK ==="
            ($net | Out-String)
            "=== BATTERY ==="
            (($battery | Format-List * | Out-String) -replace '^\s+$','')
        ) | Set-Content -LiteralPath $path -Encoding UTF8

        Write-Log "REPORT CREATED: $path"
        $script:Status.Text = "READY | Report created"
        Start-Process notepad.exe $path
    } catch {
        Write-Log "ERROR: Report creation failed. $($_.Exception.Message)"
        Show-Info 'Report Error' $_.Exception.Message
    }
}

function Test-WingetAvailable {
    return [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
}

function Start-WingetCheck {
    if (-not (Test-WingetAvailable)) {
        Show-Info 'App Updates' 'WinGet is not installed or not available in this Windows session.'
        Write-Log 'WinGet unavailable.'
        return
    }
    Run-Command 'Check App Updates' 'winget.exe upgrade --accept-source-agreements'
}

function Start-WingetUpgrade {
    if (-not (Test-WingetAvailable)) {
        Show-Info 'App Updates' 'WinGet is not installed or not available in this Windows session.'
        Write-Log 'WinGet unavailable.'
        return
    }
    Run-Command 'Upgrade All Apps' 'winget.exe upgrade --all --accept-source-agreements --accept-package-agreements' $true
}

# ---------------- XAML (Futuristic Transparent UI) ----------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Sree Laptop Command Center - Premium"
        Width="1280" Height="820" MinWidth="1000" MinHeight="650"
        WindowStartupLocation="CenterScreen"
        WindowStyle="SingleBorderWindow"
        ResizeMode="CanResize"
        AllowsTransparency="False"
        Background="#050B16"
        ShowInTaskbar="True"
        Topmost="False"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="GlassButton" TargetType="Button">
            <Setter Property="Background" Value="#3000D9FF"/>
            <Setter Property="Foreground" Value="#E8F5FF"/>
            <Setter Property="BorderBrush" Value="#6000D9FF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="5,4"/>
            <Setter Property="Padding" Value="10,9"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="NavButton" BasedOn="{StaticResource GlassButton}" TargetType="Button">
            <Setter Property="Background" Value="#10FFFFFF"/>
            <Setter Property="BorderBrush" Value="#30FFFFFF"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
        </Style>
    </Window.Resources>

    <Border x:Name="MainBorder" Background="#07111F" CornerRadius="20" BorderBrush="#6000D9FF" BorderThickness="1">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="92"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="42"/>
            </Grid.RowDefinitions>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="260"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- HEADER / DRAG AREA -->
            <Border x:Name="DragHeader" Grid.Row="0" Grid.ColumnSpan="2" Background="#0B1730" CornerRadius="12,12,0,0" BorderBrush="#3000D9FF" BorderThickness="0,0,0,1" Cursor="Hand">
                <Grid Margin="22,0">
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="SREE" FontSize="31" FontWeight="Bold" Foreground="#00D9FF">
                            <TextBlock.Effect><DropShadowEffect Color="#00D9FF" BlurRadius="15" ShadowDepth="0"/></TextBlock.Effect>
                        </TextBlock>
                        <TextBlock Text="LAPTOP COMMAND CENTER // PREMIUM SYSTEM CARE" FontSize="12" FontWeight="SemiBold" Foreground="#F2F7FF"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBox x:Name="SearchBox" Width="260" Height="34" Background="#30000000" Foreground="#00D9FF" BorderBrush="#5000D9FF" Padding="10,7"/>
                        <Button x:Name="RefreshButton" Content="REFRESH" Width="85" Height="34" Margin="8,0,0,0" Style="{StaticResource GlassButton}"/>
                        <Button x:Name="MinButton" Content="MIN" Width="60" Height="34" Margin="8,0,0,0" Style="{StaticResource GlassButton}"/>
                        <Button x:Name="MaxButton" Content="MAX" Width="60" Height="34" Margin="8,0,0,0" Style="{StaticResource GlassButton}"/>
                        <Button x:Name="CloseButton" Content="EXIT SYSTEM" Width="100" Height="34" Margin="8,0,0,0" Style="{StaticResource GlassButton}" Foreground="#FF3B57" BorderBrush="#FF3B57"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- SIDEBAR -->
            <Border Grid.Row="1" Grid.Column="0" Background="#081525" BorderBrush="#3000D9FF" BorderThickness="0,0,1,0">
                <ScrollViewer>
                    <StackPanel Margin="10,16">
                        <TextBlock Text="SYSTEM NAVIGATION" Foreground="#00D9FF" FontSize="10" Margin="14,0,0,8"/>
                        <Button x:Name="NavDashboard" Content="Dashboard" Tag="all" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavHealth" Content="System Health" Tag="health" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavUpdates" Content="Updates &amp; Software" Tag="updates" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavClean" Content="Clean &amp; Optimize" Tag="clean" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavRepair" Content="Windows Repair" Tag="repair" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavNetwork" Content="Network Tools" Tag="network" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavDiagnostics" Content="Diagnostics" Tag="diagnostics" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavBackup" Content="Backup &amp; Reports" Tag="backup" Style="{StaticResource NavButton}"/>
                        <Button x:Name="NavPower" Content="Power Settings" Tag="power" Style="{StaticResource NavButton}"/>
                        
                        <Border Background="#20FF3CAC" BorderBrush="#8B35FF" BorderThickness="1" CornerRadius="12" Padding="10" Margin="3,20,3,0">
                            <StackPanel>
                                <TextBlock Text="QUICK ACTIONS" Foreground="#FF3CAC" FontWeight="Bold" FontSize="11" Margin="5,0,0,8"/>
                                <Button x:Name="QuickOverview" Content="System Overview" Style="{StaticResource NavButton}"/>
                                <Button x:Name="QuickClean" Content="Clean TEMP" Style="{StaticResource NavButton}"/>
                                <Button x:Name="QuickOptimize" Content="Safe Optimize" Style="{StaticResource NavButton}"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </Border>

            <!-- MAIN DATA AREA -->
            <ScrollViewer x:Name="MainScroll" Grid.Row="1" Grid.Column="1">
                <StackPanel x:Name="MainPanel" Margin="16,14,20,20">
                    <!-- METRICS HUD -->
                    <Grid Margin="0,0,0,14">
                        <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="#2000D9FF" BorderBrush="#00D9FF" BorderThickness="1" CornerRadius="12" Padding="14">
                            <StackPanel><TextBlock Text="SYSTEM HEALTH" Foreground="#00D9FF" FontSize="10"/><TextBlock x:Name="HealthValue" Text="READY" Foreground="#00F5A0" FontSize="23" FontWeight="Bold"/></StackPanel>
                        </Border>
                        <Border Grid.Column="1" Background="#202787FF" BorderBrush="#2787FF" BorderThickness="1" CornerRadius="12" Padding="14" Margin="7,0,0,0">
                            <StackPanel><TextBlock Text="CPU USAGE" Foreground="#2787FF" FontSize="10"/><TextBlock x:Name="CpuValue" Text="--%" Foreground="#F2F7FF" FontSize="23" FontWeight="Bold"/></StackPanel>
                        </Border>
                        <Border Grid.Column="2" Background="#20A855F7" BorderBrush="#A855F7" BorderThickness="1" CornerRadius="12" Padding="14" Margin="7,0,0,0">
                            <StackPanel><TextBlock Text="RAM USAGE" Foreground="#A855F7" FontSize="10"/><TextBlock x:Name="RamValue" Text="--%" Foreground="#F2F7FF" FontSize="23" FontWeight="Bold"/></StackPanel>
                        </Border>
                        <Border Grid.Column="3" Background="#20FF9D2E" BorderBrush="#FF9D2E" BorderThickness="1" CornerRadius="12" Padding="14" Margin="7,0,0,0">
                            <StackPanel><TextBlock Text="BATTERY" Foreground="#FF9D2E" FontSize="10"/><TextBlock x:Name="BatteryValue" Text="--" Foreground="#F2F7FF" FontSize="20" FontWeight="Bold"/></StackPanel>
                        </Border>
                        <Border Grid.Column="4" Background="#2000FF78" BorderBrush="#00E5FF" BorderThickness="1" CornerRadius="12" Padding="14" Margin="7,0,0,0">
                            <StackPanel><TextBlock Text="DISK HEALTH" Foreground="#00E5FF" FontSize="10"/><TextBlock x:Name="DiskValue" Text="--" Foreground="#00F5A0" FontSize="20" FontWeight="Bold"/></StackPanel>
                        </Border>
                        <Border Grid.Column="5" Background="#20FF3CAC" BorderBrush="#FF3CAC" BorderThickness="1" CornerRadius="12" Padding="14" Margin="7,0,0,0">
                            <StackPanel><TextBlock Text="UPTIME" Foreground="#FF3CAC" FontSize="10"/><TextBlock x:Name="UptimeValue" Text="--" Foreground="#F2F7FF" FontSize="18" FontWeight="Bold"/></StackPanel>
                        </Border>
                    </Grid>

                    <!-- DYNAMIC CATEGORY CARDS -->
                    <Grid x:Name="CategoryGrid">
                        <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                        <Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions>

                        <Border Tag="health" Grid.Row="0" Grid.Column="0" Background="#20008CFF" BorderBrush="#008CFF" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="SYSTEM HEALTH" Foreground="#00D9FF" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnOverview" Content="System Overview" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnCpuRam" Content="CPU and RAM Processes" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnDisk" Content="Disk and Volume Health" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnBattery" Content="Battery Report" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="updates" Grid.Row="0" Grid.Column="1" Background="#209B3CFF" BorderBrush="#9B3CFF" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="UPDATES &amp; SOFTWARE" Foreground="#B66CFF" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnCheckUpdates" Content="Check App Updates" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnUpgradeApps" Content="Upgrade All Apps" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnWindowsUpdate" Content="Windows Update" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="clean" Grid.Row="0" Grid.Column="2" Background="#2000C878" BorderBrush="#00C878" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="CLEAN &amp; OPTIMIZE" Foreground="#00F5A0" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnTemp" Content="Clean User TEMP" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnStorage" Content="Storage Sense" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnDiskCleanup" Content="Disk Cleanup" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="repair" Grid.Row="0" Grid.Column="3" Background="#20FF7A18" BorderBrush="#FF7A18" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="WINDOWS REPAIR" Foreground="#FF9D2E" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnDismScan" Content="DISM ScanHealth" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnDismRestore" Content="DISM RestoreHealth" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnSfc" Content="SFC scannow" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="network" Grid.Row="1" Grid.Column="0" Background="#2000D9FF" BorderBrush="#00D9FF" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="NETWORK TOOLS" Foreground="#00D9FF" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnNetInfo" Content="Network Information" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnDnsTest" Content="Internet and DNS Test" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnFlushDns" Content="Flush DNS" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="diagnostics" Grid.Row="1" Grid.Column="1" Background="#20FF3CAC" BorderBrush="#FF3CAC" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="DIAGNOSTICS" Foreground="#FF3CAC" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnChkdsk" Content="CHKDSK C Scan" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnDefScan" Content="Defender Quick Scan" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnTaskMgr" Content="Task Manager" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="backup" Grid.Row="1" Grid.Column="2" Background="#202787FF" BorderBrush="#2787FF" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="BACKUPS &amp; REPORTS" Foreground="#2787FF" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnBackupDocs" Content="Backup Documents" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnBackupDesktop" Content="Backup Desktop" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnSystemReport" Content="Complete Report" Style="{StaticResource GlassButton}"/>
                            </StackPanel>
                        </Border>

                        <Border Tag="power" Grid.Row="1" Grid.Column="3" Background="#20F5C400" BorderBrush="#F5C400" BorderThickness="1" CornerRadius="14" Margin="4" Padding="12">
                            <StackPanel>
                                <TextBlock Text="POWER SETTINGS" Foreground="#FFD43B" FontSize="15" FontWeight="Bold" Margin="0,0,0,10"/>
                                <Button x:Name="BtnControl" Content="Control Panel" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnRestart" Content="Restart System" Style="{StaticResource GlassButton}"/>
                                <Button x:Name="BtnShutdown" Content="Shutdown System" Style="{StaticResource GlassButton}" Foreground="#FF3B57"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <!-- HUD LOG TERMINAL -->
                    <Border Background="#30000000" BorderBrush="#5000D9FF" BorderThickness="1" CornerRadius="12" Padding="14" Margin="4,12,4,0">
                        <StackPanel>
                            <TextBlock Text="TERMINAL ACTIVITY LOG" Foreground="#00D9FF" FontWeight="Bold" FontSize="11"/>
                            <TextBox x:Name="ActivityBox" Background="Transparent" Foreground="#00F5A0" BorderThickness="0" IsReadOnly="True" TextWrapping="NoWrap" FontSize="11" Height="90" FontFamily="Consolas" VerticalScrollBarVisibility="Auto"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- FOOTER -->
            <Border Grid.Row="2" Grid.ColumnSpan="2" Background="#2000D9FF" CornerRadius="0,0,20,20" BorderBrush="#3000D9FF" BorderThickness="0,1,0,0">
                <Grid Margin="18,0">
                    <TextBlock x:Name="Status" Text="READY | SECURE MODE ON" Foreground="#00F5A0" VerticalAlignment="Center" FontSize="11" FontWeight="Bold">
                        <TextBlock.Effect><DropShadowEffect Color="#00F5A0" BlurRadius="5" ShadowDepth="0"/></TextBlock.Effect>
                    </TextBlock>
                    <TextBlock x:Name="ClockText" Foreground="#00D9FF" HorizontalAlignment="Right" VerticalAlignment="Center" FontSize="11"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
'@

try {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $script:Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "UI Initialization failed: $($_.Exception.Message)"
    exit 1
}

# Native resize support for the borderless futuristic window.
# This keeps the custom design while restoring normal Windows edge/corner resizing.
if (-not ('SreeNativeResize' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class SreeNativeResize {
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
}
"@
}

$script:Window.Add_SourceInitialized({
    $source = [System.Windows.Interop.HwndSource]::FromVisual($script:Window)
    $source.AddHook({
        param($hwnd,$msg,$wParam,$lParam,[ref]$handled)
        if($msg -eq 0x0084 -and $script:Window.WindowState -ne [Windows.WindowState]::Maximized) {
            $pt = New-Object -TypeName 'SreeNativeResize+POINT'
            $rc = New-Object -TypeName 'SreeNativeResize+RECT'
            [SreeNativeResize]::GetCursorPos([ref]$pt) | Out-Null
            [SreeNativeResize]::GetWindowRect($hwnd,[ref]$rc) | Out-Null
            $edge = 8
            $left   = $pt.X -lt ($rc.Left + $edge)
            $right  = $pt.X -ge ($rc.Right - $edge)
            $top    = $pt.Y -lt ($rc.Top + $edge)
            $bottom = $pt.Y -ge ($rc.Bottom - $edge)
            $hit = 1
            if($top -and $left){$hit=13}
            elseif($top -and $right){$hit=14}
            elseif($bottom -and $left){$hit=16}
            elseif($bottom -and $right){$hit=17}
            elseif($left){$hit=10}
            elseif($right){$hit=11}
            elseif($top){$hit=12}
            elseif($bottom){$hit=15}
            if($hit -ne 1){ $handled=$true; return [IntPtr]$hit }
        }
        return [IntPtr]::Zero
    })
})

# Variable Binding
$names = @('DragHeader','CloseButton','SearchBox','RefreshButton','MinButton','MaxButton','NavDashboard','NavHealth','NavUpdates','NavClean','NavRepair','NavNetwork','NavDiagnostics','NavBackup','NavPower','QuickOverview','QuickClean','QuickOptimize','HealthValue','CpuValue','RamValue','BatteryValue','DiskValue','UptimeValue','BtnOverview','BtnCpuRam','BtnDisk','BtnBattery','BtnCheckUpdates','BtnUpgradeApps','BtnWindowsUpdate','BtnTemp','BtnStorage','BtnDiskCleanup','BtnDismScan','BtnDismRestore','BtnSfc','BtnNetInfo','BtnDnsTest','BtnFlushDns','BtnChkdsk','BtnDefScan','BtnTaskMgr','BtnBackupDocs','BtnBackupDesktop','BtnSystemReport','BtnControl','BtnRestart','BtnShutdown','ActivityBox','Status','ClockText','CategoryGrid')
foreach($name in $names) { Set-Variable -Name $name -Value $script:Window.FindName($name) -Scope Script }

# Window Behaviors
$CloseButton.Add_Click({ $script:Window.Close() })
$DragHeader.Add_MouseLeftButtonDown({
    if ($_.ClickCount -eq 2 -and $script:Window.WindowState -ne [Windows.WindowState]::Minimized) {
        if ($script:Window.WindowState -eq [Windows.WindowState]::Maximized) {
            $script:Window.WindowState = [Windows.WindowState]::Normal
        } else {
            $script:Window.WindowState = [Windows.WindowState]::Maximized
        }
    }
})

function Refresh-Metrics {
    try {
        # Error handling applied to WMI calls for robustness
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object LoadPercentage -Average
        $script:CpuValue.Text = if($cpu.Average -ne $null) { "{0:N0}%" -f $cpu.Average } else { "N/A" }
        
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if($os) {
            $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $usedPct = if($totalGB -gt 0) { [math]::Round((($totalGB - $freeGB) / $totalGB) * 100) } else { 0 }
            $script:RamValue.Text = "$usedPct%"
            $uptime = (Get-Date) - $os.LastBootUpTime
            $script:UptimeValue.Text = "{0}d {1}h" -f $uptime.Days,$uptime.Hours
        }

        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        $script:BatteryValue.Text = if($battery) { "$($battery.EstimatedChargeRemaining)%" } else { "N/A" }

        $physical = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.HealthStatus -ne $null }
        $badDisk = $physical | Where-Object { $_.HealthStatus -notin @('Healthy','Unknown') -or $_.OperationalStatus -notcontains 'OK' }
        $script:DiskValue.Text = if(-not $physical) { "N/A" } elseif($badDisk) { "CHECK" } else { "GOOD" }

        $script:ClockText.Text = Get-Date -Format 'dddd, dd MMMM yyyy | hh:mm:ss tt'
    } catch {
        Write-Log "Metric refresh encountered an issue: $($_.Exception.Message)"
    }
}

function Bind-Command($button,$title,$command,[bool]$confirm=$false) {
    $button.Add_Click({
        param($sender,$eventArgs)
        Run-Command $sender.TagTitle $sender.TagCommand $sender.TagConfirm
    })
    $button | Add-Member NoteProperty TagTitle $title -Force
    $button | Add-Member NoteProperty TagCommand $command -Force
    $button | Add-Member NoteProperty TagConfirm $confirm -Force
}

# Bindings
Bind-Command $BtnOverview 'System Overview' 'Get-ComputerInfo | Select WindowsProductName,WindowsVersion,OsBuildNumber,OsArchitecture; Get-CimInstance Win32_Processor | Select Name,NumberOfCores,NumberOfLogicalProcessors; Get-CimInstance Win32_ComputerSystem | Select Manufacturer,Model,@{N="RAM_GB";E={[math]::Round($_.TotalPhysicalMemory/1GB,2)}}'
Bind-Command $BtnCpuRam 'CPU/RAM Processes' 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name,@{N="CPUSeconds";E={[math]::Round($_.CPU,1)}},Id,WorkingSet64'
Bind-Command $BtnDisk 'Disk Health' 'Get-PhysicalDisk | Select FriendlyName,MediaType,HealthStatus,OperationalStatus,@{N="SizeGB";E={[math]::Round($_.Size/1GB,1)}}'
$BtnBattery.Add_Click({ Safe-BatteryReport })

$BtnCheckUpdates.Add_Click({ Start-WingetCheck })
$BtnUpgradeApps.Add_Click({ Start-WingetUpgrade })
$BtnWindowsUpdate.Add_Click({ Open-Setting 'ms-settings:windowsupdate' 'Windows Update' })

Bind-Command $BtnTemp 'Clean TEMP' 'Get-ChildItem "$env:TEMP" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; "User TEMP cleanup completed."' $true
$BtnStorage.Add_Click({ Open-Setting 'ms-settings:storagesense' 'Storage Sense' })
$BtnDiskCleanup.Add_Click({ Open-SystemTool 'cleanmgr.exe' 'Disk Cleanup' })

Bind-Command $BtnDismScan 'DISM ScanHealth' 'DISM.exe /Online /Cleanup-Image /ScanHealth'
Bind-Command $BtnDismRestore 'DISM RestoreHealth' 'DISM.exe /Online /Cleanup-Image /RestoreHealth' $true
Bind-Command $BtnSfc 'SFC scannow' 'sfc.exe /scannow' $true

Bind-Command $BtnNetInfo 'Network Information' 'Get-NetIPConfiguration; Get-NetAdapter | Where-Object Status -eq "Up" | Select Name,InterfaceDescription,LinkSpeed,MacAddress'
Bind-Command $BtnDnsTest 'Internet and DNS Test' 'Test-NetConnection 1.1.1.1 -InformationLevel Detailed; Resolve-DnsName example.com'
Bind-Command $BtnFlushDns 'Flush DNS' 'ipconfig.exe /flushdns'

Bind-Command $BtnChkdsk 'CHKDSK C Scan' 'chkdsk.exe C: /scan'
Bind-Command $BtnDefScan 'Defender Quick Scan' 'if(Get-Command Start-MpScan -ErrorAction SilentlyContinue){Start-MpScan -ScanType QuickScan}else{"Microsoft Defender cmdlet is unavailable on this system."}' $true
$BtnTaskMgr.Add_Click({ Open-SystemTool 'taskmgr.exe' 'Task Manager' })

$BtnBackupDocs.Add_Click({ Backup-Folder (Join-Path $env:USERPROFILE 'Documents') (Join-Path $BackupDir 'Documents') 'Backup Documents' })
$BtnBackupDesktop.Add_Click({ Backup-Folder (Join-Path $env:USERPROFILE 'Desktop') (Join-Path $BackupDir 'Desktop') 'Backup Desktop' })
$BtnSystemReport.Add_Click({ Create-SystemReport })

$BtnControl.Add_Click({ Open-SystemTool 'control.exe' 'Control Panel' })
$BtnRestart.Add_Click({ if(Confirm-Action 'Restart Windows now?'){ Restart-Computer -Force } })
$BtnShutdown.Add_Click({ if(Confirm-Action 'Shut down Windows now?'){ Stop-Computer -Force } })

$QuickOverview.Add_Click({ Run-Command 'Quick System Overview' 'Get-ComputerInfo | Select WindowsProductName,WindowsVersion,OsBuildNumber,OsArchitecture' })
$QuickClean.Add_Click({ Run-Command 'Clean TEMP' 'Get-ChildItem "$env:TEMP" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; "User TEMP cleanup completed."' $true })
$QuickOptimize.Add_Click({ Open-Setting 'ms-settings:storagesense' 'Storage Sense' })

# Search: filter visible command buttons by their caption.
$allActionButtons = @(
    $BtnOverview,$BtnCpuRam,$BtnDisk,$BtnBattery,
    $BtnCheckUpdates,$BtnUpgradeApps,$BtnWindowsUpdate,
    $BtnTemp,$BtnStorage,$BtnDiskCleanup,
    $BtnDismScan,$BtnDismRestore,$BtnSfc,
    $BtnNetInfo,$BtnDnsTest,$BtnFlushDns,
    $BtnChkdsk,$BtnDefScan,$BtnTaskMgr,
    $BtnBackupDocs,$BtnBackupDesktop,$BtnSystemReport,
    $BtnControl,$BtnRestart,$BtnShutdown
)
$SearchBox.Add_TextChanged({
    $q = $SearchBox.Text.Trim().ToLowerInvariant()
    foreach($b in $script:AllActionButtons) {
        $visible = ($q -eq '' -or ([string]$b.Content).ToLowerInvariant().Contains($q))
        $b.Visibility = if($visible){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
    }
}.GetNewClosure())
$script:AllActionButtons = $allActionButtons

# Navigation: scroll the matching category card into view.
$navMap = @{
    $NavDashboard = 'all'
    $NavHealth = 'health'
    $NavUpdates = 'updates'
    $NavClean = 'clean'
    $NavRepair = 'repair'
    $NavNetwork = 'network'
    $NavDiagnostics = 'diagnostics'
    $NavBackup = 'backup'
    $NavPower = 'power'
}
foreach($pair in $navMap.GetEnumerator()) {
    $button = $pair.Key
    $tag = $pair.Value
    $button.Add_Click({
        if($tag -eq 'all') { $MainScroll.ScrollToHome(); return }
        foreach($child in $CategoryGrid.Children) {
            if($child.Tag -eq $tag) { $child.BringIntoView(); break }
        }
    }.GetNewClosure())
}

$RefreshButton.Add_Click({ Refresh-Metrics; Write-Log 'Dashboard refreshed.' })
$MinButton.Add_Click({ $script:Window.WindowState = [Windows.WindowState]::Minimized })
$MaxButton.Add_Click({
    if($script:Window.WindowState -eq [Windows.WindowState]::Maximized) {
        $script:Window.WindowState = [Windows.WindowState]::Normal
        $MaxButton.Content = 'MAX'
    } else {
        $script:Window.WindowState = [Windows.WindowState]::Maximized
        $MaxButton.Content = 'RESTORE'
    }
})
$script:Window.Add_StateChanged({
    if($script:Window.WindowState -eq [Windows.WindowState]::Maximized){$MaxButton.Content='RESTORE'}else{$MaxButton.Content='MAX'}
})

# Task Monitor
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(800)
$timer.Add_Tick({
    try {
        if($script:RunningTask -and $script:RunningTask.Process.HasExited) {
            $task = $script:RunningTask
            $output = if(Test-Path $task.Output){Get-Content $task.Output -Raw -ErrorAction SilentlyContinue}else{''}
            if($output){ Write-Log "OUTPUT: $($task.Title)`r`n$output" }
            $exitCode = $task.Process.ExitCode
            if($exitCode -eq 0){ Write-Log "END: $($task.Title) | ExitCode=0 | SUCCESS"; $script:Status.Text = "READY | SUCCESS: $($task.Title)" }
            else { Write-Log "END: $($task.Title) | ExitCode=$exitCode"; $script:Status.Text = "READY | COMPLETED WITH CODE ${exitCode}: $($task.Title)" }
            $script:RunningTask = $null
            Refresh-Metrics
        }
    } catch {
        # Suppress HasExited exception if process disposed too fast
        $script:RunningTask = $null
    }
    $script:ClockText.Text = Get-Date -Format 'dddd, dd MMMM yyyy | hh:mm:ss tt'
})
$timer.Start()

Write-Log 'System Online. All dashboard actions loaded.'
Refresh-Metrics
[void]$script:Window.ShowDialog()
$timer.Stop()