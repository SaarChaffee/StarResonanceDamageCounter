using System.Net.Http;
using System.Text.Json;
using BuffOverlay.Models;

namespace BuffOverlay.Services;

public class BuffApiService : IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    private bool _disposed;

    public bool IsConnected { get; private set; }

    public BuffApiService(int port = 8989)
    {
        _baseUrl = $"http://localhost:{port}";
        _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
    }

    public async Task<BuffApiResponse?> FetchBuffsAsync()
    {
        try
        {
            var response = await _httpClient.GetAsync($"{_baseUrl}/api/buffs");
            if (!response.IsSuccessStatusCode)
            {
                IsConnected = false;
                return null;
            }

            var json = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<BuffApiResponse>(json);
            IsConnected = result != null;
            return result;
        }
        catch
        {
            IsConnected = false;
            return null;
        }
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            _httpClient.Dispose();
            _disposed = true;
        }
    }
}
