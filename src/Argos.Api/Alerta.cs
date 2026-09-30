using Argos.Domain.Enums;

namespace Argos.Domain.Entities;

public class Alerta
{
    public int Id { get; private set; }
    public int ZonaRiscoId { get; private set; }
    public ZonaRisco ZonaRisco { get; private set; } = null!;
    public string Titulo { get; private set; } = null!;
    public string Descricao { get; private set; } = null!;
    public NivelRisco NivelAlerta { get; private set; }
    public bool Ativo { get; private set; } = true;
    public DateTime DataCriacao { get; private set; } = DateTime.UtcNow;

    private Alerta() { }
    public Alerta(int zonaRiscoId, string titulo, string descricao, NivelRisco nivel)
    {
        Atualizar(zonaRiscoId, titulo, descricao, nivel, true);
    }
    public void Atualizar(int zonaRiscoId, string titulo, string descricao, NivelRisco nivel, bool ativo)
    {
        if (zonaRiscoId <= 0) throw new ArgumentException("Zona inválida.");
        if (string.IsNullOrWhiteSpace(titulo) || titulo.Trim().Length > 160) throw new ArgumentException("Título obrigatório, até 160 caracteres.");
        if (string.IsNullOrWhiteSpace(descricao) || descricao.Trim().Length > 2000) throw new ArgumentException("Descrição obrigatória, até 2000 caracteres.");
        if (!Enum.IsDefined(nivel)) throw new ArgumentException("Nível inválido.");
        ZonaRiscoId = zonaRiscoId;
        Titulo = titulo.Trim(); Descricao = descricao.Trim(); NivelAlerta = nivel; Ativo = ativo;
    }
}
