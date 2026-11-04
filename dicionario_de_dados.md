# Dicionário de Dados

**E.K. Consultório Odontológico** — versão v1.2, novembro de 2026

Este dicionário descreve o banco de dados `ek_consultorio`, exatamente como ele é criado pelo arquivo `docs/script.sql`. Tipos, obrigatoriedade, unicidade, valores permitidos e valores padrão aqui indicados são os do script.

---

## 1. Modelo conceitual

O modelo representa um consultório odontológico particular, com três dentistas e uma funcionária de atendimento, que atende de segunda a sábado (fechado em feriados nacionais). Cada paciente tem um prontuário e é atendido em consultas agendadas com um dentista, que a recepção confirma antes do dia. Do atendimento resultam procedimentos, que consomem materiais e geram pagamentos. As compras de material entram no estoque. As contas de usuário e os registros de auditoria controlam quem faz o quê.

### 1.1 Entidades

| Entidade | Descrição |
|---|---|
| Paciente | Pessoa física atendida pelo consultório. |
| Prontuario | Registro do histórico clínico do paciente. Cada paciente tem exatamente um. |
| Dentista | Cirurgião-dentista com registro no CRO, que atende e realiza procedimentos. |
| Horario_atendimento | Período semanal em que um dentista atende (dia da semana, hora de início e de término). |
| Usuario | Conta de acesso ao sistema, com login individual, perfil (recepção ou dentista) e permissão de acesso a prontuário. |
| Consulta | Atendimento agendado de um paciente com um dentista. É uma entidade comum, não associativa. |
| Procedimento | Ato odontológico feito durante uma consulta, com valor cobrado quando aplicável. Paciente e dentista são os da consulta. |
| Pagamento | Lançamento de recebimento ou parcela de um procedimento. |
| Material | Insumo do consultório, com estoque, estoque mínimo e validade, controlado na unidade de consumo. |
| Entrada_estoque | Compra (ou saldo inicial de inventário) de um material, com data, quantidade e fornecedor. |
| Procedimento_Material | Entidade associativa do relacionamento *Utiliza*: registra a quantidade e a data de uso de cada material em cada procedimento. |
| Acesso_prontuario | Registro de cada consulta ou alteração de um prontuário por um usuário. |
| Log_auditoria | Registro das ações relevantes (cancelamentos, remarcações, confirmações de pagamento), com o usuário responsável. |

### 1.2 Relacionamentos e cardinalidades

**Como ler:** notação do brModelo, a mesma do DER e do modelo lógico. O par (mínimo, máximo) escrito ao lado de uma entidade diz com quantas ocorrências *dessa* entidade uma ocorrência da outra se relaciona. Por exemplo, em "Paciente (1,1) – Consulta (0,n)", cada consulta tem exatamente um paciente, e cada paciente tem de zero a várias consultas. Mínimo 0 significa participação opcional, e mínimo 1 significa obrigatória.

| Entidade A | Relacionamento | Entidade B | Cardinalidade (A – B) | Leitura |
|---|---|---|---|---|
| Paciente | Possui | Prontuario | (1,1) – (1,1) | Cada paciente tem exatamente um prontuário, e cada prontuário pertence a exatamente um paciente (RN05). |
| Paciente | Agenda | Consulta | (1,1) – (0,n) | Um paciente pode ter de zero a várias consultas, e cada consulta é de um único paciente (RN08). |
| Dentista | Atende | Consulta | (1,1) – (0,n) | Um dentista pode ter de zero a várias consultas, e cada consulta é de um único dentista (RN08). |
| Consulta | Origina | Procedimento | (1,1) – (0,n) | Uma consulta pode originar nenhum ou vários procedimentos, e todo procedimento é feito em exatamente uma consulta (RN19). Paciente e dentista do procedimento são os da consulta. |
| Material | Recebe_entrada | Entrada_estoque | (1,1) – (0,n) | Um material pode ter várias entradas (compras), e cada entrada é de um único material (RN51). |
| Procedimento | Tem_pagamento | Pagamento | (1,1) – (0,n) | Um procedimento pode ter nenhum ou vários pagamentos (parcelas), e cada pagamento é de um único procedimento (RN24, RN25). |
| Procedimento | Utiliza | Material | (0,n) – (0,n) | Relação muitos para muitos, resolvida pela associativa Procedimento_Material, que guarda quantidade e data de uso (RN37). |
| Dentista | Possui_horario | Horario_atendimento | (1,1) – (1,n) | Cada dentista tem pelo menos um período de atendimento, e cada período é de um único dentista (RN42). |
| Usuario | Vincula_se | Dentista | (1,1) – (0,1) | Cada usuário se liga a no máximo um dentista (a recepção não se liga), e cada dentista tem exatamente uma conta. |
| Usuario | Registra | Log_auditoria | (1,1) – (0,n) | Um usuário gera vários registros de auditoria, e cada registro tem um único usuário responsável (RN33). |
| Usuario | Realiza_acesso | Acesso_prontuario | (1,1) – (0,n) | Um usuário gera vários acessos, e cada acesso é de um único usuário (RN41). |
| Prontuario | Sofre_acesso | Acesso_prontuario | (1,1) – (0,n) | Um prontuário recebe vários acessos, e cada acesso é a um único prontuário (RN41). |

