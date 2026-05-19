# ============================================================
#   J.A.R.V.I.S  WORKSPACE  -  UNIFIED BUILDER + COOKER
# ============================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# ---- Single-instance guard ----
# If another copy is already running, focus its window and exit.
$Script:JarvisMutexCreated = $false
$Script:JarvisMutex = New-Object System.Threading.Mutex($true, "Local\JarvisWorkspaceSingleton", [ref]$Script:JarvisMutexCreated)
if (-not $Script:JarvisMutexCreated) {
    Add-Type -Namespace Jarvis -Name Win -MemberDefinition @"
        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
        public static extern System.IntPtr FindWindowW(string lpClassName, string lpWindowName);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(System.IntPtr hWnd);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool BringWindowToTop(System.IntPtr hWnd);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern System.IntPtr GetForegroundWindow();
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
        [System.Runtime.InteropServices.DllImport("kernel32.dll")]
        public static extern uint GetCurrentThreadId();
"@
    $hwnd = [Jarvis.Win]::FindWindowW($null, "J.A.R.V.I.S  |  Workspace")
    if ($hwnd -ne [IntPtr]::Zero) {
        $pid_out = [uint32]0
        $fgWnd     = [Jarvis.Win]::GetForegroundWindow()
        $fgThread  = [Jarvis.Win]::GetWindowThreadProcessId($fgWnd, [ref]$pid_out)
        $myThread  = [Jarvis.Win]::GetCurrentThreadId()

        [Jarvis.Win]::AttachThreadInput($myThread, $fgThread, $true) | Out-Null
        # SW_RESTORE = 9 (always restore, whether minimized or normal — this also pulls it
        # to the current virtual desktop on Windows 11).
        [Jarvis.Win]::ShowWindow($hwnd, 9) | Out-Null
        [Jarvis.Win]::BringWindowToTop($hwnd) | Out-Null
        [Jarvis.Win]::SetForegroundWindow($hwnd) | Out-Null
        [Jarvis.Win]::AttachThreadInput($myThread, $fgThread, $false) | Out-Null

        # Fallback: if it still isn't foreground, kick it with minimize+restore.
        if ([Jarvis.Win]::GetForegroundWindow() -ne $hwnd) {
            [Jarvis.Win]::ShowWindow($hwnd, 6) | Out-Null  # SW_MINIMIZE
            [Jarvis.Win]::ShowWindow($hwnd, 9) | Out-Null  # SW_RESTORE
        }
    }
    exit 0
}

# ---- Paths & Constants ----
$AppDir       = Join-Path $env:APPDATA "JarvisWorkspace"
$ProfilesDir  = Join-Path $AppDir "profiles"
$VD           = Join-Path $env:USERPROFILE "AppData\Local\JarvisTools\VirtualDesktop.exe"

if (-not (Test-Path $ProfilesDir)) { New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null }

$SeedPath = Join-Path $ProfilesDir "office.json"
if (-not (Test-Path $SeedPath)) {
    $seed = [pscustomobject]@{
        name      = "office"
        return_to = 0
        desktops  = @(
            @{ name = "Office";    shortcuts = @() },
            @{ name = "Terminals"; shortcuts = @() },
            @{ name = "Personal";  shortcuts = @() }
        )
    }
    ($seed | ConvertTo-Json -Depth 6) | Set-Content -Path $SeedPath -Encoding UTF8
}

