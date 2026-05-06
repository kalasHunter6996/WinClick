param(
    [switch]$ShowReboot
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$registryPath = "HKCU:\Console\%%Startup"
$keys = @{
    "DelegationConsole"  = "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}"
    "DelegationTerminal" = "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}"
}

if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

foreach ($name in $keys.Keys) {
    Set-ItemProperty -Path $registryPath -Name $name -Value $keys[$name] -Type String -Force
}
# ================= ПУТИ =================
$batPath = Join-Path $PSScriptRoot "WinClick.bat"
$workDir = Join-Path $PSScriptRoot "Work"

# ================= ФУНКЦИИ =================
function Show-RebootPrompt {
    $doneWin = [System.Windows.Window]::new()
    $doneWin.Width = 250; $doneWin.Height = 130; $doneWin.AllowsTransparency = $true; $doneWin.WindowStyle = "None"
    $doneWin.WindowStartupLocation = "CenterScreen"; $doneWin.Topmost = $true; $doneWin.Background = [System.Windows.Media.Brushes]::Transparent
    
    $doneBorder = [System.Windows.Controls.Border]::new()
    $doneBorder.Background = $darkGrayBrush; $doneBorder.CornerRadius = 12; $doneBorder.BorderBrush = $accentBrush; $doneBorder.BorderThickness = 1
    
    $doneStack = [System.Windows.Controls.StackPanel]::new()
    $doneStack.VerticalAlignment = "Center"
    $doneText = [System.Windows.Controls.TextBlock]::new()
    $doneText.Text = "Настройка завершена!`n`nПерезагрузить ПК?"; $doneText.Foreground = $whiteBrush
    $doneText.TextAlignment = "Center"; $doneText.Margin = "0,-5,0,10"; $doneText.FontFamily = "Bahnschrift"
    
    $btnP = [System.Windows.Controls.StackPanel]::new(); $btnP.Orientation = "Horizontal"; $btnP.HorizontalAlignment = "Center"
    $bR = [System.Windows.Controls.Button]::new(); $bR.Content = "ДА"; $bR.Style = $buttonStyle; $bR.Width = 70; $bR.Height = 28; $bR.FontFamily = "Bahnschrift"
    
    Set-FadeIn $doneWin
    
    $bR.Add_Click({ 
        Close-WindowAnimated $doneWin
        Start-Process "shutdown.exe" -ArgumentList "/r /t 1 /f" -WindowStyle Hidden
    })
    $bC = [System.Windows.Controls.Button]::new(); $bC.Content = "НЕТ"; $bC.Style = $buttonStyle; $bC.Width = 70; $bC.Height = 28; $bC.FontFamily = "Bahnschrift"
    $bC.Add_Click({ 
        Close-WindowAnimated $doneWin
        # Если запущено из GUI, основное окно закроется само по логике кнопки "Оптимизировать"
    })
    $bR.Margin = [System.Windows.Thickness]::new(0, 10, 5, 0) 
    $bC.Margin = [System.Windows.Thickness]::new(5, 10, 0, 0)
    $btnP.Children.Add($bR); $btnP.Children.Add($bC)
    $doneStack.Children.Add($doneText); $doneStack.Children.Add($btnP)
    $doneBorder.Child = $doneStack; $doneWin.Content = $doneBorder
    $doneWin.ShowDialog() | Out-Null
}

function Update-OptimizeButtonState {
    $anyChecked = $false
    foreach ($cb in $allCBs) {
        if ($cb.IsChecked) {
            $anyChecked = $true
            break
        }
    }
    $btnOpt.IsEnabled = $anyChecked
}

function Get-CustomImage {
    param([string]$fileName)
    $imgPath = Join-Path $workDir $fileName
    if (Test-Path $imgPath) {
        try {
            $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.UriSource = [Uri]$imgPath
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.EndInit()
            
            $img = [System.Windows.Controls.Image]::new()
            $img.Source = $bitmap
            $img.Width = 18
            $img.Height = 18
            return $img
        } catch { return $null }
    }
    return $null
}

function Create-IconButton {
    param($imgName, $url, $tip)
    $btn = [System.Windows.Controls.Border]::new()
    $btn.Width = 24; $btn.Height = 24
    $btn.Background = [System.Windows.Media.Brushes]::Transparent
    $btn.Cursor = [System.Windows.Input.Cursors]::Hand
    $btn.ToolTip = $tip
    
    $icon = Get-CustomImage $imgName
    if ($icon) {
        $icon.Width = 16; $icon.Height = 16
        $icon.Opacity = 0.7
        $btn.Child = $icon
    }
    
    $btn.Add_MouseDown({ Start-Process $url }.GetNewClosure())
    $btn.Add_MouseEnter({ if ($this.Child) { $this.Child.Opacity = 1.0 } })
    $btn.Add_MouseLeave({ if ($this.Child) { $this.Child.Opacity = 0.7 } })
    
    return $btn
}

function Set-FadeIn($win) {
    $win.Opacity = 0 
    $win.Add_Loaded({
        $fadeIn = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fadeIn.From = 0
        $fadeIn.To = 1
        $fadeIn.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(300))
        $fadeIn.EasingFunction = New-Object System.Windows.Media.Animation.QuadraticEase -Property @{ EasingMode = "EaseOut" }
        
        $this.BeginAnimation([System.Windows.Window]::OpacityProperty, $fadeIn)
    })
}