O DER e o modelo lógico usam a mesma notação, e cada par aparece do mesmo lado nos dois diagramas. No script, as cardinalidades são garantidas pelas restrições: `Prontuario.id_paciente` é UNIQUE (1:1), `Procedimento.id_consulta` é NOT NULL (1,1) e `Usuario.id_dentista` aceita NULL e é UNIQUE.

---

## 2. Fluxo de dados

O paciente liga ou chega ao consultório. A funcionária consulta ou cadastra o **Paciente** (com a data do consentimento LGPD quando ele assina), e o **Prontuario** é aberto. A consulta é agendada em **Consulta** (`agendada`), ligando o paciente a um **Dentista** dentro do seu **Horario_atendimento**. Antes do dia, a recepção confirma por telefone ou WhatsApp (`confirmada`). No dia, a consulta termina como `realizada`, `falta` ou `cancelada`. No atendimento, o dentista avalia o paciente, define os tratamentos e os valores e registra observações e diagnóstico na consulta (a dentista sem acesso ao prontuário tem o registro transcrito por uma dentista com acesso, RN48). O que é feito vira **Procedimento**, ligado à consulta, com o valor cobrado, e os materiais usados são registrados em **Procedimento_Material**, com baixa do estoque em **Material**. As compras de material são registradas em **Entrada_estoque** e somadas ao estoque. O valor gera um ou mais lançamentos em **Pagamento** (pendentes até a confirmação do recebimento). Toda abertura de prontuário vai para **Acesso_prontuario**, e as ações relevantes (confirmação, falta, cancelamento, remarcação, confirmação de pagamento) vão para **Log_auditoria**. Essas duas tabelas sustentam a auditoria e a conformidade com a LGPD (seção 6).

---

## 3. Convenções do dicionário

- **SGBD:** MySQL 8.0.16 ou superior (necessário para as restrições CHECK), com o mecanismo InnoDB, que é o padrão do MySQL 8.
- **Codificação:** `utf8mb4`, com collation `utf8mb4_unicode_ci`, para guardar acentos do português sem perda.
- **Nomes:** tabelas com inicial maiúscula e colunas em `snake_case`, minúsculas e sem acento, iguais às do modelo lógico e do script.
- **Tipos:** valores monetários usam `DECIMAL(10,2)` e textos longos usam `TEXT` no banco. O modelo lógico (`diagramas/modelo_logico.png`) mostra os mesmos tipos do script.
- **Chaves estrangeiras:** nenhuma usa `ON DELETE CASCADE`. Vale o comportamento padrão (`RESTRICT`), que impede apagar um registro ainda referenciado, em linha com a RN22 (sem exclusão definitiva).
- **Valores nulos:** "Obrigatório = Não" significa que a coluna aceita NULL. Uma coluna UNIQUE que aceita NULL permite vários valores nulos.
- **Valores de domínio fechado** (status, perfil, tipos) são gravados em minúsculas e sem acento.
- **Índices:** o InnoDB cria índices automaticamente para as chaves primárias, para as restrições UNIQUE e para cada chave estrangeira. Nesta versão não foram criados índices adicionais.

### Notação formal

| Símbolo | Significado |
|---|---|
| `=` | é composto de |
| `+` | e (conecta elementos obrigatórios) |
| `( )` | opcional |
| `[ \| ]` | escolha obrigatória entre alternativas |
| `/ /` | rótulo de um grupo de atributos |
| `@` | identificador (chave primária) |

### Prefixos e padrões de nome