# ---- Shared engine helpers ----
function Wait-WindowByPid($targetPid, $timeoutSec = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        $p = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
        if ($p -and $p.MainWindowHandle -ne 0) { return $p }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Wait-WindowByName($hint, $timeoutSec = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        $p = Get-Process -ErrorAction SilentlyContinue |
             Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -match $hint } |
             Sort-Object StartTime -Descending | Select-Object -First 1
        if ($p) { return $p }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Move-ToDesktop($proc, $deskIdx) {
    if ($proc -and $proc.MainWindowHandle -ne 0) {
        $hwnd = [int64]$proc.MainWindowHandle
        & $VD "/GetDesktop:$deskIdx" "/MoveWindowHandle:$hwnd" | Out-Null
    }
}

function Invoke-CookProfile($wsProfile, $logCallback) {
    if (-not (Test-Path $VD)) {
        & $logCallback "[ERROR] VirtualDesktop.exe not found." "Red"
        return $false
    }
    if (-not $wsProfile -or -not $wsProfile.desktops -or $wsProfile.desktops.Count -eq 0) {
        & $logCallback "[ERROR] Profile is empty." "Red"
        return $false
    }

    & $logCallback ("Cooking '{0}' ..." -f $wsProfile.name) "Green"

    & $VD "/Count" | Out-Null
    $baseCount = $LASTEXITCODE
    if ($baseCount -lt 1) { $baseCount = 1 }

    & $logCallback ("Preserving {0} existing desktop(s). Appending {1} new desktop(s)." -f $baseCount, $wsProfile.desktops.Count) "Cyan"

    for ($i=0; $i -lt $wsProfile.desktops.Count; $i++) {
        & $VD "/New" | Out-Null
        Start-Sleep -Milliseconds 350
    }
    for ($i=0; $i -lt $wsProfile.desktops.Count; $i++) {
        $newIdx = $baseCount + $i
        & $VD "/Switch:$newIdx" ("/Name:" + $wsProfile.desktops[$i].name) | Out-Null
        Start-Sleep -Milliseconds 250
    }

    for ($i=0; $i -lt $wsProfile.desktops.Count; $i++) {
        $newIdx = $baseCount + $i
        $d = $wsProfile.desktops[$i]
        & $logCallback ("[{0}/{1}] {2}" -f ($i+1), $wsProfile.desktops.Count, $d.name) "Yellow"
        & $VD "/Switch:$newIdx" | Out-Null
        Start-Sleep -Milliseconds 600

        if (-not $d.shortcuts -or $d.shortcuts.Count -eq 0) {
            & $logCallback "    (empty)" "Gray"
            continue
        }
        foreach ($sc in $d.shortcuts) {
            $label = [System.IO.Path]::GetFileNameWithoutExtension($sc)
            if (-not (Test-Path $sc)) {
                & $logCallback ("    > {0,-22} [NOT FOUND]" -f $label) "Red"
                continue
            }
            $p = $null
            $launched = $false
            try {
                $p = Start-Process -FilePath $sc -PassThru -ErrorAction Stop
                $launched = $true
            } catch {
                try {
                    Start-Process -FilePath $sc -ErrorAction Stop
                    $launched = $true
                } catch {
                    & $logCallback ("    > {0,-22} [FAILED: {1}]" -f $label, $_.Exception.Message) "Red"
                }
            }

            if ($launched) {
                $proc = $null
                if ($p -and $p.Id) { $proc = Wait-WindowByPid $p.Id 8 }
                if (-not $proc) {
                    $hint = ($label -replace '[^a-zA-Z]', '').ToLower()
                    if ($hint.Length -ge 3) { $proc = Wait-WindowByName $hint 12 }
                }
                if ($proc) {
                    Move-ToDesktop $proc $newIdx
                    & $logCallback ("    > {0,-22} [OK]" -f $label) "Cyan"
                } else {
                    & $logCallback ("    > {0,-22} [launched, window not detected]" -f $label) "DarkYellow"
                }
            }
            Start-Sleep -Milliseconds 800
        }
    }

    $retOffset = 0
    if ($null -ne $wsProfile.return_to) { $retOffset = [int]$wsProfile.return_to }
    $retIdx = $baseCount + $retOffset
    & $VD "/Switch:$retIdx" | Out-Null

    & $logCallback "ALL SYSTEMS GO. Let's Cook, Boss." "Green"
    return $true
}

# ---- GUI (XAML) ----
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="J.A.R.V.I.S  |  Workspace"
        Height="780" Width="1020"
        Background="#0B0F0D"
        WindowStartupLocation="CenterScreen"
        FontFamily="Consolas">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent"    Color="#2EE6A6"/>
    <SolidColorBrush x:Key="AccentDim" Color="#1F8F6B"/>
    <SolidColorBrush x:Key="TextMain"  Color="#D6F5E6"/>
    <SolidColorBrush x:Key="TextDim"   Color="#7A8F84"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#1A2620"/>
      <Setter Property="Foreground" Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource AccentDim}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#0F1411"/>
      <Setter Property="Foreground" Value="{StaticResource TextMain}"/>
      <Setter Property="BorderBrush" Value="{StaticResource AccentDim}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="6,3"/>
      <Setter Property="CaretBrush" Value="{StaticResource Accent}"/>
    </Style>

    <Style x:Key="ComboBoxToggleBtn" TargetType="ToggleButton">
      <Setter Property="Background" Value="#0F1411"/>
      <Setter Property="BorderBrush" Value="{StaticResource AccentDim}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Foreground" Value="{StaticResource TextMain}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="22"/>
                </Grid.ColumnDefinitions>
                <ContentPresenter Grid.Column="0" Margin="6,2,0,2" VerticalAlignment="Center"/>
                <Path Grid.Column="1" Data="M 0 0 L 4 4 L 8 0 Z" Fill="#2EE6A6" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background"   Value="#0F1411"/>
      <Setter Property="Foreground"   Value="{StaticResource TextMain}"/>
      <Setter Property="BorderBrush"  Value="{StaticResource AccentDim}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Name="ToggleButton" Style="{StaticResource ComboBoxToggleBtn}"
                            Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}" Foreground="{TemplateBinding Foreground}"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                            Focusable="False" ClickMode="Press"/>
              <ContentPresenter Name="ContentSite" IsHitTestVisible="False"
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                Margin="8,3,25,3" VerticalAlignment="Center" HorizontalAlignment="Left"/>
              <Popup Name="Popup" Placement="Bottom" Focusable="False" AllowsTransparency="True"
                     IsOpen="{TemplateBinding IsDropDownOpen}" PopupAnimation="Slide">
                <Grid Name="DropDown" SnapsToDevicePixels="True"
                      MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                  <Border Background="#0F1411" BorderBrush="{StaticResource AccentDim}" BorderThickness="1"/>
                  <ScrollViewer Margin="4" SnapsToDevicePixels="True">
                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                  </ScrollViewer>
                </Grid>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="{StaticResource TextMain}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Padding"    Value="8,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#22382E"/>
                <Setter Property="Foreground" Value="#2EE6A6"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#1A2620"/>
                <Setter Property="Foreground" Value="#2EE6A6"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource TextMain}"/>
    </Style>
  </Window.Resources>

  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#121814" Padding="16,12">
      <DockPanel>
        <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
          <TextBlock Text="J.A.R.V.I.S" FontSize="20" FontWeight="Bold" Foreground="{StaticResource Accent}"/>
          <TextBlock Text="  |  WORKSPACE" FontSize="14" Foreground="{StaticResource TextDim}" VerticalAlignment="Center" Margin="6,0,0,0"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <TextBlock Text="Profile:" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="{StaticResource TextDim}"/>
          <ComboBox Name="ProfileCombo" Width="180" Margin="0,0,8,0"/>
          <Button Name="BtnNew"    Content="+ NEW"    Margin="0,0,6,0"/>
          <Button Name="BtnRename" Content="RENAME"   Margin="0,0,6,0"/>
          <Button Name="BtnDelete" Content="DELETE"   Foreground="#E66B6B" BorderBrush="#7A2E2E"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <Border DockPanel.Dock="Bottom" Background="#121814" Padding="16,10">
      <DockPanel>
        <TextBlock Name="StatusText" Text="Ready." Foreground="{StaticResource TextDim}" VerticalAlignment="Center"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button Name="BtnToggleLog" Content="SHOW LOG" Margin="0,0,6,0"/>
          <Button Name="BtnAddDesk"   Content="+ ADD DESKTOP" Margin="0,0,6,0"/>
          <Button Name="BtnOpenDir"   Content="OPEN PROFILES FOLDER" Margin="0,0,6,0"/>
          <Button Name="BtnSave"      Content="SAVE PROFILE" Background="#0F2A1E" Foreground="{StaticResource Accent}" FontWeight="Bold" Padding="14,6" Margin="0,0,10,0"/>
          <Button Name="BtnCook"      Content="&#9654; LET'S COOK" Background="#0F2A1E" Foreground="#2EE6A6" FontWeight="Bold" Padding="18,6" BorderBrush="#2EE6A6" BorderThickness="2"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <Border Name="LogPanel" DockPanel.Dock="Bottom"
            Background="#080B09" BorderBrush="{StaticResource AccentDim}"
            BorderThickness="0,1,0,1" Height="240" Visibility="Collapsed">
      <DockPanel>
        <DockPanel DockPanel.Dock="Top" Background="#0F1411">
          <TextBlock Text="  >  COOK LOG" Foreground="{StaticResource Accent}" FontWeight="Bold" Padding="6,4" VerticalAlignment="Center"/>
          <Button Name="BtnClearLog" Content="CLEAR" HorizontalAlignment="Right" Margin="0,2,8,2" Padding="8,2" FontSize="10"/>
        </DockPanel>
        <RichTextBox Name="LogBox" IsReadOnly="True" Background="#080B09" Foreground="{StaticResource TextMain}"
                     BorderThickness="0" FontFamily="Consolas" FontSize="12" Padding="8"
                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <FlowDocument PagePadding="0"
                        IsOptimalParagraphEnabled="False"
                        IsHyphenationEnabled="False"
                        TextAlignment="Left"
                        FontFamily="Consolas"
                        FontSize="12">
            <Paragraph Name="LogPara" Margin="0" LineHeight="16"/>
          </FlowDocument>
        </RichTextBox>
      </DockPanel>
    </Border>

    <ScrollViewer VerticalScrollBarVisibility="Auto">
      <StackPanel Name="DesktopsPanel" Margin="14"/>
    </ScrollViewer>
  </DockPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

