# Justificativa geral do projeto — Sistema de Gestão Odontológica

**Gestão de Tecnologia da Informação · Banco de Dados · E.K. Consultório Odontológico.** Versão 2 (Entrega 2), novembro de 2026. Atualiza o PDF anterior para o modelo final: 13 tabelas, Procedimento ligado à consulta e controle de compras de material.

## 1. Justificativa da escolha do estabelecimento

### 1.1 Um estabelecimento real
O trabalho partiu de um estabelecimento real, o E.K. Consultório Odontológico, no Butantã (São Paulo/SP), para compreender as dificuldades de organização dos seus dados e propor uma solução estruturada. Na área odontológica, histórico clínico, agenda, procedimentos, materiais e pagamentos formam um conjunto de dados interdependentes que exige organização rigorosa. Um caso real impõe rotinas e restrições que não foram idealizadas pelo grupo, o que obriga a analisar o problema antes de propor a solução.

### 1.2 Problemas reais de organização de dados
A modelagem só cumpre sua função quando responde a uma necessidade identificável. O levantamento com a clínica (Entrega 1 e entrevista de 02/11/2026 com a Dra. Kátia Pinheiro) definiu o escopo, quem acessa cada informação e quais relações precisam ser preservadas. Traduzir necessidades descritas de forma informal em requisitos formais é a competência que antecede o DER, o modelo lógico e a implementação.

### 1.3 Relação com o aprendizado
O caso real integrou levantamento de requisitos, entidades e atributos, relacionamentos, chaves, normalização, segurança e LGPD, mostrando que cada decisão de modelagem tem consequência sobre a consistência, o desempenho e a segurança do sistema.

## 2. Contextualização do problema

### 2.1 Dados de um consultório
O consultório lida com dados cadastrais (pacientes e profissionais), clínicos (histórico, procedimentos, diagnóstico), operacionais (agenda, horários, materiais, compras) e financeiros (pagamentos). Um mesmo atendimento gera registros em todas essas categorias, e boa parte deles é dado pessoal de saúde, protegido por sigilo profissional e pela LGPD.

### 2.2 O que a clínica relatou
A clínica tem 3 cirurgiãs-dentistas e 1 funcionária, cerca de 30 pacientes cadastrados (7 a 8 recorrentes), atende de segunda a sábado, confirma consultas pelo WhatsApp, anota os materiais usados em cada procedimento e compra material uma vez por mês a partir de uma lista do que está em falta. Os problemas declarados (P1 a P9) são: agenda e horários, dados dos pacientes, prontuários e histórico, procedimentos, pagamentos e pendências, materiais usados, estoque e compras, cancelamentos e remarcações, e acesso aos prontuários.

### 2.3 Dificuldades típicas sem banco de dados
- **Duplicidade:** o mesmo paciente registrado mais de uma vez.
- **Dispersão:** histórico, agenda, estoque e pagamentos em suportes diferentes.
- **Inconsistência:** a alteração em um lugar não chega aos outros.
- **Dificuldade de recuperação:** localizar o histórico de um paciente ou os pagamentos de um atendimento toma tempo e gera erro.

## 3. Justificativa da solução proposta

### 3.1 Um sistema de gestão odontológica
A solução é um banco de dados relacional projetado para o contexto da clínica, em que cada entidade, atributo e relacionamento representa uma atividade real.

### 3.2 Como o banco melhora a organização
Cada informação é guardada uma única vez e referenciada pelas demais. Isso reduz duplicidade, garante consistência e torna as consultas previsíveis. A base única também permite regras de acesso, registro de auditoria e relatórios gerenciais.

### 3.3 Benefícios esperados
Localização rápida de informações, menos retrabalho, agenda organizada com confirmação e controle de faltas, controle de procedimentos, materiais e compras, acompanhamento de pagamentos e segurança no acesso aos prontuários. São benefícios esperados, ainda não medidos em operação.

## 4. Justificativa da modelagem

### 4.1 Modelo relacional
Os dados do consultório são fortemente estruturados e relacionados; o modelo relacional (Codd, 1970), com SQL e mecanismos de integridade e transação, é adequado e de ampla adoção.

### 4.2 Separação em entidades
Cada conceito do domínio tem sua tabela, com atributos coesos, o que permite evoluir o sistema incluindo tabelas sem reestruturar o conjunto (como foi feito com Entrada_estoque nesta entrega).

### 4.3 Normalização
O modelo está em 3FN (Elmasri; Navathe, 2018). Exemplos: os dados do material ficam em Material, e não em cada uso; o uso é a associativa Procedimento_Material; Procedimento guarda só a consulta, porque paciente e dentista dependem dela. O detalhamento está na seção 1.4 do README.