| Padrão | Significado |
|---|---|
| `id_` | identificador (chave primária ou estrangeira); não sofre operação matemática |
| `nome_` | nome |
| `data_` / `hora_` | data e hora |
| `quantidade_` / `estoque_` | quantidade |
| `valor` / `valor_` | valor monetário |
| `tipo_` / `forma_` / `status_` / `perfil_` | categorização (domínio fechado ou lista de exemplos) |
| `descricao` / `observacoes` / `motivo` | texto livre |

**Versão:** v1.1, novembro de 2026. Qualquer alteração de estrutura deve gerar uma nova versão registrada aqui, o que atende ao princípio de responsabilização e prestação de contas da LGPD (art. 6º, X).

---

## 4. Dicionário de dados por entidade

### PACIENTE

`PACIENTE = @id_paciente + nome_completo + data_nascimento + (cpf) + (telefone) + (email) + (/ENDERECO/ = (logradouro) + (numero) + (complemento) + (bairro) + (cidade) + (uf) + (cep)) + (data_consentimento_lgpd)`

**Leitura:** `nome_completo` e `data_nascimento` são obrigatórios. O CPF só é registrado quando disponível (RN02) e, se informado, é único (RN03). O grupo ENDERECO é opcional e foi dividido em atributos atômicos (1FN). A data do consentimento LGPD fica vazia até o paciente assinar, e deve ser anterior ao primeiro atendimento (RN46).

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_paciente | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do paciente (RN01). |
| nome_completo | VARCHAR(100) | Sim | Não | Texto | — | Nome completo do paciente. |
| data_nascimento | DATE | Sim | Não | Data válida | — | Permite calcular a idade. |
| cpf | CHAR(11) | Não | Sim (se informado) | 11 dígitos, sem pontuação (CHECK de tamanho) | NULL | Apoia a verificação de duplicidade (RN03). |
| email | VARCHAR(100) | Não | Não | Texto | NULL | Contato alternativo. |
| telefone | VARCHAR(15) | Não | Não | Texto | NULL | Contato para agendamento. |
| logradouro | VARCHAR(100) | Não | Não | Texto | NULL | Rua, avenida etc. |
| numero | VARCHAR(10) | Não | Não | Texto | NULL | Número do imóvel. É texto para aceitar "S/N". |
| complemento | VARCHAR(50) | Não | Não | Texto | NULL | Apartamento, bloco etc. |
| bairro | VARCHAR(60) | Não | Não | Texto | NULL | Bairro. |
| cidade | VARCHAR(60) | Não | Não | Texto | NULL | Cidade. |
| uf | CHAR(2) | Não | Não | Texto de 2 letras | NULL | Unidade da federação. |
| cep | CHAR(8) | Não | Não | 8 dígitos, sem hífen | NULL | Código de endereçamento postal. |
| data_consentimento_lgpd | DATE | Não | Não | Data válida, anterior ao primeiro atendimento | NULL | Data em que o paciente assinou o termo de consentimento para tratamento dos dados de saúde (RN46). Conferida pela auditoria **A12**. |

**Restrições no script:** `pk_paciente`, `uq_paciente_cpf`, `ck_paciente_cpf` (CPF nulo ou com 11 caracteres).
**Regras:** não há exclusão definitiva (RN22). A tabela não pode ser apagada enquanto houver consulta, procedimento ou prontuário ligados (FK).
**Índices:** PK `id_paciente` (clusterizado) e índice único em `cpf`.

### PRONTUARIO

`PRONTUARIO = @id_prontuario + id_paciente + data_criacao + (observacoes_gerais)`

**Leitura:** `id_paciente` é obrigatório e único, o que garante a relação 1:1 com Paciente (RN05). As observações gerais são opcionais.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_prontuario | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do prontuário. |
| id_paciente | INT | Sim (FK) | Sim | Id existente em Paciente | — | Paciente titular. A unicidade garante o 1:1. |
| data_criacao | DATE | Sim | Não | Data válida | — | Data de abertura do prontuário (também usada como data de cadastro do paciente em G03). |
| observacoes_gerais | TEXT | Não | Não | Texto livre | NULL | Observações clínicas gerais. Só podem ser alteradas por profissional autorizado (RN21). |

**Restrições no script:** `pk_prontuario`, `fk_prontuario_paciente`, `uq_prontuario_paciente`.
**Índices:** PK `id_prontuario` e índice único em `id_paciente`.

