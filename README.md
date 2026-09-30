# Argos CP5 — Aplicativos e Banco em Nuvem

Adaptação web do **Argos**, plataforma de acompanhamento de zonas de risco e alertas. Esta entrega usa uma página web integrada à API .NET 10, Azure App Service Linux, Azure SQL Database e Application Insights. É um projeto distinto do Fidelis (Sprint 3). A interface permite cadastrar, consultar, atualizar e excluir **ZONAS_RISCO** e **ALERTAS**, com relacionamento 1:N. O código de `ZonaRisco` e do enum `NivelRisco` foi adaptado de [ArgosApi-NET](https://github.com/Driven-Soft/ArgosApi-NET); os scripts seguem a estrutura, sem nomes ou infraestrutura, de [Fidelis-DevOps](https://github.com/Driven-Soft/Fidelis-DevOps). O [ArgosMobile](https://github.com/Driven-Soft/ArgosMobile) serviu como referência de tema, mas esta entrega não depende do Expo.

> **Estado:** código e roteiro preparados; execução na Azure, compilação, coleta de evidências e vídeo ainda precisam ser feitos por alguém com acesso à assinatura. O deploy exige configuração e pode gerar custos. Não apresente as etapas como executadas antes de comprová-las.

## Arquitetura

Veja [o desenho macro](docs/arquitetura.md). O App Service atende front e API no mesmo domínio; o Azure SQL guarda os dados; Application Insights/Log Analytics recebe requests e dependências SQL. O SQL é PaaS, não containerizado. Esta versão acadêmica não tem autenticação: mantenha os recursos acessíveis só durante a demonstração e remova depois.

## Pré-requisitos

- Uma assinatura Azure com permissão para criar Resource Group, App Service, Azure SQL e Azure Monitor, com cota na região escolhida.
- Azure CLI atualizado (com extensão `application-insights`, instalada automaticamente quando disponível), .NET SDK 10, `zip`, `curl` e um cliente Azure SQL como `sqlcmd` ou Query Editor do portal.
- Bash em Linux ou WSL; login `az login`, assinatura selecionada por `az account set --subscription <ID>`.
- Confira `az webapp list-runtimes --os linux` e altere o runtime no script se `DOTNETCORE|10.0` não estiver disponível na região. Confirme preços e oferta na assinatura antes de criar recursos; o script usa SQL Basic e plano B1, que podem gerar cobrança.

## How To (Passo a passo)

1. Crie um **repositório novo sem histórico** para esta pasta; não copie `.git`, VM, Oracle, Docker ou segredos de nenhum projeto anterior. Copie `.env.example` para `.env`. Ajuste os nomes (globais e exclusivos, especialmente `WEBAPP_NAME` e `SQL_SERVER_NAME`) e a `LOCATION`. Use sua própria assinatura. Mantenha `.env` fora do Git. Exporte `SQL_ADMIN_PASSWORD` na sessão ou deixe o script pedir a senha em terminal interativo. O login SQL deve seguir as exigências de complexidade da Azure. Nunca grave senhas ou connection strings em capturas, vídeos, comandos exibidos ou commits.

2. Crie os recursos, registrando a tela para o vídeo:

   ```bash
   az login
   az account set --subscription '<ID-DA-ASSINATURA>'
   bash scripts/01_criacao_infra.sh
   ```

   O script cria Resource Group, plano B1 Linux, Web App .NET 10, servidor Azure SQL, banco Basic, firewall para serviços Azure, Log Analytics e Application Insights. Pode ser reexecutado para recursos já existentes. Confira cada recurso no portal. Para permitir acesso do seu computador ao Query Editor ou `sqlcmd`, crie uma regra de firewall limitada ao seu IP atual com `az sql server firewall-rule create -g <GRUPO> -s <SERVIDOR-SQL> -n MeuIP --start-ip-address '<SEU-IP>' --end-ip-address '<SEU-IP>'` após carregar seu `.env` local; não exponha uma faixa ampla. A regra `0.0.0.0` do script habilita recursos dentro da Azure, não libera todos os IPs externos.

3. Na página do banco **Argos** no portal, abra **Query editor** e execute integralmente [scripts/ddl.sql](scripts/ddl.sql), autenticando com o administrador criado.

   O DDL é idempotente na primeira implantação. O esquema é a fonte de verdade: o aplicativo **não cria tabelas automaticamente**. Confirme com `SELECT * FROM dbo.ZONAS_RISCO; SELECT * FROM dbo.ALERTAS;`.

4. Faça o build e deploy pelo Azure CLI e mostre o comando no vídeo:

   ```bash
   bash scripts/02_build_deploy.sh
   ```

   O script publica o .NET, cria ZIP da pasta de publicação, configura `ConnectionStrings__ArgosSql` e `APPLICATIONINSIGHTS_CONNECTION_STRING` no App Service, executa `az webapp deploy --type zip` e espera HTTP 200 em `/health`. A senha fica no ambiente local e nas configurações privadas do App Service; não faça `az webapp config appsettings list` na gravação. Em produção real, prefira identidade gerenciada e Microsoft Entra em lugar de administrador SQL.

5. Abra a URL HTTPS impressa no terminal. Faça operações na página ou por API seguindo [docs/json-operacoes.md](docs/json-operacoes.md). Para cada operação, mostre a tabela correspondente **logo após** no Query Editor. Sequência sugerida para o vídeo: POST zona → SELECT zona → GET zona → SELECT zona → PUT zona → SELECT zona → POST alerta → SELECT alerta → GET alerta → SELECT alerta → PUT alerta → SELECT alerta → DELETE alerta → SELECT alerta → DELETE zona → SELECT zona. Mostre HTTP 201, 200 ou 204 e os IDs usados. A zona só pode ser excluída depois de seus alertas; se houver alerta ligado, DELETE zona retorna 409.

6. No portal, abra **Application Insights → Live metrics / Transaction search / Logs**. Execute novas requisições, aguarde a ingestão, mostre requests e dependências SQL coletadas. Exemplo KQL: `requests | take 20` e `dependencies | where type has 'SQL' | take 20` (ou tabelas `AppRequests`/`AppDependencies` no workspace). Mostre também **Azure SQL → Monitoring → Metrics** ou Query Editor com alterações; a monitoração do app vem do SDK OpenTelemetry. Cargas e amostragem podem afetar a visibilidade imediata das dependências; confirme antes de gravar a tomada final.

7. Após filmar, remova a infraestrutura se não for mais necessária: `bash scripts/03_remocao_infra.sh`; o script requer digitar o nome do Resource Group e espera a exclusão. Faça backup de qualquer dado que queira manter antes.

## Verificações locais

`bash -n scripts/*.sh` valida a sintaxe dos scripts. `dotnet build src/Argos.Api/Argos.Api.csproj` compila quando SDK e acesso ao NuGet estiverem disponíveis. Antes da entrega, rode criação → DDL → deploy → CRUD completo → inspeção de telemetria → exclusão, em uma assinatura autorizada. Um `/health` 200 sozinho não confirma SQL nem Application Insights.
