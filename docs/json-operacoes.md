# Contrato JSON para demonstrar o CRUD

Substitua `{idZona}` e `{idAlerta}` pelos IDs retornados no POST. As respostas de DELETE são HTTP 204, sem corpo JSON. GET/POST/PUT enviam e recebem JSON. Execute as operações de alerta antes do DELETE da zona (FK restritiva).

| Operação | URL | JSON enviado | Resposta esperada |
|---|---|---|---|
| GET zona | `/zonas-risco/{idZona}` | nenhum | `{"id":1,"nome":"Margem do rio","cidade":"São Paulo","estado":"SP","latitude":-23.55,"longitude":-46.63,"regiao":"Centro","descricao":"Área alagável","nivelRiscoAtual":"ALTO","ativa":true}` |
| POST zona | `/zonas-risco` | `{"nome":"Margem do rio","cidade":"São Paulo","estado":"SP","latitude":-23.55,"longitude":-46.63,"regiao":"Centro","descricao":"Área alagável","nivelRiscoAtual":"ALTO","ativa":true}` | 201, JSON da zona com `id` |
| PUT zona | `/zonas-risco/{idZona}` | `{"nome":"Margem do rio","cidade":"São Paulo","estado":"SP","latitude":-23.55,"longitude":-46.63,"regiao":"Centro","descricao":"Nível revisado","nivelRiscoAtual":"MEDIO","ativa":true}` | 200, JSON atualizado |
| DELETE zona | `/zonas-risco/{idZona}` | nenhum | 204, sem JSON |
| GET alerta | `/alertas/{idAlerta}` | nenhum | `{"id":1,"zonaRiscoId":1,"zona":"Margem do rio","titulo":"Alerta de chuva","descricao":"Evite a região","nivelAlerta":"ALTO","ativo":true}` |
| POST alerta | `/alertas` | `{"zonaRiscoId":1,"titulo":"Alerta de chuva","descricao":"Evite a região","nivelAlerta":"ALTO","ativo":true}` | 201, JSON do alerta com `id` |
| PUT alerta | `/alertas/{idAlerta}` | `{"zonaRiscoId":1,"titulo":"Chuva em queda","descricao":"Atenção mantida","nivelAlerta":"MEDIO","ativo":true}` | 200, JSON atualizado |
| DELETE alerta | `/alertas/{idAlerta}` | nenhum | 204, sem JSON |

A lista GET sem ID em cada rota retorna um array. Os enums aceitos são `BAIXO`, `MEDIO`, `ALTO` e `CRITICO`. Para conferir cada operação no banco, rode `SELECT * FROM dbo.ZONAS_RISCO ORDER BY Id;` e `SELECT * FROM dbo.ALERTAS ORDER BY Id;` após cada passo.
