using Argos.Domain.Enums;

namespace Argos.Domain.Entities;

/// <summary>
/// Locais oficiais monitorados; agrupa alertas (e opcionalmente ocorrências).
/// <see cref="Nome"/> vira "localizacao" e <see cref="Regiao"/> vira "zona" no app.
/// </summary>
public class ZonaRisco
{
    public int Id { get; private set; }
    public string Nome { get; private set; } = null!;
    public string? Regiao { get; private set; }
    public string Cidade { get; private set; } = null!;
    public string Estado { get; private set; } = null!;
    public double Latitude { get; private set; }
    public double Longitude { get; private set; }
    public string? Descricao { get; private set; }
    public NivelRisco NivelRiscoAtual { get; private set; }
    public bool Ativa { get; private set; }
    public DateTime DataCriacao { get; private set; }
    public DateTime? AtualizadoEm { get; private set; }

    public ZonaRisco(string nome, string cidade, string estado,
        double latitude, double longitude, string? regiao = null,
        string? descricao = null, NivelRisco nivelRiscoAtual = NivelRisco.BAIXO)
    {
        UpdateNome(nome);
        UpdateCidade(cidade);
        UpdateEstado(estado);
        UpdateCoordenadas(latitude, longitude);
        UpdateRegiao(regiao);
        UpdateDescricao(descricao);
        NivelRiscoAtual = nivelRiscoAtual;
        Ativa = true;
        DataCriacao = DateTime.UtcNow;
    }

    public void UpdateNome(string nome)
    {
        if (string.IsNullOrWhiteSpace(nome))
            throw new ArgumentException("Nome é obrigatório");
        if (nome.Trim().Length > 120)
            throw new ArgumentException("Nome deve ter no máximo 120 caracteres");
        Nome = nome.Trim();
        TocarAtualizacao();
    }

    public void UpdateRegiao(string? regiao)
    {
        if (string.IsNullOrWhiteSpace(regiao))
        {
            Regiao = null;
        }
        else
        {
            if (regiao.Trim().Length > 40)
                throw new ArgumentException("Região deve ter no máximo 40 caracteres");
            Regiao = regiao.Trim();
        }
        TocarAtualizacao();
    }

    public void UpdateCidade(string cidade)
    {
        if (string.IsNullOrWhiteSpace(cidade))
            throw new ArgumentException("Cidade é obrigatória");
        if (cidade.Trim().Length > 120)
            throw new ArgumentException("Cidade deve ter no máximo 120 caracteres");
        Cidade = cidade.Trim();
        TocarAtualizacao();
    }

    public void UpdateEstado(string estado)
    {
        if (string.IsNullOrWhiteSpace(estado))
            throw new ArgumentException("Estado (UF) é obrigatório");
        if (estado.Trim().Length != 2)
            throw new ArgumentException("Estado deve ser a UF com 2 caracteres");
        Estado = estado.Trim().ToUpperInvariant();
        TocarAtualizacao();
    }

    public void UpdateCoordenadas(double latitude, double longitude)
    {
        if (latitude is < -90 or > 90)
            throw new ArgumentException("Latitude deve estar entre -90 e 90");
        if (longitude is < -180 or > 180)
            throw new ArgumentException("Longitude deve estar entre -180 e 180");
        Latitude = latitude;
        Longitude = longitude;
        TocarAtualizacao();
    }

    public void UpdateDescricao(string? descricao)
    {
        if (string.IsNullOrWhiteSpace(descricao))
        {
            Descricao = null;
        }
        else
        {
            if (descricao.Trim().Length > 300)
                throw new ArgumentException("Descrição deve ter no máximo 300 caracteres");
            Descricao = descricao.Trim();
        }
        TocarAtualizacao();
    }

    public void AlterarNivelRisco(NivelRisco nivel)
    {
        NivelRiscoAtual = nivel;
        TocarAtualizacao();
    }

    public void Ativar()
    {
        Ativa = true;
        TocarAtualizacao();
    }

    public void Desativar()
    {
        Ativa = false;
        TocarAtualizacao();
    }

    // Só marca atualização depois que a entidade já foi criada
    // (durante o construtor DataCriacao ainda é default, então AtualizadoEm fica null).
    private void TocarAtualizacao()
    {
        if (DataCriacao != default)
            AtualizadoEm = DateTime.UtcNow;
    }

    protected ZonaRisco() { } // EF
}