### DENTISTA

`DENTISTA = @id_dentista + nome_completo + cpf + cro + (telefone) + (email) + (especialidade)`

**Leitura:** `cpf` e `cro` são obrigatórios e únicos (RN04). Os horários de atendimento ficam em Horario_atendimento.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_dentista | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do dentista. |
| nome_completo | VARCHAR(100) | Sim | Não | Texto | — | Nome completo. |
| cpf | CHAR(11) | Sim | Sim | 11 dígitos, sem pontuação (CHECK de tamanho) | — | Documento da pessoa física. |
| cro | VARCHAR(15) | Sim | Sim | Texto | — | Registro no Conselho Regional de Odontologia. |
| telefone | VARCHAR(15) | Não | Não | Texto | NULL | Contato do profissional. |
| email | VARCHAR(100) | Não | Não | Texto | NULL | Contato alternativo. |
| especialidade | VARCHAR(60) | Não | Não | Texto | NULL | Especialidade. Nesta versão, uma por dentista. |

**Restrições no script:** `pk_dentista`, `uq_dentista_cpf`, `uq_dentista_cro`, `ck_dentista_cpf`.
**Índices:** PK `id_dentista` e índices únicos em `cpf` e `cro`.

### HORARIO_ATENDIMENTO

`HORARIO_ATENDIMENTO = @id_horario + id_dentista + dia_semana + hora_inicio + hora_fim`

**Leitura:** todos os campos são obrigatórios. Cada linha é um período de atendimento de um dentista em um dia da semana. Um dentista pode ter vários períodos no mesmo dia (por exemplo, manhã e tarde).

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_horario | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do período. |
| id_dentista | INT | Sim (FK) | Parte da chave única composta | Id existente em Dentista | — | Dentista dono do horário. |
| dia_semana | INT | Sim | Parte da chave única composta | 1 a 7 (1 = segunda, 7 = domingo) | — | Dia da semana. |
| hora_inicio | TIME | Sim | Parte da chave única composta | Hora válida, menor que `hora_fim` | — | Início do período. |
| hora_fim | TIME | Sim | Não | Hora válida, maior que `hora_inicio` | — | Fim do período. |

**Restrições no script:** `pk_horario`, `fk_horario_dentista`, `uq_horario` (id_dentista, dia_semana, hora_inicio), `ck_horario_dia`, `ck_horario_intervalo`.
**Regras:** base para a regra de disponibilidade (RN09 e RN42). A sobreposição de períodos do mesmo dia não é barrada por restrição.
**Índices:** PK `id_horario` e índice único composto (`id_dentista`, `dia_semana`, `hora_inicio`).

### USUARIO

`USUARIO = @id_usuario + (id_dentista) + nome_usuario + login + senha_hash + [recepcao | dentista] + acessa_prontuario`

**Leitura:** `login` é obrigatório e único (conta individual, RN06 e RN29). `id_dentista` é opcional, pois a recepção não tem ficha de dentista, mas é obrigatório quando o perfil é `dentista`. `acessa_prontuario` indica quem pode abrir prontuário: na clínica, só duas das três dentistas (RN48).

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_usuario | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do usuário. |
| id_dentista | INT | Não (FK) | Sim (se informado) | Id existente em Dentista | NULL | Liga a conta ao dentista. É única, pois cada dentista tem uma conta. |
| nome_usuario | VARCHAR(60) | Sim | Não | Texto | — | Nome da pessoa dona da conta. |
| login | VARCHAR(40) | Sim | Sim | Texto | — | Identificador de acesso individual. |
| senha_hash | VARCHAR(255) | Sim | Não | Hash da senha, nunca texto puro | — | Senha protegida (RN31). |
| perfil_acesso | VARCHAR(20) | Sim | Não | `recepcao`, `dentista` | — | Define as funções permitidas (RN07 e RN30). |
| acessa_prontuario | BOOLEAN | Sim | Não | `TRUE`, `FALSE` | `FALSE` | Permissão para abrir prontuário (RN48). Acesso de usuário sem permissão é apontado pela auditoria **A13**. |

**Restrições no script:** `pk_usuario`, `fk_usuario_dentista`, `uq_usuario_login`, `uq_usuario_dentista`, `ck_usuario_perfil`, `ck_usuario_perfil_dentista` (perfil `dentista` exige `id_dentista`).
**Índices:** PK `id_usuario` e índices únicos em `login` e em `id_dentista`.