$ProfileCombo   = $Window.FindName("ProfileCombo")
$DesktopsPanel  = $Window.FindName("DesktopsPanel")
$StatusText     = $Window.FindName("StatusText")
$BtnNew         = $Window.FindName("BtnNew")
$BtnRename      = $Window.FindName("BtnRename")
$BtnDelete      = $Window.FindName("BtnDelete")
$BtnAddDesk     = $Window.FindName("BtnAddDesk")
$BtnSave        = $Window.FindName("BtnSave")
$BtnOpenDir     = $Window.FindName("BtnOpenDir")
$BtnCook        = $Window.FindName("BtnCook")
$BtnToggleLog   = $Window.FindName("BtnToggleLog")
$BtnClearLog    = $Window.FindName("BtnClearLog")
$LogPanel       = $Window.FindName("LogPanel")
$LogPara        = $Window.FindName("LogPara")
$LogBox         = $Window.FindName("LogBox")

$Script:CurrentProfile = $null
$Script:LogColorMap = @{
    "Red"        = "#E66B6B"
    "Green"      = "#2EE6A6"
    "Cyan"       = "#5AD1E6"
    "Yellow"     = "#E6C95A"
    "DarkYellow" = "#B89A3D"
    "Gray"       = "#7A8F84"
    "DarkGray"   = "#5E7268"
    "White"      = "#D6F5E6"
}

