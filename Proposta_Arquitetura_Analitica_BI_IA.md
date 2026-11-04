# Proposta de arquitetura analítica para BI e IA

**Sistema de Gestão Odontológica — E.K. Consultório Odontológico.** Versão 2 (Entrega 2). Os KPIs com fórmula, período, meta e a consulta SQL que calcula cada um estão na seção 1.6 do `README.md`.

## 1. Objetivo

Transformar os dados operacionais da clínica em indicadores para a gestão e, no futuro, em análises preditivas, sem sobrecarregar o banco transacional. É uma proposta conceitual: hoje os indicadores já são calculados pelas consultas gerenciais G01 a G20 do script.

## 2. BI e IA

- **BI:** indicadores, relatórios e painéis sobre o que aconteceu (agenda, faltas, faturamento, estoque).
- **IA:** padrões e previsões a partir do histórico (faltas, consumo de material, demanda), sempre com revisão humana.

## 3. Arquitetura proposta

1. **Banco operacional (`ek_consultorio`):** pacientes, dentistas, consultas, procedimentos, pagamentos, materiais, compras, acessos e auditoria.
2. **ETL/ELT:** extração periódica, validação, padronização e **pseudonimização** dos dados pessoais.
3. **Data warehouse:** fatos e dimensões com histórico.
4. **BI:** painéis e indicadores. **IA:** previsões e alertas.

Para o porte da clínica (cerca de 30 pacientes e 2 a 3 atendimentos por dia), as etapas 2 e 3 podem começar como **visões SQL** no próprio MySQL; um data warehouse separado só se justifica com mais histórico.

## 4. Modelo dimensional sugerido

| Tabela analítica | Granularidade | Medidas / atributos | Origem no banco |
|---|---|---|---|
| Fato_Consulta | uma linha por consulta | contagem, duração prevista, status (realizada, falta, cancelada) | Consulta |
| Fato_Procedimento | uma linha por procedimento | quantidade, valor cobrado | Procedimento |
| Fato_Pagamento | uma linha por pagamento | valor, forma, status | Pagamento |
| Fato_Consumo_Material | uma linha por material usado | quantidade | Procedimento_Material |
| Fato_Compra_Material | uma linha por entrada | quantidade, fornecedor | Entrada_estoque |
| Dim_Tempo | uma linha por data | dia, mês, dia da semana, feriado | derivada |
| Dim_Dentista | uma linha por dentista | especialidade | Dentista |
| Dim_Procedimento | uma linha por nome de procedimento | nome | Procedimento |
| Dim_Material | uma linha por material | unidade de consumo, mínimo | Material |

Para relatórios gerenciais, usar dados agregados ou pseudonimizados; prontuários e identificadores pessoais não vão para o ambiente analítico.

## 5. Indicadores de BI (implementados no script)

| Indicador | Consulta | Meta |
|---|---|---|
| Atendimentos por dia | G15 | acompanhamento (capacidade: até 9/dia) |
| Ocupação da agenda | G16 | ≥ 70% |
| Taxa de faltas | G19 | ≤ 10% ao mês |
| Taxa de cancelamento | G11 | ≤ 15% ao mês |
| Pacientes ativos (90 dias) | G04 | ≥ 60% |
| Valor em aberto | G07 | nenhum saldo com mais de 30 dias |
| Faturamento recebido | G08 | acompanhamento mensal |
| Ticket médio por procedimento | G14 | acompanhamento |
| Materiais em risco (estoque ou validade) | G10 | 0 |
| Compras x consumo de material | G20 | acompanhamento |

## 6. Aplicações de IA (futuras)

| Aplicação | Dados de entrada | Resultado esperado |
|---|---|---|
| Previsão de faltas | histórico de faltas e cancelamentos do paciente, dia da semana, horário, confirmação | lista de consultas com risco de falta para a recepção confirmar com prioridade |
| Previsão de consumo de material | uso por procedimento + agenda futura + estoque | data estimada em que cada material chega ao mínimo; sugestão para a compra mensal |
| Lembrete de retorno | data da última consulta realizada | pacientes a chamar para manutenção |
| Previsão financeira | pagamentos históricos e procedimentos agendados | projeção de receita do mês, com margem de incerteza |

Com o volume atual da clínica, os modelos de IA precisam de alguns meses de histórico antes de dar resultado confiável.

## 7. Segurança, privacidade e governança

- Acesso por função e menor privilégio (`perfil_acesso`, `acessa_prontuario`).
- Registro de acessos e alterações (Acesso_prontuario, Log_auditoria).
- Consentimento do paciente registrado antes do atendimento (RN46).
- Minimização e pseudonimização dos dados nas análises.
- Dados clínicos identificáveis não são enviados a serviços externos de IA sem avaliação jurídica e técnica.
- Supervisão humana de qualquer decisão que afete pacientes.

## 8. Implantação em etapas

| Etapa | Atividade | Entrega |
|---|---|---|
| 1. Preparação | Banco revisado, regras e dicionário documentados | feito nesta entrega |
| 2. Indicadores | Consultas gerenciais G01–G20 com metas | feito nesta entrega |
| 3. Painel | Painel com G01, G11, G15, G16, G19, G07, G08 e G10 | futuro |
| 4. IA | Previsão de faltas e de consumo, com avaliação treino/teste | futuro |
| 5. Operação | Monitorar qualidade dos dados, segurança e desempenho dos modelos | futuro |

## 9. Conclusão

A base já calcula os indicadores de gestão da clínica. A camada analítica proposta amplia esse valor com histórico e previsões, de forma incremental, priorizando qualidade dos dados e privacidade.