function Close-WindowAnimated($win) {
    if ($null -eq $win -or $win.Tag -eq "Closing") { return }
    $win.Tag = "Closing"
    
    $fadeOut = New-Object System.Windows.Media.Animation.DoubleAnimation
    $fadeOut.From = $win.Opacity
    $fadeOut.To = 0
    $fadeOut.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(200))
    $fadeOut.Add_Completed({ 
        $win.Close() 
    }.GetNewClosure())
    
    $win.BeginAnimation([System.Windows.Window]::OpacityProperty, $fadeOut)
}

# ================= ЦВЕТА И СТИЛИ =================
$darkGrayBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(20,22,25))
$cardBrush     = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30,34,40))
$accentBrush   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(94,129,172))
$whiteBrush    = [System.Windows.Media.Brushes]::White
$borderBrush   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(60,60,60))
$cardBorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Gray)
$cardBorderBrush.Opacity = 0.2

$buttonStyle = [System.Windows.Markup.XamlReader]::Parse(@"
<Style TargetType='Button' xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
  <Setter Property='Margin' Value='20,10,20,20'/><Setter Property='Height' Value='45'/><Setter Property='FontSize' Value='12'/><Setter Property='FontWeight' Value='Bold'/>
  <Setter Property='Background' Value='#5E81AC'/><Setter Property='Foreground' Value='White'/><Setter Property='BorderThickness' Value='0'/>
  <Setter Property='RenderTransformOrigin' Value='0.5,0.5'/>
  <Setter Property='Template'>
    <Setter.Value>
      <ControlTemplate TargetType='Button'>
        <Border Name='border' Background='{TemplateBinding Background}' CornerRadius='8' RenderTransformOrigin='0.5,0.5'>
          <Border.RenderTransform><ScaleTransform ScaleX='1' ScaleY='1'/></Border.RenderTransform>
          <ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>
        </Border>
        <ControlTemplate.Triggers>
		<Trigger Property='IsEnabled' Value='False'>
			<Setter TargetName='border' Property='Background' Value='#2A2E33'/>
			<Setter Property='Foreground' Value='#555555'/>
			</Trigger>
          <Trigger Property='IsMouseOver' Value='True'><Setter TargetName='border' Property='Background' Value='#4C566A'/></Trigger>
          <Trigger Property='IsPressed' Value='True'><Setter TargetName='border' Property='RenderTransform'><Setter.Value><ScaleTransform ScaleX='0.98' ScaleY='0.98'/></Setter.Value></Setter></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@)