function Set-Status($msg, $color = "dim") {
    $StatusText.Text = $msg
    switch ($color) {
        "error"   { $StatusText.Foreground = [System.Windows.Media.Brushes]::IndianRed }
        "success" { $StatusText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2EE6A6") }
        default   { $StatusText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7A8F84") }
    }
}

function Add-LogLine($msg, $color = "White") {
    $bc = [System.Windows.Media.BrushConverter]::new()
    $hex = $Script:LogColorMap[$color]
    if (-not $hex) { $hex = "#D6F5E6" }
    $run = New-Object System.Windows.Documents.Run
    $run.Text = $msg
    $run.Foreground = $bc.ConvertFromString($hex)
    $LogPara.Inlines.Add($run) | Out-Null
    $LogPara.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) | Out-Null
    $LogBox.ScrollToEnd()
}

function Clear-Log { $LogPara.Inlines.Clear() }

function Show-LogPanel {
    $LogPanel.Visibility = 'Visible'
    $BtnToggleLog.Content = "HIDE LOG"
}

function Hide-LogPanel {
    $LogPanel.Visibility = 'Collapsed'
    $BtnToggleLog.Content = "SHOW LOG"
}

function Get-ProfileFiles {
    Get-ChildItem -Path $ProfilesDir -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name
}

function Refresh-ProfileList($selectName = $null) {
    $ProfileCombo.Items.Clear()
    foreach ($f in Get-ProfileFiles) { [void]$ProfileCombo.Items.Add($f.BaseName) }
    if ($selectName -and $ProfileCombo.Items.Contains($selectName)) {
        $ProfileCombo.SelectedItem = $selectName
    } elseif ($ProfileCombo.Items.Count -gt 0) {
        $ProfileCombo.SelectedIndex = 0
    }
}

function Load-Profile($name) {
    $path = Join-Path $ProfilesDir "$name.json"
    if (-not (Test-Path $path)) { return $null }
    try {
        $obj = Get-Content $path -Raw | ConvertFrom-Json
        if (-not $obj.desktops) { $obj | Add-Member -NotePropertyName desktops -NotePropertyValue @() -Force }
        if ($obj.PSObject.Properties.Name -contains 'name') { $obj.name = $name }
        else { $obj | Add-Member -NotePropertyName name -NotePropertyValue $name -Force }
        return $obj
    } catch { Set-Status "Failed to parse $name.json" "error"; return $null }
}

function Build-ProfileFromUI {
    $targetName = $null
    if ($ProfileCombo.SelectedItem) { $targetName = [string]$ProfileCombo.SelectedItem }
    elseif ($Script:CurrentProfile -and $Script:CurrentProfile.name) { $targetName = [string]$Script:CurrentProfile.name }
    if ([string]::IsNullOrWhiteSpace($targetName)) { return $null }

    $desks = @()
    foreach ($card in $DesktopsPanel.Children) {
        $nameBox = $card.Tag.NameBox
        $list    = $card.Tag.List
        $shortcuts = @()
        foreach ($item in $list.Items) { $shortcuts += [string]$item.Tag }
        $desks += @{ name = $nameBox.Text; shortcuts = $shortcuts }
    }

    $retTo = 0
    if ($Script:CurrentProfile -and $null -ne $Script:CurrentProfile.return_to) {
        $retTo = [int]$Script:CurrentProfile.return_to
    }

    return [pscustomobject]@{
        name      = $targetName
        return_to = $retTo
        desktops  = $desks
    }
}

function Save-CurrentProfile {
    $prof = Build-ProfileFromUI
    if (-not $prof) { Set-Status "Nothing to save." "error"; return $false }
    $Script:CurrentProfile = $prof
    $path = Join-Path $ProfilesDir ("{0}.json" -f $prof.name)
    ($prof | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
    Set-Status ("Saved -> {0}" -f $path) "success"
    return $true
}

function New-DesktopCard($deskName, $shortcuts) {
    $bc = [System.Windows.Media.BrushConverter]::new()
    $border = New-Object System.Windows.Controls.Border
    $border.Background      = $bc.ConvertFromString("#121814")
    $border.BorderBrush     = $bc.ConvertFromString("#1F8F6B")
    $border.BorderThickness = 1
    $border.Margin          = "0,0,0,12"
    $border.Padding         = "12"
    $border.CornerRadius    = 4

    $dock = New-Object System.Windows.Controls.DockPanel

    $headerDock = New-Object System.Windows.Controls.DockPanel
    [System.Windows.Controls.DockPanel]::SetDock($headerDock, "Top")
    $headerDock.Margin = "0,0,0,8"

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = "DESKTOP:"
    $lbl.Foreground = $bc.ConvertFromString("#7A8F84")
    $lbl.VerticalAlignment = "Center"
    $lbl.Margin = "0,0,8,0"
    [System.Windows.Controls.DockPanel]::SetDock($lbl, "Left")
    $headerDock.Children.Add($lbl) | Out-Null

    $nameBox = New-Object System.Windows.Controls.TextBox
    $nameBox.Text = $deskName
    $nameBox.MinWidth = 200
    $nameBox.MaxWidth = 320
    $nameBox.HorizontalAlignment = "Left"
    [System.Windows.Controls.DockPanel]::SetDock($nameBox, "Left")
    $headerDock.Children.Add($nameBox) | Out-Null

    $btnRemoveDesk = New-Object System.Windows.Controls.Button
    $btnRemoveDesk.Content = "REMOVE DESKTOP"
    $btnRemoveDesk.HorizontalAlignment = "Right"
    $btnRemoveDesk.Foreground = [System.Windows.Media.Brushes]::IndianRed
    $btnRemoveDesk.BorderBrush = $bc.ConvertFromString("#7A2E2E")
    $headerDock.Children.Add($btnRemoveDesk) | Out-Null

    [System.Windows.Controls.DockPanel]::SetDock($headerDock, "Top")
    $dock.Children.Add($headerDock) | Out-Null

    $list = New-Object System.Windows.Controls.ListBox
    $list.MinHeight = 90
    $list.Background = $bc.ConvertFromString("#0F1411")
    $list.Foreground = $bc.ConvertFromString("#D6F5E6")
    $list.BorderBrush = $bc.ConvertFromString("#1F8F6B")
    $list.AllowDrop = $true

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = "  [ Drop .lnk shortcuts here  -  or click 'Browse...' below ]"
    $hint.Foreground = $bc.ConvertFromString("#5E7268")
    $hint.IsHitTestVisible = $false
    $hint.Margin = "8,8,0,0"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Children.Add($list) | Out-Null
    $grid.Children.Add($hint) | Out-Null
    $dock.Children.Add($grid) | Out-Null

    $updateHint = {
        if ($list.Items.Count -eq 0) { $hint.Visibility = "Visible" } else { $hint.Visibility = "Collapsed" }
    }.GetNewClosure()

    $addShortcut = {
        param($path)
        if (-not $path) { return }
        $item = New-Object System.Windows.Controls.ListBoxItem
        $name = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $item.Content = "  - $name      ($path)"
        $item.Tag = $path
        $item.Foreground = $bc.ConvertFromString("#D6F5E6")

        $cm = New-Object System.Windows.Controls.ContextMenu
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = "Remove"
        $mi.Tag = $item
        $mi.Add_Click({
            param($s, $e)
            $target = $s.Tag
            if ($target -and $list.Items.Contains($target)) {
                $list.Items.Remove($target); & $updateHint
            }
        })
        $cm.Items.Add($mi) | Out-Null
        $item.ContextMenu = $cm

        $item.Add_MouseDoubleClick({
            param($s, $e)
            if ($list.Items.Contains($s)) { $list.Items.Remove($s); & $updateHint }
        })
        $item.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Delete' -and $list.Items.Contains($s)) {
                $list.Items.Remove($s); & $updateHint; $e.Handled = $true
            }
        })

        [void]$list.Items.Add($item)
        & $updateHint
    }.GetNewClosure()

    foreach ($s in $shortcuts) { & $addShortcut $s }
    & $updateHint

    $list.Add_PreviewDragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
        } else { $e.Effects = [System.Windows.DragDropEffects]::None }
        $e.Handled = $true
    })
    $list.Add_Drop({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            foreach ($f in $files) { & $addShortcut $f }
        }
    }.GetNewClosure())

    $footer = New-Object System.Windows.Controls.DockPanel
    [System.Windows.Controls.DockPanel]::SetDock($footer, "Bottom")
    $footer.Margin = "0,8,0,0"
    $btnBrowse = New-Object System.Windows.Controls.Button
    $btnBrowse.Content = "BROWSE..."
    $btnBrowse.HorizontalAlignment = "Left"
    $btnBrowse.Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        $ofd.Multiselect = $true
        $ofd.Filter = "Shortcuts & Apps (*.lnk;*.exe;*.url)|*.lnk;*.exe;*.url|All Files (*.*)|*.*"
        if ($ofd.ShowDialog()) { foreach ($f in $ofd.FileNames) { & $addShortcut $f } }
    }.GetNewClosure())
    $footer.Children.Add($btnBrowse) | Out-Null
    $dock.Children.Add($footer) | Out-Null

    $border.Child = $dock
    $border.Tag = [pscustomobject]@{ NameBox = $nameBox; List = $list }

    $btnRemoveDesk.Add_Click({ $DesktopsPanel.Children.Remove($border) }.GetNewClosure())

    return $border
}

