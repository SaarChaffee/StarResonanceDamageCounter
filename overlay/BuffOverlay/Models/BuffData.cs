using System.Text.Json.Serialization;

namespace BuffOverlay.Models;

public class BuffApiResponse
{
    [JsonPropertyName("code")]
    public int Code { get; set; }

    [JsonPropertyName("serverTime")]
    public double ServerTime { get; set; }

    [JsonPropertyName("buffs")]
    public List<BuffEntry> Buffs { get; set; } = [];
}

public class BuffEntry
{
    [JsonPropertyName("uid")]
    public long Uid { get; set; }

    [JsonPropertyName("playerName")]
    public string PlayerName { get; set; } = "";

    [JsonPropertyName("profession")]
    public string Profession { get; set; } = "";

    [JsonPropertyName("buffUuid")]
    public int BuffUuid { get; set; }

    [JsonPropertyName("baseId")]
    public int BaseId { get; set; }

    [JsonPropertyName("level")]
    public int Level { get; set; }

    [JsonPropertyName("layer")]
    public int Layer { get; set; }

    [JsonPropertyName("duration")]
    public int Duration { get; set; }

    [JsonPropertyName("createTime")]
    public double CreateTime { get; set; }

    [JsonPropertyName("endTime")]
    public double EndTime { get; set; }

    [JsonPropertyName("fireUuid")]
    public long FireUuid { get; set; }
}