### LOG_AUDITORIA

`LOG_AUDITORIA = @id_log + id_usuario + data_hora + tipo_acao + (descricao)`

**Leitura:** cada registro tem exatamente um usuário responsável (RN33).

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_log | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do registro. |
| id_usuario | INT | Sim (FK) | Não | Id existente em Usuario | — | Usuário responsável pela ação. |
| data_hora | DATETIME | Sim | Não | Data e hora válidas | `CURRENT_TIMESTAMP` | Momento da ação. |
| tipo_acao | VARCHAR(40) | Sim | Não | Texto. Valores usados: `CONFIRMACAO`, `FALTA`, `CANCELAMENTO`, `REMARCACAO`, `CONFIRMACAO_PAGAMENTO` | — | Categoria da ação auditada (RN32). A remarcação guarda a data antiga e a nova na descrição (RN14). |
| descricao | VARCHAR(255) | Não | Não | Texto | NULL | Detalhe do que foi feito. |

**Restrições no script:** `pk_log`, `fk_log_usuario`.
**Regras:** o sistema não oferece alterar nem apagar esses registros (política de permissões, ver seção 6). O banco não tem trava própria para isso.
**Índices:** PK `id_log` e o índice automático da FK `id_usuario`.

### ACESSO_PRONTUARIO

`ACESSO_PRONTUARIO = @id_acesso + id_usuario + id_prontuario + data_acesso + [consulta | alteracao]`

**Leitura:** todos os campos são obrigatórios. Cada linha registra uma consulta ou alteração de prontuário por um usuário (RN41).

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_acesso | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do acesso. |
| id_usuario | INT | Sim (FK) | Não | Id existente em Usuario | — | Quem acessou. |
| id_prontuario | INT | Sim (FK) | Não | Id existente em Prontuario | — | Prontuário acessado. |
| data_acesso | DATETIME | Sim | Não | Data e hora válidas | `CURRENT_TIMESTAMP` | Momento do acesso. |
| tipo_acesso | VARCHAR(20) | Sim | Não | `consulta`, `alteracao` | — | Leitura ou alteração. |

**Restrições no script:** `pk_acesso`, `fk_acesso_usuario`, `fk_acesso_prontuario`, `ck_acesso_tipo`.
**Índices:** PK `id_acesso` e os índices automáticos das FKs.

### CONSULTA

`CONSULTA = @id_consulta + id_paciente + id_dentista + data_consulta + hora_consulta + duracao_prevista + [agendada | confirmada | realizada | cancelada | falta] + (tipo_consulta) + (motivo) + (observacoes) + (diagnostico) + (motivo_cancelamento)`

**Leitura:** paciente, dentista, data, hora, duração e status são obrigatórios (RN08). Tipo, motivo, observações, diagnóstico e motivo do cancelamento são opcionais. Consulta é uma entidade comum, ligada a um paciente e a um dentista.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_consulta | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador da consulta. |
| id_paciente | INT | Sim (FK) | Não | Id existente em Paciente | — | Paciente atendido. |
| id_dentista | INT | Sim (FK) | Não | Id existente em Dentista | — | Dentista responsável. |
| data_consulta | DATE | Sim | Não | Data válida | — | Dia da consulta. |
| hora_consulta | TIME | Sim | Não | Hora válida | — | Hora de início. |
| duracao_prevista | INT | Sim | Não | Minutos, maior que 0 | — | Duração prevista. Usada para detectar sobreposição (RN10). |
| tipo_consulta | VARCHAR(40) | Não | Não | Texto. Valores usados: `avaliacao`, `retorno`, `manutencao`, `urgencia` | NULL | Categoria da consulta. |
| motivo | VARCHAR(255) | Não | Não | Texto | NULL | Motivo informado. |
| status | VARCHAR(15) | Sim | Não | `agendada`, `confirmada`, `realizada`, `cancelada`, `falta` | `agendada` | Situação da consulta (RN11). `confirmada` quando a recepção confirma (RN49); `falta` quando o paciente não comparece (RN50). |
| observacoes | TEXT | Não | Não | Texto livre | NULL | Observações clínicas do atendimento (RN17 e RN21). |
| diagnostico | TEXT | Não | Não | Texto livre | NULL | Diagnóstico registrado pelo dentista. |
| motivo_cancelamento | VARCHAR(255) | Não | Não | Texto | NULL | Justificativa do cancelamento (RN12). Preenchido quando houver. |

