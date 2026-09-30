namespace Argos.Domain.Enums;

/// <summary>
/// Nível de risco associado a zonas, alertas e ocorrências.
/// Persistido como string (UPPER_SNAKE) e exposto assim no contrato REST.
/// </summary>
public enum NivelRisco
{
    BAIXO,
    MEDIO,
    ALTO,
    CRITICO
}