$checkboxTemplate = [System.Windows.Markup.XamlReader]::Parse(@"
<ControlTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' TargetType='CheckBox'>
  <Border Name='Bg' Background='Transparent' CornerRadius='4' Padding='4'>
    <BulletDecorator Background='Transparent'>
      <BulletDecorator.Bullet>
        <Grid Width='18' Height='18'>
          <Border Name='Border' CornerRadius='4' Background='Transparent' BorderBrush='White' BorderThickness='1'/>
          <Path Name='CheckMark' Visibility='Hidden' Stroke='#5E81AC' StrokeThickness='2' Data='M3,9 L7,13 L15,5'/>
        </Grid>
      </BulletDecorator.Bullet>
      <ContentPresenter VerticalAlignment='Center' Margin='10,0,0,0'/>
    </BulletDecorator>
  </Border>
  <ControlTemplate.Triggers>
    <Trigger Property='IsChecked' Value='True'><Setter TargetName='CheckMark' Property='Visibility' Value='Visible'/><Setter TargetName='Border' Property='BorderBrush' Value='#5E81AC'/></Trigger>
    <Trigger Property='IsMouseOver' Value='True'><Setter TargetName='Bg' Property='Background' Value='#3D4450'/><Setter TargetName='Border' Property='BorderBrush' Value='#5E81AC'/></Trigger>
  </ControlTemplate.Triggers>
</ControlTemplate>
"@)

# ================= ВСЕ РАЗДЕЛЫ И ТВИКИ =================
$tweaks = [ordered]@{
    "Очистка" = @(
        @("Удалить файлы обновлений", "/RemoveUpdateFiles"),
        @("Удалить кэш Windows Store", "/RemoveStoreCache"),
        @("Удалить кэш Проводника", "/RemoveExplorerCache"),
        @("Очистить хранилище WinSxS", "/CleanWinSxS"),
        @("Удалить лишние папки на диске C:", "/RemoveJunkFolders"),
        @("Удалить старые драйвера", "/RemoveOldDrivers"),
        @("Удалить ShellBags", "/RemoveShellBags")
    )
    "Предустановленные приложения" = @(
        @("Удалить все UWP-приложения", "/RemoveAppx"),
        @("Удалить OneDrive", "/RemoveOneDrive"),
        @("Удалить Помощника по удаленному подключению", "/RemoveRemoteAssistant"),
        @("Удалить лишние папки приложений в Пуске", "/CleanStartMenu")
    )
    "Браузер Edge и WebView2" = @(
        @("Удалить Microsoft Edge", "/RemoveEdge"),
        @("Удалить Edge WebView2", "/RemoveEdgeWebView")
    )
    "Защитник Windows" = @(
        ,@("Удалить Защитнике Windows (DefenderKiller)", "/RemoveDefender")
    )
	"Компоненты Windows" = @(
        ,@("Удалить все дополнительные компоненты", "/RemoveComponents")
    )
    "Планировщик задач" = @(
        ,@("Отключить задачи телеметрии и проверок", "/DisableTasks")
    )
    "Оптимизация параметров" = @(
        @("Отключить Гибернацию", "/DisableHibernate"),
		@("Отключить Зарезервированное хранилище", "/DisableReservedStorage"),
        @("Отключить Точки восстановления", "/DisableRestorePoints"),
		@("Отложенный запуск автоматических служб", "/DelayedServices"),
		@("Минимизировать системные отчеты", "/SystemLog"),
		@("Увеличить кэш иконок", "/BoostIconCache"),
		@("Увеличить порог разделения SVC", "/SvcSplit"),
		@("Ускорить открытие папок", "/FastFolders"),
		@("Отключить VBS и HVCI", "/DisableVBS"),
        @("Отключить GameDVR", "/DisableGameDVR"),
		@("Установить схему питания Максимальная производительность", "/UltimatePerformance"),
		@("Отключить функцию Возоновить", "/DisableResume")
    )
    "Центр обновления Windows" = @(
        @("Запретить установку драйверов из ЦО", "/DisableWUDrivers"),
		@("Запретить обновления удаления вредоносных программ", "/DisableDefenderUpdates"),
		@("Установить паузу обновлений до 07.07.2077", "/PauseUpdates"),
		@("Запретить автоматические обновления", "/DisableAutoUpdates")
    )
    "Полезные твики" = @(
        @("Отключить UAC", "/DisableUAC"),
		@("Сделать учетную запись Административной", "/EnableAdmin"),
		@("Снять региональные ограничения", "/UnlockRegion"),
		@("Принудительно завершать программы при зависании", "/KillFreezeApps"),
		@("Отключить Удаленный помощник", "/DisableRemote"),
		@("Отключить залипание клавиш", "/DisableStickyKeys"),
		@("Скрыть реальный TTL", "/TTL"),
		@("Отключить лишние уведомления и рекомендации", "/DisableNotificationsAds"),
		@("Установить DNS Cloudflare на Wi-Fi адаптеры", "/DNS")
    )
    "Драйверы" = @(
        ,@("Установить драйверы (Папка Drivers на Рабочем столе)", "/InstallDrivers")
	)
	"Другие компоненты" = @(
        @("Установить Visual C++", "/InstallVC"),
        @("Установить DirectX 9-11", "/InstallDX")
    )
    "Визуальные твики" = @(
        @("Удалить пункт Главная в Проводнике", "/RemoveHome"),
        @("Удалить пункт Галерея в Проводнике", "/RemoveGallery"),
        @("Удалить пункт Сеть в Проводнике", "/RemoveNetwork"),
		@("Установить темную тему системы", "/DarkTheme"),
		@("Установить кастомные обои", "/SetWallpaper"),
		@("Установить синие папки", "/BlueIcons"),
		@("Установить дополнительные эскизы медиафайлов (Icaros)", "/Icaros"),
		@("Установить секунды в трее", "/TraySeconds"),
		@("Установить дату в трее", "/TrayDate"),
		@("Установить пункт Завершить задачу на Панели задач", "/TaskbarEndTask"),
		@("Удалить лишние значки на Панели задач", "/RemoveTaskbarIcons"),
		@("Скрыть раздел Рекомендуем в меню Пуск", "/HideRecommended"),
		@("Установить значок Настройки в меню Пуск", "/StartSettingsIcon"),
		@("Удалить сжатие обоев Рабочего стола", "/WallpaperQuality"),
		@("Удалить экран блокировки", "/RemoveLockScreen"),
		@("Удалить тени на значках Рабочего стола", "/NoIconShadow"),
		@("Открывать Проводник в Этот компьютер", "/ExplorerThisPC"),
		@("Показывать расширения файлов", "/ShowExtensions")
    )
    "Сжатие системы" = @(
        @("Максимальное сжатие системных файлов", "/CompressOS"),
		@("Максимальное сжатие системных и программных файлов", "/CompressDrive")
    )
}

# ================= КОНСТРУКТОР UI =================
$window = [System.Windows.Window]::new()
$window.Title = "WinClick 2.0"
$window.Width = 450
$window.Height = 650
$window.Background = [System.Windows.Media.Brushes]::Transparent
$window.AllowsTransparency = $true
$window.WindowStyle = "None"
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"

$mainBorder = [System.Windows.Controls.Border]::new()
$mainBorder.Background = $darkGrayBrush
$mainBorder.CornerRadius = [System.Windows.CornerRadius]::new(15)
$mainBorder.BorderBrush = $accentBrush
$mainBorder.BorderThickness = [System.Windows.Thickness]::new(1)

$root = [System.Windows.Controls.Grid]::new()
$root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
$root.RowDefinitions[0].Height = [System.Windows.GridLength]::Auto
$root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
$root.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new())
$root.RowDefinitions[2].Height = [System.Windows.GridLength]::Auto