**Restrições no script:** `pk_consulta`, `fk_consulta_paciente`, `fk_consulta_dentista`, `ck_consulta_duracao`, `ck_consulta_status`.
**Regras:** não há exclusão definitiva: cancelar muda o status (RN12 e RN22). Não há UNIQUE em (dentista, data, hora), porque a consulta cancelada permanece no histórico e o horário pode ser reutilizado (RN13). A sobreposição de horários (RN10) e a consulta fora do horário do dentista (RN09) são conferidas pelas consultas de auditoria **A01** e **A02**. Consulta que já passou e continua `agendada` ou `confirmada` é apontada pela **A11** (RN50).
**Índices:** PK `id_consulta` e os índices automáticos das FKs `id_paciente` e `id_dentista`.

### PROCEDIMENTO

`PROCEDIMENTO = @id_procedimento + id_consulta + nome_procedimento + data_procedimento + (descricao) + (valor_cobrado)`

**Leitura:** consulta, nome e data são obrigatórios (RN18 e RN19). Todo procedimento é feito durante uma consulta; paciente e dentista são obtidos pela consulta e não são repetidos aqui (3FN). O valor cobrado é opcional, e é definido caso a caso, sem catálogo de preços (decisão justificada no README).

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_procedimento | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do procedimento. |
| id_consulta | INT | Sim (FK) | Não | Id existente em Consulta | — | Consulta em que o procedimento foi feito. Dela vêm o paciente e o dentista. |
| nome_procedimento | VARCHAR(100) | Sim | Não | Texto | — | Por exemplo, profilaxia ou restauração. |
| data_procedimento | DATE | Sim | Não | Data válida | — | Data de realização. |
| descricao | TEXT | Não | Não | Texto livre | NULL | Detalhes (dente, técnica etc.). |
| valor_cobrado | DECIMAL(10,2) | Não | Não | Maior ou igual a 0 | NULL | Valor cobrado pelo procedimento. |

**Restrições no script:** `pk_procedimento`, `fk_procedimento_consulta`, `ck_procedimento_valor`.
**Regras:** a data do procedimento deve ser a da consulta (RN19 e RN35), conferido pela auditoria **A04**; procedimento só em consulta `realizada`, conferido pela **A10**. Não há exclusão definitiva (RN22).
**Índices:** PK `id_procedimento` e o índice automático da FK `id_consulta`.

### PAGAMENTO

`PAGAMENTO = @id_pagamento + id_procedimento + valor + (data_pagamento) + [pendente | pago] + forma_pagamento`

**Leitura:** `id_procedimento` liga o pagamento a exatamente um procedimento (RN24). O paciente é obtido por Procedimento → Consulta e não é gravado aqui. Um procedimento pode ter vários pagamentos, como parcelas (RN25). `data_pagamento` fica vazia enquanto o pagamento está pendente e é obrigatória quando ele está pago.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_pagamento | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do lançamento. |
| id_procedimento | INT | Sim (FK) | Não | Id existente em Procedimento | — | Procedimento pago. |
| valor | DECIMAL(10,2) | Sim | Não | Maior que 0 | — | Valor do lançamento (total ou parcela). |
| data_pagamento | DATE | Não | Não | Data válida. Obrigatória quando o status é `pago` | NULL | Data do recebimento. |
| forma_pagamento | VARCHAR(30) | Sim | Não | Texto. Valores usados: `pix`, `dinheiro`, `cartao_credito`, `cartao_debito` | — | Meio de pagamento. |
| status_pagamento | VARCHAR(10) | Sim | Não | `pendente`, `pago` | `pendente` | Só passa a `pago` após a confirmação do recebimento (RN26). |

**Restrições no script:** `pk_pagamento`, `fk_pagamento_procedimento`, `ck_pagamento_valor`, `ck_pagamento_status`, `ck_pagamento_data` (status `pago` exige data).
**Regras:** comprovante só para pagamento `pago` (RN27). Correções são feitas por usuário autorizado e registradas em Log_auditoria (RN28). A soma dos pagamentos não pode passar do valor cobrado (RN25): conferido pela consulta de auditoria **A05**.
**Índices:** PK `id_pagamento` e o índice automático da FK `id_procedimento`.

### MATERIAL

`MATERIAL = @id_material + nome_material + unidade + quantidade_estoque + estoque_minimo + (data_validade)`

