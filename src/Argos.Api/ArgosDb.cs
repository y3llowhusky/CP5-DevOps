using Argos.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Argos.Api;

public class ArgosDb(DbContextOptions<ArgosDb> options) : DbContext(options)
{
    public DbSet<ZonaRisco> Zonas => Set<ZonaRisco>();
    public DbSet<Alerta> Alertas => Set<Alerta>();
    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<ZonaRisco>(z =>
        {
            z.ToTable("ZONAS_RISCO"); z.HasKey(x => x.Id);
            z.Property(x => x.Id).ValueGeneratedOnAdd();
            z.Property(x => x.Nome).HasMaxLength(120).IsRequired();
            z.Property(x => x.Cidade).HasMaxLength(120).IsRequired();
            z.Property(x => x.Estado).HasMaxLength(2).IsRequired();
            z.Property(x => x.Regiao).HasMaxLength(40);
            z.Property(x => x.Descricao).HasMaxLength(300);
            z.Property(x => x.Latitude).HasColumnType("float");
            z.Property(x => x.Longitude).HasColumnType("float");
            z.Property(x => x.NivelRiscoAtual).HasConversion<string>().HasMaxLength(10);
            z.Property(x => x.DataCriacao).HasColumnType("datetime2");
            z.Property(x => x.AtualizadoEm).HasColumnType("datetime2");
        });
        model.Entity<Alerta>(a =>
        {
            a.ToTable("ALERTAS"); a.HasKey(x => x.Id);
            a.Property(x => x.Id).ValueGeneratedOnAdd();
            a.Property(x => x.Titulo).HasMaxLength(160).IsRequired();
            a.Property(x => x.Descricao).HasMaxLength(2000).IsRequired();
            a.Property(x => x.NivelAlerta).HasConversion<string>().HasMaxLength(10);
            a.Property(x => x.DataCriacao).HasColumnType("datetime2");
            a.HasOne(x => x.ZonaRisco).WithMany().HasForeignKey(x => x.ZonaRiscoId).OnDelete(DeleteBehavior.Restrict);
            a.HasIndex(x => x.ZonaRiscoId);
        });
    }
}