$headerContainer = [System.Windows.Controls.StackPanel]::new()
$headerContainer.Margin = [System.Windows.Thickness]::new(0,15,0,10)
$headerContainer.Background = [System.Windows.Media.Brushes]::Transparent
$headerContainer.Add_MouseLeftButtonDown({ $window.DragMove() })
[System.Windows.Controls.Grid]::SetRow($headerContainer, 0)
$root.Children.Add($headerContainer) | Out-Null

$navCard = [System.Windows.Controls.Border]::new()
$navCard.Background = $cardBrush
$navCard.BorderBrush = $cardBorderBrush
$navCard.BorderThickness = [System.Windows.Thickness]::new(1)
$navCard.CornerRadius = [System.Windows.CornerRadius]::new(8)
$navCard.HorizontalAlignment = "Right"
$navCard.VerticalAlignment = "Top"
$navCard.Margin = [System.Windows.Thickness]::new(0,20,20,0)
$navCard.Padding = [System.Windows.Thickness]::new(3,0,4,0)

$navStack = [System.Windows.Controls.StackPanel]::new()
$navStack.Orientation = "Horizontal"
$navCard.Child = $navStack

$navStack.Children.Add((Create-IconButton "Telegram.ico" "https://t.me/martyfiles" "Telegram")) | Out-Null
$navStack.Children.Add((Create-IconButton "YouTube.ico" "https://youtube.com/martyfiles" "YouTube")) | Out-Null
$navStack.Children.Add((Create-IconButton "GitHub.ico" "https://github.com/martyfiles" "GitHub")) | Out-Null

