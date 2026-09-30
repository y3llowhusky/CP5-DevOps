using System.Text.Json.Serialization;
using Argos.Api;
using Argos.Domain.Entities;
using Argos.Domain.Enums;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var connection = builder.Configuration.GetConnectionString("ArgosSql")
    ?? throw new InvalidOperationException("Configure ConnectionStrings__ArgosSql.");
builder.Services.AddDbContext<ArgosDb>(o => o.UseSqlServer(connection));
if (!string.IsNullOrWhiteSpace(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
    builder.Services.AddOpenTelemetry().UseAzureMonitor();
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
var app = builder.Build();
app.UseHttpsRedirection();
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/zonas-risco", async (ArgosDb db) => await db.Zonas.AsNoTracking().OrderBy(z => z.Id)
    .Select(z => new ZonaDto(z.Id, z.Nome, z.Cidade, z.Estado, z.Latitude, z.Longitude, z.Regiao, z.Descricao, z.NivelRiscoAtual, z.Ativa)).ToListAsync());
app.MapGet("/zonas-risco/{id:int}", async (int id, ArgosDb db) =>
{
    var z = await db.Zonas.FindAsync(id);
    return z is null ? Results.NotFound() : Results.Ok(ToZonaDto(z));
});
app.MapPost("/zonas-risco", async (ZonaInput input, ArgosDb db) =>
{
    try
    {
        var z = new ZonaRisco(input.Nome, input.Cidade, input.Estado, input.Latitude, input.Longitude, input.Regiao, input.Descricao, input.NivelRiscoAtual);
        db.Zonas.Add(z); await db.SaveChangesAsync();
        return Results.Created($"/zonas-risco/{z.Id}", ToZonaDto(z));
    }
    catch (ArgumentException e) { return Results.BadRequest(new { erro = e.Message }); }
});
app.MapPut("/zonas-risco/{id:int}", async (int id, ZonaInput input, ArgosDb db) =>
{
    var z = await db.Zonas.FindAsync(id);
    if (z is null) return Results.NotFound();
    try
    {
        z.UpdateNome(input.Nome); z.UpdateCidade(input.Cidade); z.UpdateEstado(input.Estado);
        z.UpdateCoordenadas(input.Latitude, input.Longitude); z.UpdateRegiao(input.Regiao);
        z.UpdateDescricao(input.Descricao); z.AlterarNivelRisco(input.NivelRiscoAtual);
        if (input.Ativa) z.Ativar(); else z.Desativar();
        await db.SaveChangesAsync(); return Results.Ok(ToZonaDto(z));
    }
    catch (ArgumentException e) { return Results.BadRequest(new { erro = e.Message }); }
});
app.MapDelete("/zonas-risco/{id:int}", async (int id, ArgosDb db) =>
{
    var z = await db.Zonas.FindAsync(id);
    if (z is null) return Results.NotFound();
    if (await db.Alertas.AnyAsync(a => a.ZonaRiscoId == id))
        return Results.Conflict(new { erro = "Exclua os alertas da zona antes de excluí-la." });
    db.Zonas.Remove(z); await db.SaveChangesAsync(); return Results.NoContent();
});
app.MapGet("/alertas", async (ArgosDb db) => await db.Alertas.AsNoTracking().OrderBy(a => a.Id)
    .Select(a => new AlertaDto(a.Id, a.ZonaRiscoId, a.ZonaRisco.Nome, a.Titulo, a.Descricao, a.NivelAlerta, a.Ativo)).ToListAsync());
app.MapGet("/alertas/{id:int}", async (int id, ArgosDb db) =>
{
    var a = await db.Alertas.AsNoTracking().Include(a => a.ZonaRisco).FirstOrDefaultAsync(a => a.Id == id);
    return a is null ? Results.NotFound() : Results.Ok(ToAlertaDto(a));
});
app.MapPost("/alertas", async (AlertaInput input, ArgosDb db) =>
{
    if (!await db.Zonas.AnyAsync(z => z.Id == input.ZonaRiscoId)) return Results.BadRequest(new { erro = "Zona inexistente." });
    try
    {
        var a = new Alerta(input.ZonaRiscoId, input.Titulo, input.Descricao, input.NivelAlerta);
        db.Alertas.Add(a); await db.SaveChangesAsync();
        a = (await db.Alertas.Include(x => x.ZonaRisco).FirstAsync(x => x.Id == a.Id));
        return Results.Created($"/alertas/{a.Id}", ToAlertaDto(a));
    }
    catch (ArgumentException e) { return Results.BadRequest(new { erro = e.Message }); }
});
app.MapPut("/alertas/{id:int}", async (int id, AlertaInput input, ArgosDb db) =>
{
    var a = await db.Alertas.Include(x => x.ZonaRisco).FirstOrDefaultAsync(x => x.Id == id);
    if (a is null) return Results.NotFound();
    if (!await db.Zonas.AnyAsync(z => z.Id == input.ZonaRiscoId)) return Results.BadRequest(new { erro = "Zona inexistente." });
    try
    {
        a.Atualizar(input.ZonaRiscoId, input.Titulo, input.Descricao, input.NivelAlerta, input.Ativo);
        await db.SaveChangesAsync();
        var updated = await db.Alertas.AsNoTracking().Include(x => x.ZonaRisco).FirstAsync(x => x.Id == id);
        return Results.Ok(ToAlertaDto(updated));
    }
    catch (ArgumentException e) { return Results.BadRequest(new { erro = e.Message }); }
});
app.MapDelete("/alertas/{id:int}", async (int id, ArgosDb db) =>
{
    var a = await db.Alertas.FindAsync(id);
    if (a is null) return Results.NotFound();
    db.Alertas.Remove(a); await db.SaveChangesAsync(); return Results.NoContent();
});
app.Run();

static ZonaDto ToZonaDto(ZonaRisco z) => new(z.Id, z.Nome, z.Cidade, z.Estado, z.Latitude, z.Longitude, z.Regiao, z.Descricao, z.NivelRiscoAtual, z.Ativa);
static AlertaDto ToAlertaDto(Alerta a) => new(a.Id, a.ZonaRiscoId, a.ZonaRisco.Nome, a.Titulo, a.Descricao, a.NivelAlerta, a.Ativo);
record ZonaInput(string Nome, string Cidade, string Estado, double Latitude, double Longitude, string? Regiao, string? Descricao, NivelRisco NivelRiscoAtual, bool Ativa = true);
record AlertaInput(int ZonaRiscoId, string Titulo, string Descricao, NivelRisco NivelAlerta, bool Ativo = true);
record ZonaDto(int Id, string Nome, string Cidade, string Estado, double Latitude, double Longitude, string? Regiao, string? Descricao, NivelRisco NivelRiscoAtual, bool Ativa);
record AlertaDto(int Id, int ZonaRiscoId, string Zona, string Titulo, string Descricao, NivelRisco NivelAlerta, bool Ativo);