function Render-Profile($prof) {
    $DesktopsPanel.Children.Clear()
    if (-not $prof) { return }
    foreach ($d in $prof.desktops) {
        $shortcuts = @()
        if ($d.shortcuts) { $shortcuts = @($d.shortcuts) }
        $card = New-DesktopCard $d.name $shortcuts
        $DesktopsPanel.Children.Add($card) | Out-Null
    }
}

$ProfileCombo.Add_SelectionChanged({
    if ($ProfileCombo.SelectedItem) {
        $Script:CurrentProfile = Load-Profile $ProfileCombo.SelectedItem
        Render-Profile $Script:CurrentProfile
        Set-Status ("Loaded profile: {0}" -f $ProfileCombo.SelectedItem)
    }
})

$BtnNew.Add_Click({
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("Profile name (letters, numbers, dashes):", "New Profile", "my-setup")
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $name = ($name -replace '[^a-zA-Z0-9_\-]', '').ToLower()
    if (-not $name) { return }
    $path = Join-Path $ProfilesDir "$name.json"
    if (Test-Path $path) { Set-Status "Profile already exists." "error"; return }
    $new = [pscustomobject]@{
        name = $name; return_to = 0
        desktops = @(@{ name = "Desktop 1"; shortcuts = @() })
    }
    ($new | ConvertTo-Json -Depth 6) | Set-Content -Path $path -Encoding UTF8
    Refresh-ProfileList $name
    Set-Status "Created '$name'." "success"
})