$sep = [System.Windows.Controls.Border]::new()
$sep.Width = 1; $sep.Height = 14; $sep.Background = [System.Windows.Media.Brushes]::Gray
$sep.Opacity = 0.3; $sep.Margin = [System.Windows.Thickness]::new(4,0,4,0)
$sep.VerticalAlignment = "Center"
$navStack.Children.Add($sep) | Out-Null

$closeWrapper = [System.Windows.Controls.Border]::new()
$closeWrapper.Width = 24; $closeWrapper.Height = 24
$closeWrapper.Background = [System.Windows.Media.Brushes]::Transparent
$closeWrapper.Cursor = [System.Windows.Input.Cursors]::Hand

$closeTxt = [System.Windows.Controls.TextBlock]::new()
$closeTxt.Text = "r"; $closeTxt.FontFamily = "Marlett"; $closeTxt.FontSize = 16; $closeTxt.Margin = "0,2,0,0"
$closeTxt.Foreground = [System.Windows.Media.Brushes]::Gray
$closeTxt.HorizontalAlignment = "Center"; $closeTxt.VerticalAlignment = "Center"
$closeWrapper.Child = $closeTxt
$closeWrapper.Add_MouseEnter({ $closeTxt.Foreground = [System.Windows.Media.Brushes]::IndianRed })
$closeWrapper.Add_MouseLeave({ $closeTxt.Foreground = [System.Windows.Media.Brushes]::Gray })
$closeWrapper.Add_MouseDown({ Close-WindowAnimated $window })

$navStack.Children.Add($closeWrapper) | Out-Null
[System.Windows.Controls.Grid]::SetRow($navCard, 0)
$root.Children.Add($navCard) | Out-Null

$headerTxt = [System.Windows.Controls.Label]::new()
$headerTxt.Content = "WinClick 2.0"; $headerTxt.FontSize = 26; $headerTxt.FontWeight = [System.Windows.FontWeights]::Bold
$headerTxt.Foreground = $accentBrush; $headerTxt.Margin = [System.Windows.Thickness]::new(25,0,0,0); $headerTxt.FontFamily = "Bahnschrift"
$headerTxt.Add_MouseDoubleClick({
    $items = $this.Tag
    if ($null -ne $items) {
        $allUnchecked = ($items | Where-Object { -not $_.IsChecked }).Count -eq $items.Count
        foreach ($item in $items) {
            $item.IsChecked = $allUnchecked
        }
    }
})

$headerContainer.Children.Add($headerTxt) | Out-Null
$scroll = [System.Windows.Controls.ScrollViewer]::new()
$scroll.VerticalScrollBarVisibility = "Hidden"; $scroll.Margin = [System.Windows.Thickness]::new(20,-10,20,-15); $scroll.BorderThickness = [System.Windows.Thickness]::new(0)

