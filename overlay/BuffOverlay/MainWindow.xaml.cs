using System.ComponentModel;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using BuffOverlay.Models;
using BuffOverlay.Services;

namespace BuffOverlay;

public partial class MainWindow : Window
{
    private readonly BuffApiService _apiService;
    private readonly DispatcherTimer _pollTimer;
    private readonly DispatcherTimer _uiTimer;

    private double _lastServerTime;
    private DateTime _lastLocalTime = DateTime.Now;
    private List<BuffEntry> _currentBuffs = [];
    private readonly string _settingsPath;

    public MainWindow()
    {
        InitializeComponent();

        var args = Environment.GetCommandLineArgs();
        int port = 8989;
        for (int i = 1; i < args.Length; i++)
        {
            if (int.TryParse(args[i], out int p))
            {
                port = p;
                break;
            }
        }

        _apiService = new BuffApiService(port);

        _settingsPath = Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory, "overlay_settings.json");
        LoadWindowPosition();

        // Poll API every 250ms
        _pollTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        _pollTimer.Tick += async (_, _) => await PollBuffsAsync();
        _pollTimer.Start();

        // Refresh UI countdown every 100ms
        _uiTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(100) };
        _uiTimer.Tick += (_, _) => RefreshUI();
        _uiTimer.Start();
    }

    private async Task PollBuffsAsync()
    {
        var data = await _apiService.FetchBuffsAsync();
        if (data != null)
        {
            _lastServerTime = data.ServerTime;
            _lastLocalTime = DateTime.Now;
            _currentBuffs = data.Buffs;
            StatusDot.Fill = new SolidColorBrush(Color.FromRgb(0, 200, 0));
        }
        else
        {
            StatusDot.Fill = new SolidColorBrush(Color.FromRgb(200, 0, 0));
        }
    }

    private void RefreshUI()
    {
        var elapsedMs = (DateTime.Now - _lastLocalTime).TotalMilliseconds;
        var estimatedServerTime = _lastServerTime + elapsedMs;

        var displayItems = new List<BuffDisplayItem>();
        foreach (var buff in _currentBuffs)
        {
            double remaining;
            string timeText;
            if (buff.EndTime <= 0)
            {
                // Permanent buff
                remaining = double.MaxValue;
                timeText = "\u221E"; // ∞
            }
            else
            {
                remaining = buff.EndTime - estimatedServerTime;
                if (remaining <= 0) continue; // Expired
                timeText = $"{remaining / 1000.0:F1}s";
            }

            var item = new BuffDisplayItem
            {
                DisplayId = buff.BaseId > 0 ? buff.BaseId.ToString() : buff.BuffUuid.ToString(),
                TimeText = timeText,
                TimeColor = GetTimeColor(remaining),
                Layer = buff.Layer,
                LayerText = buff.Layer > 1 ? $"\u00D7{buff.Layer}" : "",
                LayerVisibility = buff.Layer > 1 ? Visibility.Visible : Visibility.Collapsed,
            };
            displayItems.Add(item);
        }

        BuffList.ItemsSource = displayItems;

        if (displayItems.Count == 0)
        {
            EmptyText.Visibility = Visibility.Visible;
            BuffList.Visibility = Visibility.Collapsed;
        }
        else
        {
            EmptyText.Visibility = Visibility.Collapsed;
            BuffList.Visibility = Visibility.Visible;
        }

        // Auto-resize height
        var rows = Math.Max(1, (int)Math.Ceiling(displayItems.Count / 8.0));
        Height = 20 + rows * 26;
    }

    private static Brush GetTimeColor(double remainingMs)
    {
        if (remainingMs == double.MaxValue)
            return Brushes.White;
        if (remainingMs <= 2000)
            return new SolidColorBrush(Color.FromRgb(255, 80, 80));
        if (remainingMs <= 5000)
            return new SolidColorBrush(Color.FromRgb(255, 220, 50));
        return Brushes.White;
    }

    // Drag to move
    private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 1)
            DragMove();
    }

    // Double-click to close
    private void Window_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        Close();
    }

    // Right-click context menu for opacity
    private void Window_MouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        var menu = new System.Windows.Controls.ContextMenu();

        var opacities = new[] { ("100%", 1.0), ("75%", 0.75), ("50%", 0.5), ("25%", 0.25) };
        foreach (var (label, val) in opacities)
        {
            var item = new System.Windows.Controls.MenuItem { Header = $"Opacity: {label}" };
            var v = val;
            item.Click += (_, _) => Opacity = v;
            menu.Items.Add(item);
        }

        menu.Items.Add(new System.Windows.Controls.Separator());

        var closeItem = new System.Windows.Controls.MenuItem { Header = "Close" };
        closeItem.Click += (_, _) => Close();
        menu.Items.Add(closeItem);

        menu.IsOpen = true;
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        SaveWindowPosition();
        _pollTimer.Stop();
        _uiTimer.Stop();
        _apiService.Dispose();
        base.OnClosing(e);
    }

    private void SaveWindowPosition()
    {
        try
        {
            var settings = new { Left, Top, Opacity };
            File.WriteAllText(_settingsPath, JsonSerializer.Serialize(settings));
        }
        catch { /* ignore */ }
    }

    private void LoadWindowPosition()
    {
        try
        {
            if (!File.Exists(_settingsPath)) return;
            var json = File.ReadAllText(_settingsPath);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.TryGetProperty("Left", out var l)) Left = l.GetDouble();
            if (root.TryGetProperty("Top", out var t)) Top = t.GetDouble();
            if (root.TryGetProperty("Opacity", out var o)) Opacity = o.GetDouble();
        }
        catch { /* ignore */ }
    }
}

public class BuffDisplayItem
{
    public string DisplayId { get; set; } = "";
    public string TimeText { get; set; } = "";
    public Brush TimeColor { get; set; } = Brushes.White;
    public int Layer { get; set; }
    public string LayerText { get; set; } = "";
    public Visibility LayerVisibility { get; set; } = Visibility.Collapsed;
}