$BtnRename.Add_Click({
    if (-not $Script:CurrentProfile) { return }
    $old = $Script:CurrentProfile.name
    $new = [Microsoft.VisualBasic.Interaction]::InputBox("Rename profile:", "Rename", $old)
    if ([string]::IsNullOrWhiteSpace($new)) { return }
    $new = ($new -replace '[^a-zA-Z0-9_\-]', '').ToLower()
    if (-not $new -or $new -eq $old) { return }
    $oldPath = Join-Path $ProfilesDir "$old.json"
    $newPath = Join-Path $ProfilesDir "$new.json"
    if (Test-Path $newPath) { Set-Status "Target name exists." "error"; return }
    $Script:CurrentProfile.name = $new
    Save-CurrentProfile | Out-Null
    Remove-Item $oldPath -ErrorAction SilentlyContinue
    Refresh-ProfileList $new
})

$BtnDelete.Add_Click({
    if (-not $Script:CurrentProfile) { return }
    $n = $Script:CurrentProfile.name
    $confirm = [System.Windows.MessageBox]::Show("Delete profile '$n'?", "Confirm",
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($confirm -ne 'Yes') { return }
    Remove-Item (Join-Path $ProfilesDir "$n.json") -ErrorAction SilentlyContinue
    Refresh-ProfileList
})

$BtnAddDesk.Add_Click({
    if (-not $Script:CurrentProfile) { return }
    $card = New-DesktopCard ("Desktop {0}" -f ($DesktopsPanel.Children.Count + 1)) @()
    $DesktopsPanel.Children.Add($card) | Out-Null
})

$BtnSave.Add_Click({ Save-CurrentProfile | Out-Null })
$BtnOpenDir.Add_Click({ Start-Process explorer.exe $ProfilesDir })
$BtnToggleLog.Add_Click({
    if ($LogPanel.Visibility -eq 'Visible') { Hide-LogPanel } else { Show-LogPanel }
})
$BtnClearLog.Add_Click({ Clear-Log })

$BtnCook.Add_Click({
    if (-not (Test-Path $VD)) {
        [System.Windows.MessageBox]::Show(
            "VirtualDesktop.exe not found at:`n$VD`n`nDownload from:`nhttps://github.com/MScholtes/VirtualDesktop/releases",
            "Engine Missing", "OK", "Error") | Out-Null
        return
    }

    if (-not (Save-CurrentProfile)) { return }

    $prof = $Script:CurrentProfile
    $confirm = [System.Windows.MessageBox]::Show(
        "About to cook '$($prof.name)':`n`n* Keeps your existing virtual desktops untouched`n* Appends $($prof.desktops.Count) new named desktops`n* Launches all configured apps on the new desktops`n`nProceed?",
        "Let's Cook", "YesNo", "Question")
    if ($confirm -ne 'Yes') { return }

    Show-LogPanel
    Clear-Log
    Add-LogLine "============================================" "Green"
    Add-LogLine ("  J.A.R.V.I.S  |  LET'S COOK  ({0})" -f $prof.name) "Green"
    Add-LogLine "============================================" "Green"
    Add-LogLine ""

    $BtnCook.IsEnabled = $false; $BtnSave.IsEnabled = $false
    $BtnCook.Content = "COOKING..."
    Set-Status "Cooking in progress..." "success"

    $logger = {
        param($msg, $color)
        Add-LogLine $msg $color
        Set-Status $msg $(if ($color -eq "Red") { "error" } elseif ($color -eq "Green") { "success" } else { "dim" })
        $Window.Dispatcher.Invoke([Action]{}, "Background") | Out-Null
    }

    try {
        $ok = Invoke-CookProfile $prof $logger
        Add-LogLine ""
        if ($ok) {
            Add-LogLine "============================================" "Green"
            Add-LogLine ("  Cooked '{0}'. Enjoy." -f $prof.name) "Green"
            Add-LogLine "============================================" "Green"
            Set-Status ("Cooked '{0}'. Enjoy." -f $prof.name) "success"
        } else {
            Add-LogLine "  Cook failed. See log above." "Red"
            Set-Status "Cook failed. See log." "error"
        }
    } catch {
        Add-LogLine ("  Error: {0}" -f $_.Exception.Message) "Red"
        Set-Status ("Cook error: {0}" -f $_.Exception.Message) "error"
    } finally {
        $BtnCook.IsEnabled = $true; $BtnSave.IsEnabled = $true
        $BtnCook.Content = [char]0x25B6 + " LET'S COOK"
    }
})

Refresh-ProfileList "office"
$Window.ShowDialog() | Out-Null