$mask = [System.Windows.Media.LinearGradientBrush]::new()
$mask.StartPoint = "0,0"; $mask.EndPoint = "0,1"

$stopTop = [System.Windows.Media.GradientStop]::new([System.Windows.Media.Colors]::Black, 0.0)
$stopTopFade = [System.Windows.Media.GradientStop]::new([System.Windows.Media.Colors]::Black, 0.05)
$stopBottomFade = [System.Windows.Media.GradientStop]::new([System.Windows.Media.Colors]::Black, 0.90)
$stopBottom = [System.Windows.Media.GradientStop]::new([System.Windows.Media.Colors]::Black, 1.0)

$mask.GradientStops.Add($stopTop)
$mask.GradientStops.Add($stopTopFade)
$mask.GradientStops.Add($stopBottomFade)
$mask.GradientStops.Add($stopBottom)
$scroll.OpacityMask = $mask
$scroll.Add_ScrollChanged({
    if ($scroll.VerticalOffset -gt 0) { $stopTop.Color = [System.Windows.Media.Colors]::Transparent }
    else { $stopTop.Color = [System.Windows.Media.Colors]::Black }
    
    if ($scroll.VerticalOffset -lt $scroll.ScrollableHeight) { $stopBottom.Color = [System.Windows.Media.Colors]::Transparent }
    else { $stopBottom.Color = [System.Windows.Media.Colors]::Black }
})

$script:scrollTimer = $null
$script:scrollVelocity = 0

$scroll.Add_PreviewMouseWheel({
    param($s, $e)
    $e.Handled = $true
    $script:scrollVelocity += -$e.Delta / 120 * 15
    if (-not $script:scrollTimer) {
        $script:scrollTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:scrollTimer.Interval = [TimeSpan]::FromMilliseconds(1)
        $script:scrollTimer.Add_Tick({
            if ([math]::Abs($script:scrollVelocity) -lt 0.1) {
                $script:scrollTimer.Stop()
                return
            }
            $newOffset = $scroll.VerticalOffset + $script:scrollVelocity
            if ($newOffset -lt 0) { 
                $newOffset = 0
                $script:scrollVelocity = 0
            }
            if ($newOffset -gt $scroll.ScrollableHeight) {
                $newOffset = $scroll.ScrollableHeight
                $script:scrollVelocity = 0
            }
            $scroll.ScrollToVerticalOffset($newOffset)
            $script:scrollVelocity *= 0.8
        })
    }
    $script:scrollTimer.Start()
})

$stack = [System.Windows.Controls.StackPanel]::new()
$scroll.Content = [System.Windows.Controls.Border]::new()
$scroll.Content.Padding = [System.Windows.Thickness]::new(0,20,0,10)
$scroll.Content.Child = $stack
[System.Windows.Controls.Grid]::SetRow($scroll, 1)
$root.Children.Add($scroll) | Out-Null

$allCBs = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()