**Leitura:** nome, unidade e as duas quantidades são obrigatórios. A validade é opcional, pois nem todo material vence.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_material | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador do material. |
| nome_material | VARCHAR(100) | Sim | Não | Texto | — | Nome do material. |
| unidade | VARCHAR(20) | Sim | Não | Texto. Valores usados: `par`, `unidade`, `tubete`, `grama`, `mL` | — | Unidade de consumo. Estoque, mínimo, entradas e usos usam a mesma unidade. |
| quantidade_estoque | INT | Sim | Não | Maior ou igual a 0 | 0 | Quantidade disponível (RN36). Deve ser igual a entradas − usos (RN51). |
| estoque_minimo | INT | Sim | Não | Maior ou igual a 0 | 0 | Nível que indica reposição (RN39). |
| data_validade | DATE | Não | Não | Data válida | NULL | Validade, quando aplicável (RN40). |

**Restrições no script:** `pk_material`, `ck_material_estoque`, `ck_material_minimo`.
**Regras:** material com `quantidade_estoque` menor ou igual a `estoque_minimo`, ou com validade próxima, entra na consulta gerencial **G10**. Diferença entre o estoque registrado e entradas − usos é apontada pela auditoria **A14**.
**Índices:** apenas a PK `id_material`.

### ENTRADA_ESTOQUE

`ENTRADA_ESTOQUE = @id_entrada + id_material + data_entrada + quantidade + (fornecedor)`

**Leitura:** cada linha é uma compra de um material (ou o saldo inicial do inventário de 30/09/2026). O fornecedor é texto livre, porque a clínica compra tudo na mesma loja (a Dental, por contato com o vendedor, segundo a responsável) e não precisa de um cadastro de fornecedores.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_entrada | INT AUTO_INCREMENT | Sim (PK) | Sim | Inteiro positivo | Gerado pelo SGBD | Identificador da entrada. |
| id_material | INT | Sim (FK) | Não | Id existente em Material | — | Material comprado. |
| data_entrada | DATE | Sim | Não | Data válida | — | Data do recebimento. |
| quantidade | INT | Sim | Não | Maior que 0, na unidade de consumo do material | — | Quantidade recebida (RN51). |
| fornecedor | VARCHAR(100) | Não | Não | Texto | NULL | Distribuidor. O saldo inicial usa o texto "Saldo inicial (inventário)". |

**Restrições no script:** `pk_entrada`, `fk_entrada_material`, `ck_entrada_quantidade`.
**Regras:** toda entrada soma ao `quantidade_estoque` do material (RN51). Compras por mês e fornecedor aparecem na consulta gerencial **G20**.
**Índices:** PK `id_entrada` e o índice automático da FK `id_material`.

### PROCEDIMENTO_MATERIAL

`PROCEDIMENTO_MATERIAL = @id_procedimento + @id_material + quantidade_utilizada + data_utilizacao`

**Leitura:** a chave primária é composta por `id_procedimento` e `id_material`, ambos também chaves estrangeiras. A tabela resolve a relação muitos para muitos entre Procedimento e Material.

| Atributo | Tipo físico | Obrigatório | Único | Valores permitidos | Valor padrão | Significado |
|---|---|---|---|---|---|---|
| id_procedimento | INT | Sim (PK, FK) | Parte da chave primária | Id existente em Procedimento | — | Procedimento em que o material foi usado. |
| id_material | INT | Sim (PK, FK) | Parte da chave primária | Id existente em Material | — | Material utilizado. |
| quantidade_utilizada | INT | Sim | Não | Maior que 0, na unidade de consumo do material | — | Quantidade consumida (RN37). |
| data_utilizacao | DATE | Sim | Não | Data válida | — | Data do consumo. |

**Restrições no script:** `pk_procedimento_material`, `fk_pm_procedimento`, `fk_pm_material`, `ck_pm_quantidade`.
**Regras:** material com validade vencida não deve ser usado (RN40): conferido pela consulta de auditoria **A08**.
**Índices:** PK composta (`id_procedimento`, `id_material`) e o índice automático da FK `id_material`.

---

## 5. Log de acesso (metadado operacional)

O sistema mantém dois registros próprios de auditoria. **Acesso_prontuario** guarda quem consultou ou alterou cada prontuário (RN41). **Log_auditoria** guarda ações relevantes como cancelamentos, remarcações e confirmações de pagamento (RN32). Ambos são gravados pelo sistema. O banco não impede por si só alterar ou apagar esses registros: a imutabilidade depende de permissões de acesso, que não fazem parte do script desta versão.