### 4.4 Integridade referencial
As chaves estrangeiras impedem registros órfãos e a exclusão de registros com histórico.

### 4.5 Redundância controlada
A única redundância mantida de propósito é o estoque em Material (que poderia ser calculado por entradas − usos), conferida pela auditoria A14.

## 5. Entidades e relacionamentos

O modelo tem **13 tabelas** (12 entidades e a associativa Procedimento_Material):

| Tabela | Papel |
|---|---|
| Usuario | Pessoas que usam o sistema; login, perfil e permissão de prontuário |
| Dentista | Profissionais que atendem |
| Horario_atendimento | Horários semanais de cada dentista |
| Paciente | Pessoas atendidas, com consentimento LGPD |
| Prontuario | Registro clínico do paciente (1:1) |
| Consulta | Atendimento agendado, confirmado, realizado, cancelado ou com falta |
| Procedimento | Ato odontológico feito durante uma consulta, com valor cobrado |
| Pagamento | Recebimentos e parcelas de um procedimento |
| Material | Insumos, com estoque, mínimo e validade |
| Entrada_estoque | Compras (entradas) de material |
| Procedimento_Material | Uso de material em procedimento (quantidade e data) |
| Log_auditoria | Ações relevantes, com o usuário responsável |
| Acesso_prontuario | Cada consulta ou alteração de prontuário |

- **Cadastrais (Usuario, Dentista, Paciente):** a separação entre Usuario e Dentista permite que a recepção tenha conta e que a permissão de prontuário seja controlada por pessoa.
- **Clínicas e de agenda (Prontuario, Consulta, Horario_atendimento, Procedimento):** Prontuario separado permite controlar e auditar o acesso; Consulta liga paciente, dentista e tempo; Procedimento registra o que foi feito em cada consulta.
- **Insumos (Material, Entrada_estoque, Procedimento_Material):** controlam o que entra e o que é consumido.
- **Financeira (Pagamento):** liga o recebimento ao procedimento que o originou.
- **Segurança (Log_auditoria, Acesso_prontuario):** permitem reconstituir quem fez o quê e quando.

## 6. Chaves primárias e estrangeiras

Todas as PKs são identificadores técnicos `INT AUTO_INCREMENT`; CPF, CRO e login são chaves candidatas com UNIQUE. As FKs concretizam os relacionamentos e impõem a integridade referencial. Procedimento_Material usa PK composta (`id_procedimento`, `id_material`), que também orienta a verificação da 2FN. Ver `Identificacao_PKs_FKs.md`.

## 7. Segurança e proteção dos dados

- **Controle de acesso:** perfis (recepção e dentista) e permissão individual de prontuário — só a Dra. Kátia e a Dra. Elielma acessam (RN48).
- **Auditoria:** Log_auditoria e Acesso_prontuario dão rastreabilidade.
- **LGPD:** dados de saúde são sensíveis (art. 5º, II, e art. 11). O sistema registra o consentimento (RN46), não apaga registros clínicos e segue a orientação do CFO de guarda por no mínimo 20 anos (RN47). A clínica informou guardar por 1 ano; o projeto recomenda adequar. A conformidade também depende de medidas organizacionais (políticas, treinamento, autenticação segura).

## 8. BI e IA

A base organizada já calcula os indicadores de gestão (consultas G01 a G20) e cria condições para BI e IA futuros: previsão de faltas, de consumo de material e de demanda. Ver `Proposta_Arquitetura_Analitica_BI_IA.md`.

## 9. Justificativa acadêmica

O projeto integra levantamento de requisitos, DER, modelo lógico, chaves, normalização, SQL e LGPD em torno de um problema concreto, e desenvolve competências como análise de contexto, comunicação com a organização e justificativa de decisões.

## 10. Resultados esperados e conclusão

A estrutura proposta, com 13 tabelas, chaves, restrições e auditorias, responde aos problemas P1 a P9 da clínica: organização, consistência, segurança e base para evolução tecnológica. A implantação e a medição dos resultados são etapas futuras.

## Referências

- BRASIL. Lei nº 13.709, de 14 de agosto de 2018. Lei Geral de Proteção de Dados Pessoais (LGPD).
- CODD, E. F. A relational model of data for large shared data banks. *Communications of the ACM*, v. 13, n. 6, p. 377-387, 1970.
- DATE, C. J. *Introdução a sistemas de bancos de dados*. 8. ed. Rio de Janeiro: Elsevier, 2004.
- ELMASRI, R.; NAVATHE, S. B. *Sistemas de banco de dados*. 7. ed. São Paulo: Pearson, 2018.
- SILBERSCHATZ, A.; KORTH, H. F.; SUDARSHAN, S. *Sistema de banco de dados*. 6. ed. Rio de Janeiro: Elsevier, 2012.