foreach ($sec in $tweaks.Keys) {
    $card = [System.Windows.Controls.Border]::new()
    $card.Background = $cardBrush; $card.CornerRadius = [System.Windows.CornerRadius]::new(10)
    $card.Margin = [System.Windows.Thickness]::new(0,0,0,20); $card.Padding = [System.Windows.Thickness]::new(15)
	
	$card.BorderThickness = [System.Windows.Thickness]::new(1)
    $card.BorderBrush = $cardBorderBrush
    
    $cardStack = [System.Windows.Controls.StackPanel]::new()
    $sectionCBs = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()

	$secHeader = [System.Windows.Controls.Label]::new()
    $secHeader.Content = $sec.ToUpper(); $secHeader.FontSize = 12; $secHeader.FontWeight = [System.Windows.FontWeights]::Bold 
    $secHeader.Foreground = [System.Windows.Media.Brushes]::LightGray; $secHeader.Margin = [System.Windows.Thickness]::new(-5,-5,0,12)
    $secHeader.Cursor = [System.Windows.Input.Cursors]::Hand; $secHeader.Tag = $sectionCBs; $secHeader.FontFamily = "Bahnschrift"
    
    $secHeader.Add_MouseEnter({ $this.Foreground = $accentBrush })
    $secHeader.Add_MouseLeave({ $this.Foreground = [System.Windows.Media.Brushes]::LightGray })
	$secHeader.Add_MouseDown({
    $items = $this.Tag
    $allUnchecked = ($items | Where-Object { -not $_.IsChecked }).Count -eq $items.Count
    foreach ($item in $items) {
        $item.IsChecked = $allUnchecked
    }
    Update-OptimizeButtonState
	})
    
    $cardStack.Children.Add($secHeader) | Out-Null

    $currentList = $tweaks[$sec]
    if ($currentList.Count -eq 2 -and $currentList[0] -is [string]) { $currentList = ,$currentList }

	foreach ($tweak in $currentList) {
        $cb = [System.Windows.Controls.CheckBox]::new()
        $cb.Content = $tweak[0]; $cb.Tag = $tweak[1]; $cb.Template = $checkboxTemplate
        $cb.Foreground = [System.Windows.Media.Brushes]::Gray; $cb.Margin = [System.Windows.Thickness]::new(0,0,5,5)
        $cb.FontSize = 11; $cb.Cursor = [System.Windows.Input.Cursors]::Hand; $cb.FontFamily = "Bahnschrift"

		$cb.Add_Checked({ 
			$this.Foreground = [System.Windows.Media.Brushes]::White 
			Update-OptimizeButtonState
		})
		$cb.Add_Unchecked({ 
			$this.Foreground = [System.Windows.Media.Brushes]::Gray 
			Update-OptimizeButtonState
		})

        $cardStack.Children.Add($cb) | Out-Null
        $allCBs.Add($cb)
        $sectionCBs.Add($cb)
    }
    $card.Child = $cardStack
    $stack.Children.Add($card) | Out-Null
}

$headerTxt.Tag = $allCBs

# ================= ЛОГИКА СЖАТИЯ =================
$cbCompressOS = $allCBs | Where-Object { $_.Tag -eq "/CompressOS" }
$cbCompressDrive = $allCBs | Where-Object { $_.Tag -eq "/CompressDrive" }

function Set-CompressCheckbox {
    param($target, $value)
    $target.Remove_Checked($null)
    $target.IsChecked = $value
}

$isUpdating = $false

$cbCompressOS.Add_Checked({
    if ($isUpdating) { return }
    $global:isUpdating = $true
    $cbCompressDrive.IsChecked = $false
    $global:isUpdating = $false
})

$cbCompressDrive.Add_Checked({
    if ($isUpdating) { return }
    $global:isUpdating = $true
    $cbCompressOS.IsChecked = $false
    $global:isUpdating = $false
})

$btnOpt = [System.Windows.Controls.Button]::new()
$btnOpt.Content = "ОПТИМИЗИРОВАТЬ"
$btnOpt.Style = $buttonStyle
$btnOpt.Cursor = [System.Windows.Input.Cursors]::Hand
$btnOpt.FontFamily = "Bahnschrift"
$btnOpt.FontSize = 18
$btnOpt.IsEnabled = $false
[System.Windows.Controls.Grid]::SetRow($btnOpt, 2)
$root.Children.Add($btnOpt) | Out-Null

$btnOpt.Add_Click({
    $selected = $allCBs | Where-Object { $_.IsChecked }
    if ($selected.Count -eq 0) { return }

    $argsString = ($selected | ForEach-Object { $_.Tag }) -join " "
	$window.Hide()
	$proc = Start-Process cmd.exe -ArgumentList "/c call `"$batPath`" $argsString" -PassThru
})

$mainBorder.Child = $root
$window.Content = $mainBorder
Set-FadeIn $window

if ($ShowReboot) {
    Show-RebootPrompt
} else {
    Set-FadeIn $window
    $window.ShowDialog() | Out-Null
}