Se o SGBD oferecer log de auditoria próprio (por exemplo, o log geral do MySQL), ele pode ser ativado como camada adicional. Retenção e rotação do log seguem política própria, independente da retenção dos dados de negócio.

---

## 6. Acesso por operação e conformidade com a LGPD (metadado administrativo)

O script implementa dois perfis (`recepcao` e `dentista`). A tabela abaixo é uma **premissa do projeto**, não confirmada com a clínica, e inclui papéis lógicos (Administração, Auditoria e Sistema) que não existem como perfil no banco.

| Tabela | Ler | Inserir | Atualizar | Apagar |
|---|---|---|---|---|
| Paciente | Recepção, Dentista, Auditoria | Recepção, Dentista | Recepção, Dentista | Nenhum papel (apenas anonimização ao fim da retenção) |
| Prontuario | Dentista, Auditoria | Dentista | Dentista | Nenhum papel |
| Dentista | Todos os papéis | Administração | Administração | Nenhum papel |
| Horario_atendimento | Todos os papéis | Administração | Administração | Nenhum papel |
| Usuario | Administração, Auditoria | Administração | Administração | Nenhum papel |
| Consulta | Recepção, Dentista (própria agenda), Auditoria | Recepção, Dentista | Recepção (agenda e status), Dentista (campos clínicos) | Nenhum papel (cancela-se por status) |
| Procedimento | Dentista, Recepção (parcial), Auditoria | Dentista | Dentista | Nenhum papel |
| Pagamento | Dentista, Recepção, Auditoria | Recepção, Dentista | Usuário autorizado, com registro em log (RN26 e RN28) | Nenhum papel |
| Material | Dentista, Administração | Administração | Administração, Dentista (estoque) | Nenhum papel |
| Entrada_estoque | Dentista, Administração, Auditoria | Administração | Nenhum papel | Nenhum papel |
| Procedimento_Material | Dentista, Administração, Auditoria | Dentista | Dentista | Nenhum papel |
| Acesso_prontuario | Auditoria | Sistema (automático) | Nenhum papel | Nenhum papel |
| Log_auditoria | Auditoria | Sistema (automático) | Nenhum papel | Nenhum papel |

Papéis: Recepção (funcionária de atendimento), Dentista, Administração (dentistas responsáveis pela gestão), Auditoria e Sistema (gravação automática).

**LGPD.** Paciente, Prontuario, Consulta (observações e diagnóstico) e Procedimento carregam dado pessoal sensível de saúde (LGPD, art. 5º, II). O tratamento se ampara na tutela da saúde (art. 11, II, "f") ou na execução do contrato de prestação do serviço, e a clínica registra o consentimento do paciente em `Paciente.data_consentimento_lgpd` antes do primeiro atendimento (RN46, auditoria A12). O acesso é restrito aos usuários com `acessa_prontuario = TRUE` (RN48, auditoria A13), e todo acesso a prontuário fica registrado (seção 5), o que sustenta o princípio de responsabilização (art. 6º, X). Os dados não são apagados fisicamente (RN22): o prontuário é guardado por no mínimo 20 anos após o último registro, conforme orientação do CFO (RN47). Encerrado esse prazo, os dados seriam anonimizados, preservando a estatística sem identificar o paciente. Dentista e Usuario são dados cadastrais comuns, sujeitos às mesmas regras gerais de acesso e registro.

---

## 7. Histórico de versões

| Versão | Mudanças |
|---|---|
| v1.0 | Primeira versão do dicionário. |
| v1.1 | Alinhado ao `script.sql`: tipos e tamanhos, obrigatoriedade, valores permitidos, valores padrão, restrições (CHECK e UNIQUE) e índices. Cardinalidades com mínimo e máximo dos dois lados. Consulta tratada como entidade comum. Triggers trocados por consultas de auditoria (A01, A02, A04, A05 e A08). |
| v1.2 | Correções da Entrega 1: Procedimento sempre ligado a uma consulta, sem `id_paciente` e `id_dentista` (3FN); status `confirmada` e `falta` em Consulta; `data_consentimento_lgpd` em Paciente; `acessa_prontuario` em Usuario; nova tabela Entrada_estoque; materiais na unidade de consumo; novas auditorias A12, A13 e A14. |
