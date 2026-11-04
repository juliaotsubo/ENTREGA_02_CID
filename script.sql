-- =====================================================================
-- E.K. Consultório Odontológico — Entrega 2
-- Script SQL completo para MySQL 8.0.16 ou superior (por causa dos CHECK)
--
-- Como executar (banco vazio):
--   mysql -u root -p --default-character-set=utf8mb4 < docs/script.sql
--   ou abrir o arquivo no MySQL Workbench e executar tudo (Ctrl+Shift+Enter)
--
-- Conteúdo, nesta ordem:
--   1. CREATE DATABASE        2. CREATE TABLE e constraints
--   3. INSERT INTO (massa de dados FICTÍCIA)
--   4. SELECT com JOIN        5. UPDATE        6. DELETE
--   7. Consultas gerenciais (G01 a G20)
--   8. Consultas de auditoria (A01 a A14)
--
-- Volume da massa de dados (justificativa):
--   A clínica tem 3 cirurgiãs-dentistas e 1 funcionária de atendimento e
--   atende de segunda a sábado, fechando em feriados nacionais. Na
--   entrevista de 02/11/2026 a clínica informou cerca de 30 pacientes
--   cadastrados (contando os que já terminaram o tratamento), dos quais
--   7 a 8 retornam com frequência. A massa tem exatamente 30 pacientes.
--   Outubro de 2026 tem 26 dias de atendimento (sem o feriado de 12/10).
--   A massa de outubro tem 68 consultas marcadas: 57 realizadas (média de
--   2,2 por dia), 6 canceladas e 5 faltas, o que dá cerca de 2 consultas
--   por paciente no mês (tratamentos em andamento têm várias sessões).
--   O "5 a 9 pacientes por dia" da Entrega 1 era a capacidade informada
--   na época; a entrevista de 02/11 corrigiu o volume real.
--   Em novembro, 03/11 já foi atendido (1 realizada, 1 falta, 1 cancelada)
--   e há 18 consultas futuras (6 confirmadas e 12 agendadas). O feriado
--   de Finados (02/11) não tem atendimento. Um paciente (id 20) não tem
--   consulta no período, de propósito.
--   Materiais: estoque e uso na unidade de consumo (par, unidade, tubete,
--   grama, mL). O estoque de 30/09 entra como "saldo inicial" e as
--   compras de outubro, com fornecedor, em Entrada_estoque.
--   Formas de pagamento: a clínica informou aceitar dinheiro e cartão,
--   com parcelamento em até 3 vezes (na massa, todo pagamento
--   dividido em parcelas usa cartão de crédito). O motivo do cancelamento não é
--   registrado pela clínica, então a coluna fica vazia na massa.
--   A clínica atende crianças a partir de 8 anos. As datas de nascimento
--   da massa foram revisadas para respeitar essa idade mínima.
--   Os 3 dentistas são de Clínica geral. Conforme a entrevista, só 2
--   dentistas acessam prontuários: os usuários 2 (dentista 1) e 3
--   (dentista 2), marcados com acessa_prontuario = TRUE. O usuário 4
--   (dentista 3) não tem acesso; o diagnóstico das consultas dela é
--   transcrito pela dentista 1 ou 2 (RN48). Acesso_prontuario tem 82
--   registros, todos dos usuários 2 e 3.
--   Todos os dados são fictícios (nomes, CPFs, telefones, e-mails).
--   Valores de referência da clínica: profilaxia R$ 250 e restauração
--   entre R$ 300 e R$ 350. Os demais valores são fictícios.
--
-- Casos de teste de auditoria plantados na massa (de propósito):
--   A01: duas consultas sobrepostas do mesmo dentista em 09/11/2026
--   A05: um procedimento com pagamentos acima do valor cobrado
--   A08: um procedimento que usou material com validade vencida
--   A12: um paciente (id 7) atendido sem consentimento LGPD registrado
--   A14: luva descartável com 4 pares a menos no inventário (perda)
--   Todas as demais auditorias devem retornar zero linhas.
-- =====================================================================



-- ---------------------------------------------------------------------
-- 1. CREATE DATABASE
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS ek_consultorio;
CREATE DATABASE ek_consultorio
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE ek_consultorio;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 2. CREATE TABLE (com constraints)
-- Ordem: primeiro as tabelas que não dependem de outras.
-- Nenhuma FK usa ON DELETE CASCADE: registros não são apagados em
-- cascata (RN22). O padrão do MySQL (RESTRICT) impede a exclusão de um
-- registro que ainda é referenciado.
-- ---------------------------------------------------------------------

-- Paciente -------------------------------------------------------------
CREATE TABLE Paciente (
    id_paciente      INT          NOT NULL AUTO_INCREMENT,
    nome_completo    VARCHAR(100) NOT NULL,                  -- RN02
    data_nascimento  DATE         NOT NULL,                  -- RN02
    cpf              CHAR(11)     NULL,                      -- RN02 (quando disponível), RN03 (único)
    email            VARCHAR(100) NULL,
    telefone         VARCHAR(15)  NULL,
    logradouro       VARCHAR(100) NULL,
    numero           VARCHAR(10)  NULL,
    complemento      VARCHAR(50)  NULL,
    bairro           VARCHAR(60)  NULL,
    cidade           VARCHAR(60)  NULL,
    uf               CHAR(2)      NULL,
    cep              CHAR(8)      NULL,
    data_consentimento_lgpd DATE  NULL,                      -- RN46 (vazio até o paciente assinar)
    CONSTRAINT pk_paciente PRIMARY KEY (id_paciente),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf),
    CONSTRAINT ck_paciente_cpf CHECK (cpf IS NULL OR CHAR_LENGTH(cpf) = 11)
);

-- Dentista -------------------------------------------------------------
CREATE TABLE Dentista (
    id_dentista      INT          NOT NULL AUTO_INCREMENT,
    nome_completo    VARCHAR(100) NOT NULL,                  -- RN04
    cpf              CHAR(11)     NOT NULL,                  -- RN04 (obrigatório e único)
    cro              VARCHAR(15)  NOT NULL,                  -- RN04 (obrigatório e único)
    telefone         VARCHAR(15)  NULL,
    email            VARCHAR(100) NULL,
    especialidade    VARCHAR(60)  NULL,
    CONSTRAINT pk_dentista PRIMARY KEY (id_dentista),
    CONSTRAINT uq_dentista_cpf UNIQUE (cpf),
    CONSTRAINT uq_dentista_cro UNIQUE (cro),
    CONSTRAINT ck_dentista_cpf CHECK (CHAR_LENGTH(cpf) = 11)
);

-- Horario_atendimento ----------------------------------------------------
CREATE TABLE Horario_atendimento (
    id_horario       INT      NOT NULL AUTO_INCREMENT,
    id_dentista      INT      NOT NULL,                      -- RN42
    dia_semana       INT      NOT NULL,                      -- 1 = segunda ... 7 = domingo
    hora_inicio      TIME     NOT NULL,
    hora_fim         TIME     NOT NULL,
    CONSTRAINT pk_horario PRIMARY KEY (id_horario),
    CONSTRAINT fk_horario_dentista FOREIGN KEY (id_dentista) REFERENCES Dentista (id_dentista),
    CONSTRAINT uq_horario UNIQUE (id_dentista, dia_semana, hora_inicio),
    CONSTRAINT ck_horario_dia CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_horario_intervalo CHECK (hora_inicio < hora_fim)   -- RN42
);

-- Usuario ----------------------------------------------------------------
CREATE TABLE Usuario (
    id_usuario       INT          NOT NULL AUTO_INCREMENT,
    id_dentista      INT          NULL,                      -- recepção não tem dentista
    nome_usuario     VARCHAR(60)  NOT NULL,                  -- RN06
    login            VARCHAR(40)  NOT NULL,                  -- RN06, RN29 (individual)
    senha_hash       VARCHAR(255) NOT NULL,                  -- RN31 (nunca texto puro)
    perfil_acesso    VARCHAR(20)  NOT NULL,                  -- RN07
    acessa_prontuario BOOLEAN     NOT NULL DEFAULT FALSE,    -- RN48
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT fk_usuario_dentista FOREIGN KEY (id_dentista) REFERENCES Dentista (id_dentista),
    CONSTRAINT uq_usuario_login UNIQUE (login),
    CONSTRAINT uq_usuario_dentista UNIQUE (id_dentista),     -- um dentista, uma conta
    CONSTRAINT ck_usuario_perfil CHECK (perfil_acesso IN ('recepcao', 'dentista')),
    CONSTRAINT ck_usuario_perfil_dentista CHECK (perfil_acesso <> 'dentista' OR id_dentista IS NOT NULL)
);

-- Log_auditoria ----------------------------------------------------------
CREATE TABLE Log_auditoria (
    id_log           INT          NOT NULL AUTO_INCREMENT,
    id_usuario       INT          NOT NULL,                  -- RN33
    data_hora        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- RN32
    tipo_acao        VARCHAR(40)  NOT NULL,                  -- RN32
    descricao        VARCHAR(255) NULL,
    CONSTRAINT pk_log PRIMARY KEY (id_log),
    CONSTRAINT fk_log_usuario FOREIGN KEY (id_usuario) REFERENCES Usuario (id_usuario)
);

-- Prontuario -------------------------------------------------------------
CREATE TABLE Prontuario (
    id_prontuario    INT          NOT NULL AUTO_INCREMENT,
    id_paciente      INT          NOT NULL,                  -- RN05
    data_criacao     DATE         NOT NULL,
    observacoes_gerais TEXT       NULL,
    CONSTRAINT pk_prontuario PRIMARY KEY (id_prontuario),
    CONSTRAINT fk_prontuario_paciente FOREIGN KEY (id_paciente) REFERENCES Paciente (id_paciente),
    CONSTRAINT uq_prontuario_paciente UNIQUE (id_paciente)   -- RN05: um prontuário por paciente
);

-- Acesso_prontuario ------------------------------------------------------
CREATE TABLE Acesso_prontuario (
    id_acesso        INT          NOT NULL AUTO_INCREMENT,
    id_usuario       INT          NOT NULL,                  -- RN41
    id_prontuario    INT          NOT NULL,                  -- RN41
    data_acesso      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_acesso      VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_acesso PRIMARY KEY (id_acesso),
    CONSTRAINT fk_acesso_usuario FOREIGN KEY (id_usuario) REFERENCES Usuario (id_usuario),
    CONSTRAINT fk_acesso_prontuario FOREIGN KEY (id_prontuario) REFERENCES Prontuario (id_prontuario),
    CONSTRAINT ck_acesso_tipo CHECK (tipo_acesso IN ('consulta', 'alteracao'))
);

-- Consulta ---------------------------------------------------------------
CREATE TABLE Consulta (
    id_consulta         INT          NOT NULL AUTO_INCREMENT,
    id_paciente         INT          NOT NULL,               -- RN08
    id_dentista         INT          NOT NULL,               -- RN08
    data_consulta       DATE         NOT NULL,               -- RN08
    hora_consulta       TIME         NOT NULL,               -- RN08
    duracao_prevista    INT          NOT NULL,               -- RN08 (minutos)
    tipo_consulta       VARCHAR(40)  NULL,
    motivo              VARCHAR(255) NULL,
    status              VARCHAR(15)  NOT NULL DEFAULT 'agendada',   -- RN11, RN49, RN50
    observacoes         TEXT         NULL,                   -- RN17
    diagnostico         TEXT         NULL,                   -- RN17
    motivo_cancelamento VARCHAR(255) NULL,                   -- RN12
    CONSTRAINT pk_consulta PRIMARY KEY (id_consulta),
    CONSTRAINT fk_consulta_paciente FOREIGN KEY (id_paciente) REFERENCES Paciente (id_paciente),
    CONSTRAINT fk_consulta_dentista FOREIGN KEY (id_dentista) REFERENCES Dentista (id_dentista),
    CONSTRAINT ck_consulta_duracao CHECK (duracao_prevista > 0),
    CONSTRAINT ck_consulta_status CHECK (status IN ('agendada', 'confirmada', 'realizada', 'cancelada', 'falta'))
);
-- Obs.: não há UNIQUE em (dentista, data, hora) porque a consulta cancelada
-- permanece no histórico (RN12) e o horário pode ser reutilizado (RN13).
-- A sobreposição de horários (RN10) é conferida na consulta de auditoria.

-- Procedimento -----------------------------------------------------------
-- Todo procedimento é feito durante uma consulta (RN19). Paciente e
-- dentista vêm da consulta, por isso não são repetidos aqui (3FN).
CREATE TABLE Procedimento (
    id_procedimento     INT           NOT NULL AUTO_INCREMENT,
    id_consulta         INT           NOT NULL,              -- RN19
    nome_procedimento   VARCHAR(100)  NOT NULL,              -- RN18
    data_procedimento   DATE          NOT NULL,              -- RN18
    descricao           TEXT          NULL,
    valor_cobrado       DECIMAL(10,2) NULL,                  -- RN18
    CONSTRAINT pk_procedimento PRIMARY KEY (id_procedimento),
    CONSTRAINT fk_procedimento_consulta FOREIGN KEY (id_consulta) REFERENCES Consulta (id_consulta),
    CONSTRAINT ck_procedimento_valor CHECK (valor_cobrado IS NULL OR valor_cobrado >= 0)
);

-- Pagamento --------------------------------------------------------------
CREATE TABLE Pagamento (
    id_pagamento        INT           NOT NULL AUTO_INCREMENT,
    id_procedimento     INT           NOT NULL,              -- RN24
    valor               DECIMAL(10,2) NOT NULL,              -- RN23
    data_pagamento      DATE          NULL,                  -- vazio enquanto pendente
    forma_pagamento     VARCHAR(30)   NOT NULL,              -- RN23
    status_pagamento    VARCHAR(10)   NOT NULL DEFAULT 'pendente',   -- RN26
    CONSTRAINT pk_pagamento PRIMARY KEY (id_pagamento),
    CONSTRAINT fk_pagamento_procedimento FOREIGN KEY (id_procedimento) REFERENCES Procedimento (id_procedimento),
    CONSTRAINT ck_pagamento_valor CHECK (valor > 0),
    CONSTRAINT ck_pagamento_status CHECK (status_pagamento IN ('pendente', 'pago')),
    CONSTRAINT ck_pagamento_data CHECK (status_pagamento = 'pendente' OR data_pagamento IS NOT NULL)   -- RN26, RN27
);

-- Material ---------------------------------------------------------------
CREATE TABLE Material (
    id_material         INT          NOT NULL AUTO_INCREMENT,
    nome_material       VARCHAR(100) NOT NULL,               -- RN36
    unidade             VARCHAR(20)  NOT NULL,               -- RN36
    quantidade_estoque  INT          NOT NULL DEFAULT 0,     -- RN36
    estoque_minimo      INT          NOT NULL DEFAULT 0,     -- RN36, RN39
    data_validade       DATE         NULL,                   -- RN36, RN40
    CONSTRAINT pk_material PRIMARY KEY (id_material),
    CONSTRAINT ck_material_estoque CHECK (quantidade_estoque >= 0),
    CONSTRAINT ck_material_minimo CHECK (estoque_minimo >= 0)
);
-- Quantidades na unidade de consumo (par, unidade, tubete, grama, mL).

-- Entrada_estoque ----------------------------------------------------------
-- Compras de material (e o saldo inicial do inventário de 30/09). O estoque
-- de Material deve ser igual a entradas − usos (RN51, conferido na A14).
CREATE TABLE Entrada_estoque (
    id_entrada          INT          NOT NULL AUTO_INCREMENT,
    id_material         INT          NOT NULL,               -- RN51
    data_entrada        DATE         NOT NULL,               -- RN51
    quantidade          INT          NOT NULL,               -- RN51
    fornecedor          VARCHAR(100) NULL,
    CONSTRAINT pk_entrada PRIMARY KEY (id_entrada),
    CONSTRAINT fk_entrada_material FOREIGN KEY (id_material) REFERENCES Material (id_material),
    CONSTRAINT ck_entrada_quantidade CHECK (quantidade > 0)
);

-- Procedimento_Material (entidade associativa Utiliza) -------------------
CREATE TABLE Procedimento_Material (
    id_procedimento     INT  NOT NULL,
    id_material         INT  NOT NULL,
    quantidade_utilizada INT NOT NULL,                       -- RN37
    data_utilizacao     DATE NOT NULL,                       -- RN37
    CONSTRAINT pk_procedimento_material PRIMARY KEY (id_procedimento, id_material),
    CONSTRAINT fk_pm_procedimento FOREIGN KEY (id_procedimento) REFERENCES Procedimento (id_procedimento),
    CONSTRAINT fk_pm_material FOREIGN KEY (id_material) REFERENCES Material (id_material),
    CONSTRAINT ck_pm_quantidade CHECK (quantidade_utilizada > 0)
);



-- ---------------------------------------------------------------------
-- 3. INSERT INTO — massa de dados fictícia
-- ---------------------------------------------------------------------

INSERT INTO Paciente (id_paciente, nome_completo, data_nascimento, cpf, email, telefone, logradouro, numero, complemento, bairro, cidade, uf, cep, data_consentimento_lgpd) VALUES
(1, 'Daniel Carvalho Santos', '2004-12-03', '99900000001', 'daniel.carvalho.santos@exemplo.com', '11900002327', 'Rua do Sol', '997', NULL, 'Jardim Bonfiglioli', 'São Paulo', 'SP', '05095396', '2026-03-10'),
(2, 'Carla Silva Fernandes', '2015-09-11', '99900000002', NULL, '11900001784', 'Rua São Jorge', '347', NULL, 'Jaguaré', 'São Paulo', 'SP', '05191909', '2026-02-26'),
(3, 'Priscila Silva Costa', '1982-06-02', '99900000003', 'priscila.silva.costa@exemplo.com', '11900006692', 'Avenida Central', '59', NULL, 'Jardim Bonfiglioli', 'São Paulo', 'SP', '05465815', '2026-07-21'),
(4, 'Débora Rocha Correia', '1979-09-08', '99900000004', 'debora.rocha.correia@exemplo.com', '11900009059', 'Rua do Sol', '513', NULL, 'Butantã', 'São Paulo', 'SP', '05723838', '2026-04-14'),
(5, 'Eduarda Cunha Moreira', '1971-03-07', '99900000005', 'eduarda.cunha.moreira@exemplo.com', '11900003522', 'Avenida Central', '47', 'Bloco B', 'Vila Leopoldina', 'São Paulo', 'SP', '05550376', '2026-09-08'),
(6, 'Fábio Moreira Barros', '2001-07-31', '99900000006', NULL, '11900005300', 'Rua das Acácias', '587', NULL, 'Pinheiros', 'São Paulo', 'SP', '05492819', '2026-01-24'),
(7, 'Otávio Costa Dias', '2011-05-03', '99900000007', NULL, '11900008915', 'Rua Boa Vista', '138', NULL, 'Vila Sônia', 'São Paulo', 'SP', '05530514', NULL),
(8, 'Vanessa Teixeira Ribeiro', '2012-11-22', '99900000008', NULL, '11900007893', 'Travessa da Paz', '536', 'Apto 12', 'Raposo Tavares', 'São Paulo', 'SP', '05306716', '2026-05-30'),
(9, 'Lucas Souza Rocha', '1944-08-01', '99900000009', 'lucas.souza.rocha@exemplo.com', '11900000060', 'Rua Boa Vista', '332', 'Fundos', 'Cidade Universitária', 'São Paulo', 'SP', '05993348', '2026-03-19'),
(10, 'Thiago Correia Martins', '1992-03-30', '99900000010', 'thiago.correia.martins@exemplo.com', '11900008022', 'Avenida Central', '168', 'Apto 83', 'Butantã', 'São Paulo', 'SP', '05030645', '2026-02-15'),
(11, 'Gustavo Nunes Santos', '2008-02-06', '99900000011', NULL, '11900001203', 'Avenida das Palmeiras', '675', NULL, 'Cidade Universitária', 'São Paulo', 'SP', '05881744', '2026-02-25'),
(12, 'Débora Alves Barros', '1991-09-01', '99900000012', NULL, '11900006271', 'Rua Girassol', '87', NULL, 'Morumbi', 'São Paulo', 'SP', '05859667', '2026-02-01'),
(13, 'Débora Silva Costa', '1999-10-07', '99900000013', NULL, '11900005933', 'Avenida das Palmeiras', '48', NULL, 'Vila Leopoldina', 'São Paulo', 'SP', '05825461', '2026-07-19'),
(14, 'Juliana Correia Ribeiro', '2013-05-23', '99900000014', NULL, '11900000591', 'Avenida das Palmeiras', '183', NULL, 'Raposo Tavares', 'São Paulo', 'SP', '05593963', '2026-02-24'),
(15, 'Sérgio Mendes Souza', '1951-01-30', '99900000015', 'sergio.mendes.souza@exemplo.com', '11900002612', 'Avenida Central', '827', 'Bloco B', 'Rio Pequeno', 'São Paulo', 'SP', '05507161', '2026-05-02'),
(16, 'Sabrina Moreira Carvalho', '1992-01-11', '99900000016', NULL, '11900006318', 'Travessa da Paz', '463', NULL, 'Cidade Universitária', 'São Paulo', 'SP', '05906840', '2026-02-14'),
(17, 'Eduardo Correia Cunha', '2007-07-17', NULL, NULL, '11900005128', 'Rua do Sol', '724', NULL, 'Pinheiros', 'São Paulo', 'SP', '05328409', '2026-06-15'),
(18, 'Beatriz Ribeiro Teixeira', '1946-01-23', '99900000018', NULL, '11900002608', 'Alameda dos Pinheiros', '181', 'Bloco B', 'Raposo Tavares', 'São Paulo', 'SP', '05362387', '2026-02-06'),
(19, 'Lucas Lima Oliveira', '1956-10-13', '99900000019', NULL, '11900002451', 'Rua São Jorge', '597', NULL, 'Raposo Tavares', 'São Paulo', 'SP', '05308925', '2026-06-21'),
(20, 'Leonardo Santos Ribeiro', '1987-08-14', '99900000020', 'leonardo.santos.ribeiro@exemplo.com', '11900007061', 'Rua Boa Vista', '610', NULL, 'Pinheiros', 'São Paulo', 'SP', '05804967', '2026-10-13'),
(21, 'Eduarda Martins Pereira', '1986-03-14', '99900000021', 'eduarda.martins.pereira@exemplo.com', '11900008796', 'Travessa da Paz', '683', NULL, 'Butantã', 'São Paulo', 'SP', '05440402', '2026-03-10'),
(22, 'Marcelo Costa Barros', '2017-08-28', '99900000022', NULL, '11900005907', 'Rua dos Ipês', '271', NULL, 'Vila Leopoldina', 'São Paulo', 'SP', '05250131', '2026-08-10'),
(23, 'Daniela Alves Araújo', '1952-02-01', '99900000023', 'daniela.alves.araujo@exemplo.com', '11900009840', 'Rua Boa Vista', '62', NULL, 'Butantã', 'São Paulo', 'SP', '05242527', '2026-03-17'),
(24, 'Elaine Souza Freitas', '1958-02-22', NULL, 'elaine.souza.freitas@exemplo.com', '11900000171', 'Alameda dos Pinheiros', '916', 'Fundos', 'Rio Pequeno', 'São Paulo', 'SP', '05741166', '2026-09-02'),
(25, 'Giovana Teixeira Rocha', '1978-04-01', '99900000025', 'giovana.teixeira.rocha@exemplo.com', '11900003456', 'Rua das Acácias', '357', NULL, 'Rio Pequeno', 'São Paulo', 'SP', '05147814', '2026-10-17'),
(26, 'Sabrina Ramos Almeida', '1992-08-11', '99900000026', 'sabrina.ramos.almeida@exemplo.com', '11900006526', 'Travessa da Paz', '408', NULL, 'Vila Leopoldina', 'São Paulo', 'SP', '05530659', '2026-10-10'),
(27, 'Paulo Nascimento Mendes', '1998-12-01', '99900000027', 'paulo.nascimento.mendes@exemplo.com', '11900001150', 'Rua Boa Vista', '589', NULL, 'Jaguaré', 'São Paulo', 'SP', '05605859', '2026-05-04'),
(28, 'Larissa Pereira Lima', '1971-03-09', '99900000028', 'larissa.pereira.lima@exemplo.com', '11900002357', 'Rua dos Ipês', '576', NULL, 'Cidade Universitária', 'São Paulo', 'SP', '05824890', '2026-07-10'),
(29, 'Sérgio Costa Teixeira', '1992-08-02', '99900000029', 'sergio.costa.teixeira@exemplo.com', '11900008654', 'Rua do Sol', '220', NULL, 'Raposo Tavares', 'São Paulo', 'SP', '05192820', '2026-07-11'),
(30, 'Ana Oliveira Moreira', '1979-12-02', '99900000030', 'ana.oliveira.moreira@exemplo.com', '11900003274', 'Avenida Central', '950', NULL, 'Jaguaré', 'São Paulo', 'SP', '05762117', '2026-08-02');

INSERT INTO Dentista (id_dentista, nome_completo, cpf, cro, telefone, email, especialidade) VALUES
(1, 'Helena Duarte Lima', '99800000001', 'SP-100001', '11900000001', 'helena.duarte@exemplo.com', 'Clínica geral'),
(2, 'Marcos Tavares Prado', '99800000002', 'SP-100002', '11900000002', 'marcos.tavares@exemplo.com', 'Clínica geral'),
(3, 'Beatriz Nogueira Faria', '99800000003', 'SP-100003', '11900000003', 'beatriz.nogueira@exemplo.com', 'Clínica geral');

INSERT INTO Horario_atendimento (id_horario, id_dentista, dia_semana, hora_inicio, hora_fim) VALUES
(1, 1, 1, '08:00:00', '12:00:00'),
(2, 1, 1, '14:00:00', '18:00:00'),
(3, 1, 3, '08:00:00', '12:00:00'),
(4, 1, 3, '14:00:00', '18:00:00'),
(5, 1, 5, '08:00:00', '12:00:00'),
(6, 1, 5, '14:00:00', '18:00:00'),
(7, 2, 2, '08:00:00', '12:00:00'),
(8, 2, 2, '14:00:00', '18:00:00'),
(9, 2, 4, '08:00:00', '12:00:00'),
(10, 2, 4, '14:00:00', '18:00:00'),
(11, 2, 6, '08:00:00', '12:00:00'),
(12, 3, 1, '08:00:00', '12:00:00'),
(13, 3, 4, '14:00:00', '18:00:00'),
(14, 3, 6, '08:00:00', '12:00:00');

INSERT INTO Usuario (id_usuario, id_dentista, nome_usuario, login, senha_hash, perfil_acesso, acessa_prontuario) VALUES
(1, NULL, 'Atendimento Recepção', 'recepcao', 'b3df2e1c7ae36062c160b923f345b81f012b110f0d91a6a2b408881b955acff8', 'recepcao', FALSE),
(2, 1, 'Helena Duarte Lima', 'helena.duarte', '06ecb4c08a989cc5150da5abcf27c3cf9e3e8ce57903ea0be01fca156cd7e848', 'dentista', TRUE),
(3, 2, 'Marcos Tavares Prado', 'marcos.tavares', '1904e98cb4b089bf2586d148f3fd1f1adebe5d891bcfba867d6e65750d57bc34', 'dentista', TRUE),
(4, 3, 'Beatriz Nogueira Faria', 'beatriz.nogueira', 'ef77338994e270a96ca587faa7c9e8f53d9e634aca73990b0b198eb9303bfe6e', 'dentista', FALSE);

INSERT INTO Prontuario (id_prontuario, id_paciente, data_criacao, observacoes_gerais) VALUES
(1, 1, '2026-03-10', 'Hipertensão controlada.'),
(2, 2, '2026-02-26', 'Sem alergias conhecidas.'),
(3, 3, '2026-07-21', 'Alergia relatada a penicilina.'),
(4, 4, '2026-04-14', 'Alergia relatada a penicilina.'),
(5, 5, '2026-09-08', NULL),
(6, 6, '2026-01-24', 'Usa aparelho ortodôntico.'),
(7, 7, '2026-05-31', 'Hipertensão controlada.'),
(8, 8, '2026-05-30', NULL),
(9, 9, '2026-03-19', NULL),
(10, 10, '2026-02-15', 'Sem alergias conhecidas.'),
(11, 11, '2026-02-25', 'Alergia relatada a penicilina.'),
(12, 12, '2026-02-01', 'Usa aparelho ortodôntico.'),
(13, 13, '2026-07-19', NULL),
(14, 14, '2026-02-24', 'Alergia relatada a penicilina.'),
(15, 15, '2026-05-02', 'Alergia relatada a penicilina.'),
(16, 16, '2026-02-14', 'Hipertensão controlada.'),
(17, 17, '2026-06-15', 'Hipertensão controlada.'),
(18, 18, '2026-02-06', 'Alergia relatada a penicilina.'),
(19, 19, '2026-06-21', NULL),
(20, 20, '2026-10-13', 'Hipertensão controlada.'),
(21, 21, '2026-03-10', NULL),
(22, 22, '2026-08-10', 'Sem alergias conhecidas.'),
(23, 23, '2026-03-17', 'Alergia relatada a penicilina.'),
(24, 24, '2026-09-02', 'Usa aparelho ortodôntico.'),
(25, 25, '2026-10-17', 'Usa aparelho ortodôntico.'),
(26, 26, '2026-10-10', NULL),
(27, 27, '2026-05-04', NULL),
(28, 28, '2026-07-10', 'Sem alergias conhecidas.'),
(29, 29, '2026-07-11', NULL),
(30, 30, '2026-08-02', NULL);

INSERT INTO Material (id_material, nome_material, unidade, quantidade_estoque, estoque_minimo, data_validade) VALUES
(1, 'Luva descartável', 'par', 56, 40, '2027-08-31'),
(2, 'Máscara descartável', 'unidade', 15, 20, '2027-05-30'),
(3, 'Resina composta', 'grama', 10, 6, '2027-03-15'),
(4, 'Anestésico (tubete)', 'tubete', 8, 15, '2026-12-20'),
(5, 'Gaze estéril', 'unidade', 12, 10, '2026-10-10'),
(6, 'Pasta profilática', 'grama', 45, 30, '2027-02-28'),
(7, 'Flúor gel', 'mL', 18, 25, '2027-01-31'),
(8, 'Fio de sutura', 'unidade', 6, 3, '2028-01-31'),
(9, 'Cimento ionômero', 'grama', 7, 3, '2027-06-30'),
(10, 'Sugador descartável', 'unidade', 35, 20, '2028-03-31'),
(11, 'Lençol de borracha', 'unidade', 5, 2, '2029-01-31'),
(12, 'Ácido condicionador', 'mL', 9, 5, '2026-12-10');

INSERT INTO Entrada_estoque (id_entrada, id_material, data_entrada, quantidade, fornecedor) VALUES
(1, 1, '2026-09-30', 75, 'Saldo inicial (inventário)'),
(2, 1, '2026-10-15', 60, 'Dental (loja de materiais odontológicos)'),
(3, 2, '2026-09-30', 8, 'Saldo inicial (inventário)'),
(4, 2, '2026-10-15', 30, 'Dental (loja de materiais odontológicos)'),
(5, 3, '2026-09-30', 11, 'Saldo inicial (inventário)'),
(6, 3, '2026-10-15', 10, 'Dental (loja de materiais odontológicos)'),
(7, 4, '2026-09-30', 15, 'Saldo inicial (inventário)'),
(8, 4, '2026-10-15', 20, 'Dental (loja de materiais odontológicos)'),
(9, 5, '2026-09-30', 30, 'Saldo inicial (inventário)'),
(10, 6, '2026-09-30', 60, 'Saldo inicial (inventário)'),
(11, 6, '2026-10-15', 60, 'Dental (loja de materiais odontológicos)'),
(12, 7, '2026-09-30', 34, 'Saldo inicial (inventário)'),
(13, 8, '2026-09-30', 13, 'Saldo inicial (inventário)'),
(14, 9, '2026-09-30', 10, 'Saldo inicial (inventário)'),
(15, 10, '2026-09-30', 26, 'Saldo inicial (inventário)'),
(16, 10, '2026-10-15', 40, 'Dental (loja de materiais odontológicos)'),
(17, 11, '2026-09-30', 8, 'Saldo inicial (inventário)'),
(18, 12, '2026-09-30', 10, 'Saldo inicial (inventário)'),
(19, 12, '2026-10-15', 10, 'Dental (loja de materiais odontológicos)');

INSERT INTO Consulta (id_consulta, id_paciente, id_dentista, data_consulta, hora_consulta, duracao_prevista, tipo_consulta, motivo, status, observacoes, diagnostico, motivo_cancelamento) VALUES
(1, 7, 2, '2026-10-01', '09:00:00', 60, 'avaliacao', 'Avaliação inicial', 'realizada', 'Retorno agendado conforme plano.', 'Dente com fratura coronária', NULL),
(2, 19, 2, '2026-10-01', '14:00:00', 30, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Sem queixas no momento.', NULL, NULL),
(3, 30, 3, '2026-10-01', '14:00:00', 60, 'retorno', 'Retorno de tratamento', 'falta', NULL, NULL, NULL),
(4, 6, 2, '2026-10-01', '16:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Paciente colaborativo, sem intercorrências.', NULL, NULL),
(5, 28, 1, '2026-10-02', '11:00:00', 30, 'retorno', 'Retorno de tratamento', 'realizada', 'Sem queixas no momento.', NULL, NULL),
(6, 13, 1, '2026-10-02', '14:00:00', 60, 'urgencia', 'Inchaço na gengiva', 'realizada', NULL, 'Dente com fratura coronária', NULL),
(7, 12, 1, '2026-10-02', '16:00:00', 60, 'manutencao', 'Controle periódico', 'realizada', 'Paciente relatou sensibilidade ao frio.', NULL, NULL),
(8, 11, 3, '2026-10-03', '08:00:00', 30, 'avaliacao', 'Dor de dente', 'falta', NULL, NULL, NULL),
(9, 12, 2, '2026-10-03', '09:00:00', 60, 'avaliacao', 'Avaliação para tratamento', 'realizada', 'Retorno agendado conforme plano.', 'Necessidade de restauração', NULL),
(10, 11, 1, '2026-10-05', '08:00:00', 60, 'avaliacao', 'Avaliação inicial', 'realizada', 'Retorno agendado conforme plano.', 'Placa bacteriana e cálculo', NULL),
(11, 5, 1, '2026-10-05', '10:00:00', 60, 'avaliacao', 'Dor de dente', 'realizada', 'Sem queixas no momento.', 'Dente com fratura coronária', NULL),
(12, 12, 3, '2026-10-05', '10:00:00', 60, 'manutencao', 'Controle periódico', 'cancelada', NULL, NULL, NULL),
(13, 19, 2, '2026-10-06', '11:00:00', 60, 'avaliacao', 'Check-up geral', 'cancelada', NULL, NULL, NULL),
(14, 28, 2, '2026-10-06', '16:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Retorno agendado conforme plano.', NULL, NULL),
(15, 4, 1, '2026-10-07', '11:00:00', 30, 'manutencao', 'Manutenção preventiva', 'realizada', 'Orientada higiene bucal e uso de fio dental.', NULL, NULL),
(16, 22, 1, '2026-10-07', '15:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Paciente colaborativo, sem intercorrências.', 'Sem alterações relevantes', NULL),
(17, 8, 1, '2026-10-07', '16:00:00', 60, 'urgencia', 'Inchaço na gengiva', 'realizada', 'Paciente colaborativo, sem intercorrências.', 'Cárie em dente posterior', NULL),
(18, 29, 3, '2026-10-08', '17:00:00', 60, 'avaliacao', 'Avaliação para tratamento', 'falta', NULL, NULL, NULL),
(19, 8, 1, '2026-10-09', '09:00:00', 60, 'avaliacao', 'Avaliação inicial', 'cancelada', NULL, NULL, NULL),
(20, 27, 1, '2026-10-09', '15:00:00', 60, 'retorno', 'Retorno de tratamento', 'realizada', 'Sem queixas no momento.', 'Necessidade de restauração', NULL),
(21, 1, 2, '2026-10-10', '09:00:00', 30, 'avaliacao', 'Avaliação para tratamento', 'realizada', NULL, 'Placa bacteriana e cálculo', NULL),
(22, 21, 3, '2026-10-10', '10:00:00', 60, 'manutencao', 'Controle periódico', 'realizada', 'Paciente relatou sensibilidade ao frio.', NULL, NULL),
(23, 2, 3, '2026-10-10', '11:00:00', 60, 'urgencia', 'Dente fraturado', 'falta', NULL, NULL, NULL),
(24, 16, 1, '2026-10-14', '17:00:00', 60, 'manutencao', 'Controle periódico', 'realizada', 'Retorno agendado conforme plano.', NULL, NULL),
(25, 8, 2, '2026-10-13', '10:00:00', 60, 'avaliacao', 'Check-up geral', 'realizada', 'Retorno agendado conforme plano.', 'Dente com fratura coronária', NULL),
(26, 11, 2, '2026-10-13', '14:00:00', 60, 'retorno', 'Retorno de tratamento', 'realizada', 'Paciente relatou sensibilidade ao frio.', NULL, NULL),
(27, 29, 2, '2026-10-13', '15:00:00', 60, 'urgencia', 'Dente fraturado', 'realizada', 'Paciente colaborativo, sem intercorrências.', 'Dente com fratura coronária', NULL),
(28, 27, 2, '2026-10-13', '16:00:00', 60, 'avaliacao', 'Avaliação para tratamento', 'realizada', 'Sem queixas no momento.', 'Sem alterações relevantes', NULL),
(29, 18, 1, '2026-10-14', '10:00:00', 60, 'urgencia', 'Dente fraturado', 'realizada', NULL, 'Necessidade de restauração', NULL),
(30, 22, 1, '2026-10-14', '11:00:00', 60, 'retorno', 'Retorno de tratamento', 'realizada', 'Paciente colaborativo, sem intercorrências.', NULL, NULL),
(31, 8, 1, '2026-10-14', '14:00:00', 30, 'manutencao', 'Controle periódico', 'realizada', 'Orientada higiene bucal e uso de fio dental.', 'Cárie em dente posterior', NULL),
(32, 6, 2, '2026-10-15', '09:00:00', 60, 'avaliacao', 'Dor de dente', 'realizada', 'Paciente relatou sensibilidade ao frio.', 'Bruxismo suspeito', NULL),
(33, 24, 2, '2026-10-15', '11:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Orientada higiene bucal e uso de fio dental.', 'Placa bacteriana e cálculo', NULL),
(34, 17, 2, '2026-10-15', '16:00:00', 30, 'avaliacao', 'Check-up geral', 'realizada', 'Sem queixas no momento.', 'Bruxismo suspeito', NULL),
(35, 1, 1, '2026-10-16', '16:00:00', 60, 'avaliacao', 'Check-up geral', 'realizada', 'Retorno agendado conforme plano.', 'Dente com fratura coronária', NULL),
(36, 19, 2, '2026-10-17', '09:00:00', 30, 'manutencao', 'Controle periódico', 'realizada', 'Retorno agendado conforme plano.', NULL, NULL),
(37, 25, 2, '2026-10-17', '11:00:00', 60, 'retorno', 'Retorno de tratamento', 'realizada', NULL, 'Dente com fratura coronária', NULL),
(38, 12, 3, '2026-10-17', '11:00:00', 60, 'manutencao', 'Limpeza e revisão', 'realizada', NULL, NULL, NULL),
(39, 23, 1, '2026-10-19', '11:00:00', 60, 'avaliacao', 'Check-up geral', 'realizada', 'Sem queixas no momento.', 'Bruxismo suspeito', NULL),
(40, 10, 1, '2026-10-19', '17:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'cancelada', NULL, NULL, NULL),
(41, 10, 2, '2026-10-20', '08:00:00', 30, 'avaliacao', 'Dor de dente', 'realizada', 'Paciente colaborativo, sem intercorrências.', 'Cárie em dente posterior', NULL),
(42, 25, 2, '2026-10-20', '11:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Paciente relatou sensibilidade ao frio.', 'Bruxismo suspeito', NULL),
(43, 8, 2, '2026-10-20', '14:00:00', 30, 'manutencao', 'Limpeza e revisão', 'realizada', 'Sem queixas no momento.', NULL, NULL),
(44, 13, 2, '2026-10-20', '15:00:00', 60, 'avaliacao', 'Check-up geral', 'realizada', NULL, 'Gengivite leve', NULL),
(45, 27, 1, '2026-10-21', '08:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Sem queixas no momento.', 'Gengivite leve', NULL),
(46, 12, 1, '2026-10-21', '11:00:00', 60, 'urgencia', 'Dor intensa', 'realizada', NULL, 'Gengivite leve', NULL),
(47, 25, 1, '2026-10-21', '16:00:00', 30, 'urgencia', 'Dente fraturado', 'realizada', 'Orientada higiene bucal e uso de fio dental.', 'Placa bacteriana e cálculo', NULL),
(48, 23, 2, '2026-10-22', '08:00:00', 30, 'manutencao', 'Controle periódico', 'realizada', NULL, NULL, NULL),
(49, 27, 2, '2026-10-22', '09:00:00', 60, 'avaliacao', 'Avaliação para tratamento', 'realizada', NULL, 'Bruxismo suspeito', NULL),
(50, 9, 2, '2026-10-22', '10:00:00', 60, 'manutencao', 'Manutenção preventiva', 'realizada', NULL, 'Dente com fratura coronária', NULL),
(51, 26, 3, '2026-10-22', '15:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'realizada', 'Sem queixas no momento.', NULL, NULL),
(52, 6, 1, '2026-10-23', '08:00:00', 30, 'manutencao', 'Manutenção preventiva', 'realizada', 'Orientada higiene bucal e uso de fio dental.', 'Cárie em dente posterior', NULL),
(53, 3, 1, '2026-10-23', '09:00:00', 30, 'manutencao', 'Manutenção preventiva', 'realizada', NULL, NULL, NULL),
(54, 12, 1, '2026-10-23', '16:00:00', 30, 'manutencao', 'Manutenção preventiva', 'realizada', 'Retorno agendado conforme plano.', NULL, NULL),
(55, 3, 2, '2026-10-24', '08:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'cancelada', NULL, NULL, NULL),
(56, 22, 3, '2026-10-24', '10:00:00', 30, 'manutencao', 'Manutenção preventiva', 'realizada', 'Sem queixas no momento.', NULL, NULL),
(57, 21, 3, '2026-10-26', '09:00:00', 60, 'manutencao', 'Controle periódico', 'realizada', 'Paciente colaborativo, sem intercorrências.', 'Dente com fratura coronária', NULL),
(58, 16, 2, '2026-10-27', '09:00:00', 60, 'urgencia', 'Dor intensa', 'realizada', 'Retorno agendado conforme plano.', 'Bruxismo suspeito', NULL),
(59, 5, 2, '2026-10-27', '10:00:00', 60, 'avaliacao', 'Check-up geral', 'realizada', 'Paciente colaborativo, sem intercorrências.', 'Sem alterações relevantes', NULL),
(60, 3, 2, '2026-10-27', '17:00:00', 30, 'manutencao', 'Controle periódico', 'cancelada', NULL, NULL, NULL);

INSERT INTO Consulta (id_consulta, id_paciente, id_dentista, data_consulta, hora_consulta, duracao_prevista, tipo_consulta, motivo, status, observacoes, diagnostico, motivo_cancelamento) VALUES
(61, 28, 1, '2026-10-28', '10:00:00', 60, 'manutencao', 'Limpeza e revisão', 'realizada', 'Paciente relatou sensibilidade ao frio.', NULL, NULL),
(62, 10, 2, '2026-10-29', '16:00:00', 30, 'avaliacao', 'Avaliação inicial', 'realizada', NULL, 'Necessidade de restauração', NULL),
(63, 19, 1, '2026-10-30', '17:00:00', 30, 'avaliacao', 'Avaliação inicial', 'realizada', 'Paciente relatou sensibilidade ao frio.', 'Cárie em dente posterior', NULL),
(64, 3, 3, '2026-10-31', '08:00:00', 60, 'manutencao', 'Controle periódico', 'realizada', NULL, 'Cárie em dente posterior', NULL),
(65, 25, 3, '2026-10-31', '09:00:00', 30, 'avaliacao', 'Check-up geral', 'falta', NULL, NULL, NULL),
(66, 5, 2, '2026-10-31', '11:00:00', 60, 'retorno', 'Retorno de tratamento', 'realizada', 'Retorno agendado conforme plano.', NULL, NULL),
(67, 11, 1, '2026-11-09', '10:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'agendada', NULL, NULL, NULL),
(68, 8, 3, '2026-11-09', '10:00:00', 30, 'avaliacao', 'Dor de dente', 'agendada', NULL, NULL, NULL),
(69, 12, 1, '2026-11-09', '10:30:00', 30, 'retorno', 'Retorno de tratamento', 'agendada', NULL, NULL, NULL),
(70, 11, 1, '2026-11-09', '16:00:00', 30, 'retorno', 'Revisão pós-procedimento', 'agendada', NULL, NULL, NULL),
(71, 12, 2, '2026-11-03', '11:00:00', 30, 'avaliacao', 'Avaliação para tratamento', 'realizada', 'Sem queixas no momento.', NULL, NULL),
(72, 4, 2, '2026-11-03', '15:00:00', 30, 'urgencia', 'Dor intensa', 'falta', NULL, NULL, NULL),
(73, 28, 2, '2026-11-03', '16:00:00', 30, 'retorno', 'Retorno de tratamento', 'cancelada', NULL, NULL, NULL),
(74, 11, 1, '2026-11-04', '10:00:00', 30, 'retorno', 'Revisão pós-procedimento', 'confirmada', NULL, NULL, NULL),
(75, 10, 1, '2026-11-04', '15:00:00', 60, 'avaliacao', 'Check-up geral', 'confirmada', NULL, NULL, NULL),
(76, 23, 1, '2026-11-04', '16:00:00', 60, 'urgencia', 'Inchaço na gengiva', 'confirmada', NULL, NULL, NULL),
(77, 3, 3, '2026-11-05', '15:00:00', 60, 'urgencia', 'Inchaço na gengiva', 'confirmada', NULL, NULL, NULL),
(78, 19, 2, '2026-11-05', '16:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'confirmada', NULL, NULL, NULL),
(79, 9, 2, '2026-11-05', '17:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'confirmada', NULL, NULL, NULL),
(80, 15, 1, '2026-11-06', '08:00:00', 60, 'avaliacao', 'Avaliação inicial', 'agendada', NULL, NULL, NULL),
(81, 22, 1, '2026-11-06', '14:00:00', 60, 'manutencao', 'Manutenção preventiva', 'agendada', NULL, NULL, NULL),
(82, 18, 1, '2026-11-06', '15:00:00', 60, 'avaliacao', 'Check-up geral', 'agendada', NULL, NULL, NULL),
(83, 5, 1, '2026-11-06', '16:00:00', 60, 'retorno', 'Revisão pós-procedimento', 'agendada', NULL, NULL, NULL),
(84, 10, 1, '2026-11-06', '17:00:00', 60, 'urgencia', 'Inchaço na gengiva', 'agendada', NULL, NULL, NULL),
(85, 14, 2, '2026-11-07', '08:00:00', 30, 'avaliacao', 'Avaliação para tratamento', 'agendada', NULL, NULL, NULL),
(86, 12, 3, '2026-11-07', '09:00:00', 60, 'urgencia', 'Dor intensa', 'agendada', NULL, NULL, NULL),
(87, 22, 3, '2026-11-07', '10:00:00', 60, 'urgencia', 'Dente fraturado', 'agendada', NULL, NULL, NULL),
(88, 26, 2, '2026-10-13', '08:30:00', 60, 'retorno', 'Continuidade do tratamento', 'realizada', NULL, NULL, NULL),
(89, 17, 2, '2026-10-22', '08:30:00', 30, 'manutencao', 'Limpeza e revisão', 'realizada', NULL, NULL, NULL);

INSERT INTO Procedimento (id_procedimento, id_consulta, nome_procedimento, data_procedimento, descricao, valor_cobrado) VALUES
(1, 2, 'Clareamento dental', '2026-10-01', 'Arcadas superior e inferior', 900),
(2, 4, 'Extração simples', '2026-10-01', 'Arcada inferior', 280),
(3, 5, 'Aplicação de flúor', '2026-10-02', 'Dente 26', 120),
(4, 5, 'Extração simples', '2026-10-02', NULL, 280),
(5, 6, 'Profilaxia (limpeza)', '2026-10-02', 'Arcada superior', 250),
(6, 7, 'Extração simples', '2026-10-02', 'Dente 26', 280),
(7, 9, 'Profilaxia (limpeza)', '2026-10-03', 'Arcada superior', 250),
(8, 10, 'Raspagem periodontal', '2026-10-05', 'Dente 36', 220),
(9, 10, 'Extração simples', '2026-10-05', NULL, 280),
(10, 11, 'Extração simples', '2026-10-05', NULL, 280),
(11, 15, 'Profilaxia (limpeza)', '2026-10-07', 'Dente 16', 250),
(12, 16, 'Raspagem periodontal', '2026-10-07', 'Dente 26', 220),
(13, 16, 'Restauração em resina', '2026-10-07', 'Dente 46', 320),
(14, 17, 'Aplicação de flúor', '2026-10-07', 'Arcada superior', 120),
(15, 22, 'Clareamento dental', '2026-10-10', 'Arcadas superior e inferior', 900),
(16, 24, 'Restauração em resina', '2026-10-14', 'Arcada inferior', 320),
(17, 25, 'Tratamento de canal', '2026-10-13', 'Dente 16', 850),
(18, 27, 'Profilaxia (limpeza)', '2026-10-13', NULL, 250),
(19, 88, 'Tratamento de canal', '2026-10-13', 'Dente 26', 850),
(20, 30, 'Aplicação de flúor', '2026-10-14', 'Dente 46', 120),
(21, 31, 'Profilaxia (limpeza)', '2026-10-14', NULL, 250),
(22, 32, 'Restauração em resina', '2026-10-15', 'Arcada superior', 300),
(23, 35, 'Profilaxia (limpeza)', '2026-10-16', NULL, 250),
(24, 36, 'Restauração em resina', '2026-10-17', 'Dente 16', 350),
(25, 38, 'Profilaxia (limpeza)', '2026-10-17', 'Arcada superior', 250),
(26, 41, 'Raspagem periodontal', '2026-10-20', 'Dente 26', 220),
(27, 42, 'Profilaxia (limpeza)', '2026-10-20', 'Dente 26', 250),
(28, 43, 'Restauração em resina', '2026-10-20', 'Dente 26', 300),
(29, 44, 'Restauração em resina', '2026-10-20', NULL, 350),
(30, 46, 'Profilaxia (limpeza)', '2026-10-21', NULL, 250),
(31, 47, 'Extração simples', '2026-10-21', 'Dente 16', 280),
(32, 48, 'Profilaxia (limpeza)', '2026-10-22', 'Dente 16', 250),
(33, 49, 'Profilaxia (limpeza)', '2026-10-22', 'Arcada inferior', 250),
(34, 49, 'Tratamento de canal', '2026-10-22', 'Dente 16', 850),
(35, 50, 'Extração simples', '2026-10-22', 'Dente 16', 280),
(36, 89, 'Profilaxia (limpeza)', '2026-10-22', 'Arcada inferior', 250),
(37, 51, 'Profilaxia (limpeza)', '2026-10-22', NULL, 250),
(38, 52, 'Restauração em resina', '2026-10-23', 'Arcada inferior', 350),
(39, 53, 'Restauração em resina', '2026-10-23', 'Dente 46', 320),
(40, 54, 'Profilaxia (limpeza)', '2026-10-23', 'Dente 26', 250),
(41, 56, 'Raspagem periodontal', '2026-10-24', 'Arcada inferior', 220),
(42, 57, 'Profilaxia (limpeza)', '2026-10-26', 'Arcada inferior', 250),
(43, 58, 'Aplicação de flúor', '2026-10-27', NULL, 120),
(44, 61, 'Restauração em resina', '2026-10-28', 'Dente 16', 320),
(45, 63, 'Restauração em resina', '2026-10-30', 'Arcada superior', 300),
(46, 66, 'Raspagem periodontal', '2026-10-31', 'Arcada superior', 220),
(47, 64, 'Restauração em resina', '2026-10-31', 'Arcada inferior', 300),
(48, 64, 'Clareamento dental', '2026-10-31', 'Arcadas superior e inferior', 900);

INSERT INTO Pagamento (id_pagamento, id_procedimento, valor, data_pagamento, forma_pagamento, status_pagamento) VALUES
(1, 1, 900.00, NULL, 'dinheiro', 'pendente'),
(2, 2, 280.00, '2026-10-01', 'dinheiro', 'pago'),
(3, 3, 120.00, '2026-10-02', 'dinheiro', 'pago'),
(4, 4, 280.00, NULL, 'cartao_credito', 'pendente'),
(5, 5, 250.00, '2026-10-02', 'cartao_credito', 'pago'),
(6, 5, 80.00, '2026-10-07', 'cartao_credito', 'pago'),
(7, 7, 250.00, '2026-10-03', 'cartao_debito', 'pago'),
(8, 8, 220.00, '2026-10-05', 'cartao_credito', 'pago'),
(9, 10, 280.00, '2026-10-05', 'cartao_credito', 'pago'),
(10, 11, 250.00, '2026-10-07', 'dinheiro', 'pago'),
(11, 12, 220.00, '2026-10-07', 'dinheiro', 'pago'),
(12, 13, 160.00, '2026-10-07', 'cartao_credito', 'pago'),
(13, 13, 160.00, NULL, 'cartao_credito', 'pendente'),
(14, 14, 120.00, '2026-10-07', 'dinheiro', 'pago'),
(15, 15, 900.00, NULL, 'dinheiro', 'pendente'),
(16, 16, 160.00, '2026-10-14', 'cartao_credito', 'pago'),
(17, 16, 160.00, NULL, 'cartao_credito', 'pendente'),
(18, 17, 425.00, '2026-10-13', 'cartao_credito', 'pago'),
(19, 17, 425.00, NULL, 'cartao_credito', 'pendente'),
(20, 18, 250.00, '2026-10-13', 'cartao_debito', 'pago'),
(21, 19, 425.00, '2026-10-13', 'cartao_credito', 'pago'),
(22, 19, 425.00, NULL, 'cartao_credito', 'pendente'),
(23, 20, 120.00, '2026-10-14', 'dinheiro', 'pago'),
(24, 21, 250.00, '2026-10-14', 'dinheiro', 'pago'),
(25, 22, 300.00, '2026-10-15', 'cartao_debito', 'pago'),
(26, 23, 250.00, '2026-10-16', 'dinheiro', 'pago'),
(27, 24, 350.00, '2026-10-17', 'cartao_credito', 'pago'),
(28, 25, 250.00, '2026-10-17', 'dinheiro', 'pago'),
(29, 26, 220.00, '2026-10-20', 'cartao_credito', 'pago'),
(30, 27, 250.00, '2026-10-20', 'dinheiro', 'pago'),
(31, 28, 300.00, '2026-10-20', 'dinheiro', 'pago'),
(32, 29, 350.00, '2026-10-20', 'cartao_credito', 'pago'),
(33, 30, 250.00, '2026-10-21', 'dinheiro', 'pago'),
(34, 31, 280.00, '2026-10-21', 'dinheiro', 'pago'),
(35, 32, 250.00, '2026-10-22', 'dinheiro', 'pago'),
(36, 33, 250.00, '2026-10-22', 'cartao_credito', 'pago'),
(37, 34, 850.00, '2026-10-22', 'cartao_credito', 'pago'),
(38, 35, 280.00, NULL, 'cartao_credito', 'pendente'),
(39, 36, 250.00, '2026-10-22', 'dinheiro', 'pago'),
(40, 37, 250.00, NULL, 'dinheiro', 'pendente'),
(41, 38, 350.00, '2026-10-23', 'cartao_credito', 'pago'),
(42, 39, 320.00, '2026-10-23', 'dinheiro', 'pago'),
(43, 40, 250.00, '2026-10-23', 'dinheiro', 'pago'),
(44, 41, 220.00, '2026-10-24', 'dinheiro', 'pago'),
(45, 42, 250.00, '2026-10-26', 'dinheiro', 'pago'),
(46, 44, 160.00, '2026-10-28', 'cartao_credito', 'pago'),
(47, 44, 160.00, NULL, 'cartao_credito', 'pendente'),
(48, 45, 300.00, '2026-10-30', 'dinheiro', 'pago'),
(49, 46, 220.00, '2026-10-31', 'cartao_credito', 'pago'),
(50, 47, 300.00, '2026-10-31', 'cartao_credito', 'pago'),
(51, 48, 300.00, '2026-10-31', 'cartao_credito', 'pago'),
(52, 48, 300.00, NULL, 'cartao_credito', 'pendente'),
(53, 48, 300.00, NULL, 'cartao_credito', 'pendente');

INSERT INTO Procedimento_Material (id_procedimento, id_material, quantidade_utilizada, data_utilizacao) VALUES
(31, 5, 2, '2026-10-21'),
(1, 1, 1, '2026-10-01'),
(1, 2, 1, '2026-10-01'),
(2, 1, 2, '2026-10-01'),
(2, 4, 2, '2026-10-01'),
(2, 5, 4, '2026-10-01'),
(2, 8, 1, '2026-10-01'),
(3, 1, 1, '2026-10-02'),
(3, 7, 4, '2026-10-02'),
(4, 1, 1, '2026-10-02'),
(4, 4, 1, '2026-10-02'),
(4, 5, 4, '2026-10-02'),
(4, 8, 1, '2026-10-02'),
(5, 1, 2, '2026-10-02'),
(5, 2, 1, '2026-10-02'),
(5, 6, 5, '2026-10-02'),
(5, 10, 1, '2026-10-02'),
(6, 1, 2, '2026-10-02'),
(6, 4, 1, '2026-10-02'),
(6, 5, 4, '2026-10-02'),
(6, 8, 1, '2026-10-02'),
(7, 1, 1, '2026-10-03'),
(7, 2, 1, '2026-10-03'),
(7, 6, 5, '2026-10-03'),
(7, 10, 1, '2026-10-03'),
(8, 1, 2, '2026-10-05'),
(8, 2, 1, '2026-10-05'),
(8, 10, 1, '2026-10-05'),
(9, 1, 1, '2026-10-05'),
(9, 4, 2, '2026-10-05'),
(9, 5, 2, '2026-10-05'),
(9, 8, 1, '2026-10-05'),
(10, 1, 1, '2026-10-05'),
(10, 4, 1, '2026-10-05'),
(10, 5, 2, '2026-10-05'),
(10, 8, 1, '2026-10-05'),
(11, 1, 2, '2026-10-07'),
(11, 2, 1, '2026-10-07'),
(11, 6, 5, '2026-10-07'),
(11, 10, 1, '2026-10-07'),
(12, 1, 2, '2026-10-07'),
(12, 2, 1, '2026-10-07'),
(12, 10, 1, '2026-10-07'),
(13, 1, 2, '2026-10-07'),
(13, 3, 1, '2026-10-07'),
(13, 4, 1, '2026-10-07'),
(13, 10, 1, '2026-10-07'),
(13, 12, 1, '2026-10-07'),
(14, 1, 1, '2026-10-07'),
(14, 7, 4, '2026-10-07'),
(15, 1, 2, '2026-10-10'),
(15, 2, 1, '2026-10-10'),
(16, 1, 2, '2026-10-14'),
(16, 3, 1, '2026-10-14'),
(16, 4, 1, '2026-10-14'),
(16, 10, 1, '2026-10-14'),
(16, 12, 1, '2026-10-14'),
(17, 1, 2, '2026-10-13'),
(17, 4, 2, '2026-10-13'),
(17, 9, 1, '2026-10-13'),
(17, 11, 1, '2026-10-13');

INSERT INTO Procedimento_Material (id_procedimento, id_material, quantidade_utilizada, data_utilizacao) VALUES
(18, 1, 2, '2026-10-13'),
(18, 2, 1, '2026-10-13'),
(18, 6, 5, '2026-10-13'),
(18, 10, 1, '2026-10-13'),
(19, 1, 2, '2026-10-13'),
(19, 4, 1, '2026-10-13'),
(19, 9, 1, '2026-10-13'),
(19, 11, 1, '2026-10-13'),
(20, 1, 1, '2026-10-14'),
(20, 7, 4, '2026-10-14'),
(21, 1, 1, '2026-10-14'),
(21, 2, 1, '2026-10-14'),
(21, 6, 5, '2026-10-14'),
(21, 10, 1, '2026-10-14'),
(22, 1, 1, '2026-10-15'),
(22, 3, 1, '2026-10-15'),
(22, 4, 1, '2026-10-15'),
(22, 10, 1, '2026-10-15'),
(22, 12, 1, '2026-10-15'),
(23, 1, 2, '2026-10-16'),
(23, 2, 1, '2026-10-16'),
(23, 6, 5, '2026-10-16'),
(23, 10, 1, '2026-10-16'),
(24, 1, 1, '2026-10-17'),
(24, 3, 1, '2026-10-17'),
(24, 4, 1, '2026-10-17'),
(24, 10, 1, '2026-10-17'),
(24, 12, 1, '2026-10-17'),
(25, 1, 2, '2026-10-17'),
(25, 2, 1, '2026-10-17'),
(25, 6, 5, '2026-10-17'),
(25, 10, 1, '2026-10-17'),
(26, 1, 2, '2026-10-20'),
(26, 2, 1, '2026-10-20'),
(26, 10, 1, '2026-10-20'),
(27, 1, 2, '2026-10-20'),
(27, 2, 1, '2026-10-20'),
(27, 6, 5, '2026-10-20'),
(27, 10, 1, '2026-10-20'),
(28, 1, 1, '2026-10-20'),
(28, 3, 1, '2026-10-20'),
(28, 4, 1, '2026-10-20'),
(28, 10, 1, '2026-10-20'),
(28, 12, 1, '2026-10-20'),
(29, 1, 1, '2026-10-20'),
(29, 3, 1, '2026-10-20'),
(29, 4, 1, '2026-10-20'),
(29, 10, 1, '2026-10-20'),
(29, 12, 1, '2026-10-20'),
(30, 1, 1, '2026-10-21'),
(30, 2, 1, '2026-10-21'),
(30, 6, 5, '2026-10-21'),
(30, 10, 1, '2026-10-21'),
(31, 1, 1, '2026-10-21'),
(31, 4, 2, '2026-10-21'),
(31, 8, 1, '2026-10-21'),
(32, 1, 1, '2026-10-22'),
(32, 2, 1, '2026-10-22'),
(32, 6, 5, '2026-10-22'),
(32, 10, 1, '2026-10-22');

INSERT INTO Procedimento_Material (id_procedimento, id_material, quantidade_utilizada, data_utilizacao) VALUES
(33, 1, 2, '2026-10-22'),
(33, 2, 1, '2026-10-22'),
(33, 6, 5, '2026-10-22'),
(33, 10, 1, '2026-10-22'),
(34, 1, 2, '2026-10-22'),
(34, 4, 2, '2026-10-22'),
(34, 9, 1, '2026-10-22'),
(34, 11, 1, '2026-10-22'),
(35, 1, 2, '2026-10-22'),
(35, 4, 2, '2026-10-22'),
(35, 8, 1, '2026-10-22'),
(36, 1, 2, '2026-10-22'),
(36, 2, 1, '2026-10-22'),
(36, 6, 5, '2026-10-22'),
(36, 10, 1, '2026-10-22'),
(37, 1, 2, '2026-10-22'),
(37, 2, 1, '2026-10-22'),
(37, 6, 5, '2026-10-22'),
(37, 10, 1, '2026-10-22'),
(38, 1, 2, '2026-10-23'),
(38, 3, 1, '2026-10-23'),
(38, 4, 1, '2026-10-23'),
(38, 10, 1, '2026-10-23'),
(38, 12, 1, '2026-10-23'),
(39, 1, 1, '2026-10-23'),
(39, 3, 1, '2026-10-23'),
(39, 4, 1, '2026-10-23'),
(39, 10, 1, '2026-10-23'),
(39, 12, 1, '2026-10-23'),
(40, 1, 2, '2026-10-23'),
(40, 2, 1, '2026-10-23'),
(40, 6, 5, '2026-10-23'),
(40, 10, 1, '2026-10-23'),
(41, 1, 1, '2026-10-24'),
(41, 2, 1, '2026-10-24'),
(41, 10, 1, '2026-10-24'),
(42, 1, 2, '2026-10-26'),
(42, 2, 1, '2026-10-26'),
(42, 6, 5, '2026-10-26'),
(42, 10, 1, '2026-10-26'),
(43, 1, 1, '2026-10-27'),
(43, 7, 4, '2026-10-27'),
(44, 1, 1, '2026-10-28'),
(44, 3, 1, '2026-10-28'),
(44, 4, 1, '2026-10-28'),
(44, 10, 1, '2026-10-28'),
(44, 12, 1, '2026-10-28'),
(45, 1, 1, '2026-10-30'),
(45, 3, 1, '2026-10-30'),
(45, 4, 1, '2026-10-30'),
(45, 10, 1, '2026-10-30'),
(45, 12, 1, '2026-10-30'),
(46, 1, 2, '2026-10-31'),
(46, 2, 1, '2026-10-31'),
(46, 10, 1, '2026-10-31'),
(47, 1, 2, '2026-10-31'),
(47, 3, 1, '2026-10-31'),
(47, 4, 1, '2026-10-31'),
(47, 10, 1, '2026-10-31'),
(47, 12, 1, '2026-10-31');

INSERT INTO Procedimento_Material (id_procedimento, id_material, quantidade_utilizada, data_utilizacao) VALUES
(48, 1, 2, '2026-10-31'),
(48, 2, 1, '2026-10-31');

INSERT INTO Acesso_prontuario (id_acesso, id_usuario, id_prontuario, data_acesso, tipo_acesso) VALUES
(1, 3, 7, '2026-10-01 09:11:00', 'consulta'),
(2, 3, 7, '2026-10-01 10:01:00', 'alteracao'),
(3, 3, 19, '2026-10-01 14:11:00', 'consulta'),
(4, 3, 19, '2026-10-01 14:34:00', 'alteracao'),
(5, 3, 6, '2026-10-01 16:07:00', 'consulta'),
(6, 3, 6, '2026-10-01 16:45:00', 'alteracao'),
(7, 2, 28, '2026-10-02 11:00:00', 'consulta'),
(8, 2, 13, '2026-10-02 14:01:00', 'consulta'),
(9, 2, 12, '2026-10-02 16:04:00', 'consulta'),
(10, 3, 12, '2026-10-03 09:05:00', 'consulta'),
(11, 2, 11, '2026-10-05 08:00:00', 'consulta'),
(12, 2, 11, '2026-10-05 08:39:00', 'alteracao'),
(13, 2, 5, '2026-10-05 10:08:00', 'consulta'),
(14, 2, 5, '2026-10-05 10:38:00', 'alteracao'),
(15, 3, 28, '2026-10-06 16:05:00', 'consulta'),
(16, 3, 28, '2026-10-06 16:45:00', 'alteracao'),
(17, 2, 4, '2026-10-07 11:07:00', 'consulta'),
(18, 2, 22, '2026-10-07 15:11:00', 'consulta'),
(19, 2, 22, '2026-10-07 15:58:00', 'alteracao'),
(20, 2, 8, '2026-10-07 16:15:00', 'consulta'),
(21, 2, 8, '2026-10-07 17:05:00', 'alteracao'),
(22, 2, 27, '2026-10-09 15:04:00', 'consulta'),
(23, 3, 1, '2026-10-10 09:16:00', 'consulta'),
(24, 3, 1, '2026-10-10 10:03:00', 'alteracao'),
(25, 2, 16, '2026-10-14 10:09:00', 'consulta'),
(26, 2, 16, '2026-10-14 10:44:00', 'alteracao'),
(27, 3, 8, '2026-10-13 10:09:00', 'consulta'),
(28, 3, 11, '2026-10-13 14:04:00', 'consulta'),
(29, 3, 11, '2026-10-13 14:24:00', 'alteracao'),
(30, 3, 29, '2026-10-13 15:01:00', 'consulta'),
(31, 3, 27, '2026-10-13 16:07:00', 'consulta'),
(32, 3, 27, '2026-10-13 16:39:00', 'alteracao'),
(33, 2, 18, '2026-10-14 10:13:00', 'consulta'),
(34, 2, 22, '2026-10-14 11:02:00', 'consulta'),
(35, 2, 22, '2026-10-14 11:22:00', 'alteracao'),
(36, 2, 8, '2026-10-14 14:19:00', 'consulta'),
(37, 2, 8, '2026-10-14 14:53:00', 'alteracao'),
(38, 3, 6, '2026-10-15 09:15:00', 'consulta'),
(39, 3, 6, '2026-10-15 09:54:00', 'alteracao'),
(40, 3, 24, '2026-10-15 11:07:00', 'consulta'),
(41, 3, 24, '2026-10-15 11:55:00', 'alteracao'),
(42, 3, 17, '2026-10-15 16:04:00', 'consulta'),
(43, 3, 17, '2026-10-15 16:34:00', 'alteracao'),
(44, 2, 1, '2026-10-16 16:16:00', 'consulta'),
(45, 2, 1, '2026-10-16 16:41:00', 'alteracao'),
(46, 3, 19, '2026-10-17 09:09:00', 'consulta'),
(47, 3, 19, '2026-10-17 09:56:00', 'alteracao'),
(48, 3, 25, '2026-10-17 11:12:00', 'consulta'),
(49, 2, 23, '2026-10-19 11:15:00', 'consulta'),
(50, 2, 23, '2026-10-19 12:00:00', 'alteracao'),
(51, 3, 10, '2026-10-20 08:00:00', 'consulta'),
(52, 3, 10, '2026-10-20 08:36:00', 'alteracao'),
(53, 3, 25, '2026-10-20 11:07:00', 'consulta'),
(54, 3, 8, '2026-10-20 14:18:00', 'consulta'),
(55, 3, 13, '2026-10-20 15:14:00', 'consulta'),
(56, 3, 13, '2026-10-20 16:01:00', 'alteracao'),
(57, 2, 27, '2026-10-21 08:17:00', 'consulta'),
(58, 2, 27, '2026-10-21 09:02:00', 'alteracao'),
(59, 2, 12, '2026-10-21 11:11:00', 'consulta'),
(60, 2, 25, '2026-10-21 16:18:00', 'consulta');

INSERT INTO Acesso_prontuario (id_acesso, id_usuario, id_prontuario, data_acesso, tipo_acesso) VALUES
(61, 2, 25, '2026-10-21 16:43:00', 'alteracao'),
(62, 3, 23, '2026-10-22 08:08:00', 'consulta'),
(63, 3, 23, '2026-10-22 08:42:00', 'alteracao'),
(64, 3, 27, '2026-10-22 09:17:00', 'consulta'),
(65, 3, 9, '2026-10-22 10:11:00', 'consulta'),
(66, 3, 9, '2026-10-22 10:54:00', 'alteracao'),
(67, 2, 6, '2026-10-23 08:05:00', 'consulta'),
(68, 2, 6, '2026-10-23 08:29:00', 'alteracao'),
(69, 2, 3, '2026-10-23 09:13:00', 'consulta'),
(70, 2, 3, '2026-10-23 09:36:00', 'alteracao'),
(71, 2, 12, '2026-10-23 16:14:00', 'consulta'),
(72, 2, 12, '2026-10-23 16:54:00', 'alteracao'),
(73, 3, 16, '2026-10-27 09:01:00', 'consulta'),
(74, 3, 5, '2026-10-27 10:12:00', 'consulta'),
(75, 2, 28, '2026-10-28 10:17:00', 'consulta'),
(76, 2, 28, '2026-10-28 10:53:00', 'alteracao'),
(77, 3, 10, '2026-10-29 16:10:00', 'consulta'),
(78, 2, 19, '2026-10-30 17:09:00', 'consulta'),
(79, 2, 19, '2026-10-30 17:38:00', 'alteracao'),
(80, 3, 5, '2026-10-31 11:17:00', 'consulta'),
(81, 3, 5, '2026-10-31 11:44:00', 'alteracao'),
(82, 3, 12, '2026-11-03 11:06:00', 'consulta');

INSERT INTO Log_auditoria (id_log, id_usuario, data_hora, tipo_acao, descricao) VALUES
(1, 1, '2026-10-01 15:20:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 2 confirmado (dinheiro)'),
(2, 1, '2026-10-02 12:15:00', 'CANCELAMENTO', 'Consulta 12 cancelada'),
(3, 1, '2026-10-02 15:23:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 5 confirmado (dinheiro)'),
(4, 1, '2026-10-02 15:39:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 3 confirmado (dinheiro)'),
(5, 1, '2026-10-03 15:31:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 7 confirmado (cartao_debito)'),
(6, 1, '2026-10-05 10:15:00', 'REMARCACAO', 'Consulta 23 remarcada de 05/10/2026 11:00 para 10/10/2026 11:00'),
(7, 1, '2026-10-05 15:03:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 8 confirmado (cartao_credito)'),
(8, 1, '2026-10-05 15:37:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 10 confirmado (cartao_credito)'),
(9, 1, '2026-10-05 17:54:00', 'CANCELAMENTO', 'Consulta 13 cancelada'),
(10, 1, '2026-10-07 15:32:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 14 confirmado (dinheiro)'),
(11, 1, '2026-10-07 15:39:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 13 confirmado (dinheiro)'),
(12, 1, '2026-10-07 15:40:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 12 confirmado (dinheiro)'),
(13, 1, '2026-10-07 15:48:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 11 confirmado (dinheiro)'),
(14, 1, '2026-10-08 17:08:00', 'CANCELAMENTO', 'Consulta 19 cancelada'),
(15, 1, '2026-10-14 15:49:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 16 confirmado (dinheiro)'),
(16, 1, '2026-10-13 15:33:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 18 confirmado (cartao_debito)'),
(17, 1, '2026-10-13 15:56:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 17 confirmado (dinheiro)'),
(18, 1, '2026-10-13 15:56:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 19 confirmado (dinheiro)'),
(19, 1, '2026-10-14 15:16:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 20 confirmado (dinheiro)'),
(20, 1, '2026-10-14 15:43:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 21 confirmado (dinheiro)'),
(21, 1, '2026-10-15 15:23:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 22 confirmado (cartao_debito)'),
(22, 1, '2026-10-16 10:38:00', 'REMARCACAO', 'Consulta 41 remarcada de 17/10/2026 09:00 para 20/10/2026 08:00'),
(23, 1, '2026-10-16 15:01:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 23 confirmado (dinheiro)'),
(24, 1, '2026-10-17 15:10:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 24 confirmado (cartao_credito)'),
(25, 1, '2026-10-17 15:55:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 25 confirmado (dinheiro)'),
(26, 1, '2026-10-17 16:24:00', 'CANCELAMENTO', 'Consulta 40 cancelada'),
(27, 1, '2026-10-20 15:04:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 27 confirmado (dinheiro)'),
(28, 1, '2026-10-20 15:07:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 28 confirmado (dinheiro)'),
(29, 1, '2026-10-20 15:17:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 26 confirmado (cartao_credito)'),
(30, 1, '2026-10-20 15:41:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 29 confirmado (cartao_credito)'),
(31, 1, '2026-10-21 15:19:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 31 confirmado (dinheiro)'),
(32, 1, '2026-10-21 15:36:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 30 confirmado (dinheiro)'),
(33, 1, '2026-10-22 15:03:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 33 confirmado (cartao_credito)'),
(34, 1, '2026-10-22 15:13:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 36 confirmado (dinheiro)'),
(35, 1, '2026-10-22 15:49:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 34 confirmado (cartao_credito)'),
(36, 1, '2026-10-22 15:58:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 32 confirmado (dinheiro)'),
(37, 1, '2026-10-23 13:54:00', 'CANCELAMENTO', 'Consulta 55 cancelada'),
(38, 1, '2026-10-23 15:03:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 38 confirmado (cartao_credito)'),
(39, 1, '2026-10-23 15:10:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 40 confirmado (dinheiro)'),
(40, 1, '2026-10-23 15:28:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 39 confirmado (dinheiro)'),
(41, 1, '2026-10-24 15:47:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 41 confirmado (dinheiro)'),
(42, 1, '2026-10-24 15:56:00', 'CANCELAMENTO', 'Consulta 60 cancelada'),
(43, 1, '2026-10-26 15:45:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 42 confirmado (dinheiro)'),
(44, 1, '2026-10-27 16:00:00', 'REMARCACAO', 'Consulta 70 remarcada de 28/10/2026 16:00 para 09/11/2026 16:00'),
(45, 1, '2026-10-28 15:35:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 44 confirmado (cartao_debito)'),
(46, 1, '2026-10-30 15:38:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 45 confirmado (dinheiro)'),
(47, 1, '2026-10-31 15:55:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 46 confirmado (cartao_credito)'),
(48, 1, '2026-10-31 15:56:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 47 confirmado (cartao_credito)'),
(49, 1, '2026-10-31 15:58:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 48 confirmado (dinheiro)'),
(50, 1, '2026-11-01 17:17:00', 'CANCELAMENTO', 'Consulta 73 cancelada'),
(51, 1, '2026-10-01 18:10:00', 'FALTA', 'Falta registrada na consulta 3'),
(52, 1, '2026-10-03 18:10:00', 'FALTA', 'Falta registrada na consulta 8'),
(53, 1, '2026-10-08 18:10:00', 'FALTA', 'Falta registrada na consulta 18'),
(54, 1, '2026-10-10 18:10:00', 'FALTA', 'Falta registrada na consulta 23'),
(55, 1, '2026-10-31 18:10:00', 'FALTA', 'Falta registrada na consulta 65'),
(56, 1, '2026-11-03 18:10:00', 'FALTA', 'Falta registrada na consulta 72'),
(57, 1, '2026-11-03 16:30:00', 'CONFIRMACAO', 'Consulta 74 confirmada pelo WhatsApp'),
(58, 1, '2026-11-03 16:30:00', 'CONFIRMACAO', 'Consulta 75 confirmada pelo WhatsApp'),
(59, 1, '2026-11-03 16:30:00', 'CONFIRMACAO', 'Consulta 76 confirmada pelo WhatsApp'),
(60, 1, '2026-11-04 16:30:00', 'CONFIRMACAO', 'Consulta 77 confirmada pelo WhatsApp');

INSERT INTO Log_auditoria (id_log, id_usuario, data_hora, tipo_acao, descricao) VALUES
(61, 1, '2026-11-04 16:30:00', 'CONFIRMACAO', 'Consulta 78 confirmada pelo WhatsApp'),
(62, 1, '2026-11-04 16:30:00', 'CONFIRMACAO', 'Consulta 79 confirmada pelo WhatsApp'),
(63, 1, '2026-10-07 17:55:00', 'CONFIRMACAO_PAGAMENTO', 'Pagamento do procedimento 5 confirmado (cartao_credito)');

-- ---------------------------------------------------------------------
-- 4. SELECT com JOIN
-- ---------------------------------------------------------------------

-- J01 — Quais são as últimas consultas, com paciente e dentista?
SELECT c.id_consulta, c.data_consulta, c.hora_consulta, p.nome_completo AS paciente,
       d.nome_completo AS dentista, c.tipo_consulta, c.status
FROM Consulta c
JOIN Paciente p ON p.id_paciente = c.id_paciente
JOIN Dentista d ON d.id_dentista = c.id_dentista
ORDER BY c.data_consulta DESC, c.hora_consulta DESC
LIMIT 15;

-- J02 — Quais procedimentos foram realizados, com paciente, dentista e consulta de origem?
-- Paciente e dentista vêm da consulta (o procedimento não repete esses dados).
SELECT pr.id_procedimento, pr.data_procedimento, pr.nome_procedimento, pa.nome_completo AS paciente,
       d.nome_completo AS dentista, c.id_consulta AS consulta_de_origem, pr.valor_cobrado
FROM Procedimento pr
JOIN Consulta c ON c.id_consulta = pr.id_consulta
JOIN Paciente pa ON pa.id_paciente = c.id_paciente
JOIN Dentista d ON d.id_dentista = c.id_dentista
ORDER BY pr.data_procedimento DESC, pr.id_procedimento DESC
LIMIT 15;

-- J03 — Quais são os pagamentos mais recentes, com o procedimento e o paciente?
SELECT pg.id_pagamento, pg.data_pagamento, pg.valor, pg.forma_pagamento, pg.status_pagamento,
       pr.nome_procedimento, pa.nome_completo AS paciente
FROM Pagamento pg
JOIN Procedimento pr ON pr.id_procedimento = pg.id_procedimento
JOIN Consulta c ON c.id_consulta = pr.id_consulta
JOIN Paciente pa ON pa.id_paciente = c.id_paciente
ORDER BY pg.id_pagamento DESC
LIMIT 15;

-- J04 — Quais materiais foram usados em cada procedimento (junção de cinco tabelas)?
SELECT pr.id_procedimento, pr.data_procedimento, pr.nome_procedimento, pa.nome_completo AS paciente,
       m.nome_material, pm.quantidade_utilizada, m.unidade
FROM Procedimento_Material pm
JOIN Procedimento pr ON pr.id_procedimento = pm.id_procedimento
JOIN Material m ON m.id_material = pm.id_material
JOIN Consulta c ON c.id_consulta = pr.id_consulta
JOIN Paciente pa ON pa.id_paciente = c.id_paciente
ORDER BY pr.id_procedimento DESC, m.nome_material
LIMIT 15;

-- J05 — Quais compras de material foram registradas, com o estoque atual?
SELECT e.data_entrada, m.nome_material, e.quantidade, m.unidade, e.fornecedor, m.quantidade_estoque
FROM Entrada_estoque e
JOIN Material m ON m.id_material = e.id_material
WHERE e.data_entrada > '2026-09-30'
ORDER BY e.data_entrada, m.nome_material;

-- ---------------------------------------------------------------------
-- 5. UPDATE
-- ---------------------------------------------------------------------

-- U01 — Confirmar o recebimento de um pagamento pendente (RN26)
UPDATE Pagamento
SET status_pagamento = 'pago', data_pagamento = '2026-11-01'
WHERE id_pagamento = 1 AND status_pagamento = 'pendente';

INSERT INTO Log_auditoria (id_usuario, data_hora, tipo_acao, descricao)
VALUES (1, '2026-11-04 07:55:00', 'CONFIRMACAO_PAGAMENTO',
        'Pagamento do procedimento 1 confirmado (dinheiro)');

-- U02 — Cancelar uma consulta agendada ou confirmada, mantendo o registro no histórico (RN12). A clínica não registra o motivo.
UPDATE Consulta
SET status = 'cancelada'
WHERE id_consulta = 75 AND status IN ('agendada', 'confirmada');

INSERT INTO Log_auditoria (id_usuario, data_hora, tipo_acao, descricao)
VALUES (1, '2026-11-04 08:00:00', 'CANCELAMENTO',
        'Consulta 75 cancelada');

-- U03 — Corrigir o uso de resina do procedimento 13 (foram 2 g, não 1 g) e dar baixa da diferença no estoque (RN37, RN38)
-- Uso e estoque mudam juntos, para o estoque continuar igual a entradas − usos (RN51, A14).
UPDATE Procedimento_Material
SET quantidade_utilizada = quantidade_utilizada + 1
WHERE id_procedimento = 13 AND id_material = 3;

UPDATE Material
SET quantidade_estoque = quantidade_estoque - 1
WHERE id_material = 3 AND quantidade_estoque >= 1;

-- U04 — Remarcar uma consulta para outro horário livre do mesmo dentista e registrar na auditoria (RN14)
UPDATE Consulta
SET data_consulta = '2026-11-06', hora_consulta = '09:00:00', status = 'agendada'
WHERE id_consulta = 76 AND status IN ('agendada', 'confirmada');

INSERT INTO Log_auditoria (id_usuario, data_hora, tipo_acao, descricao)
VALUES (1, '2026-11-04 08:10:00', 'REMARCACAO',
        'Consulta 76 remarcada de 04/11/2026 16:00 para 06/11/2026 09:00');

-- U05 — Registrar a compra de máscaras e somar ao estoque (RN51)
INSERT INTO Entrada_estoque (id_material, data_entrada, quantidade, fornecedor)
VALUES (2, '2026-11-04', 100, 'Dental (loja de materiais odontológicos)');

UPDATE Material
SET quantidade_estoque = quantidade_estoque + 100
WHERE id_material = 2;

-- U06 — Confirmar pelo WhatsApp uma consulta de 06/11 (RN49)
UPDATE Consulta
SET status = 'confirmada'
WHERE id_consulta = 80 AND status = 'agendada';

INSERT INTO Log_auditoria (id_usuario, data_hora, tipo_acao, descricao)
VALUES (1, '2026-11-04 09:30:00', 'CONFIRMACAO',
        'Consulta 80 confirmada pelo WhatsApp');

-- U07 — Registrar a falta do paciente da consulta das 10:00 de hoje (RN50)
UPDATE Consulta
SET status = 'falta'
WHERE id_consulta = 74 AND status IN ('agendada', 'confirmada');

INSERT INTO Log_auditoria (id_usuario, data_hora, tipo_acao, descricao)
VALUES (1, '2026-11-04 10:20:00', 'FALTA',
        'Falta registrada na consulta 74');

-- ---------------------------------------------------------------------
-- 6. DELETE
-- Consultas e procedimentos não são apagados (RN22). O DELETE vale só
-- para lançamentos feitos por engano e ainda pendentes.
-- ---------------------------------------------------------------------

-- D01 — Registrar um lançamento pendente por engano e excluí-lo em seguida
INSERT INTO Pagamento (id_procedimento, valor, forma_pagamento, status_pagamento)
VALUES (1, 50.00, 'dinheiro', 'pendente');

DELETE FROM Pagamento
WHERE id_pagamento = LAST_INSERT_ID() AND status_pagamento = 'pendente';

-- D02 — Tentar apagar um paciente com histórico é bloqueado pela FK (RN22).
-- Descomente para ver o erro 1451 (não executar no script, pois interrompe a carga):
-- DELETE FROM Paciente WHERE id_paciente = 12;



-- ---------------------------------------------------------------------
-- 7. CONSULTAS GERENCIAIS
-- Problemas declarados (Entrega 1):
--   P1 agenda e horários   P2 dados dos pacientes   P3 prontuários e histórico
--   P4 procedimentos       P5 pagamentos            P6 materiais usados
--   P7 estoque             P8 cancelamentos         P9 acesso aos prontuários
-- Processos incluídos após a correção da Entrega 1: confirmação e faltas,
-- compra de materiais. As metas dos KPIs são referências do setor a
-- validar com a clínica.
-- Variáveis de referência (altere @data_ref para simular outro dia):
-- ---------------------------------------------------------------------
SET @data_ref = '2026-11-04';
SET @ref_menos_90 = DATE_SUB(@data_ref, INTERVAL 90 DAY);
SET @ref_mais_7 = DATE_ADD(@data_ref, INTERVAL 7 DAY);
SET @ref_mais_60 = DATE_ADD(@data_ref, INTERVAL 60 DAY);
SET @inicio_mes = '2026-10-01';
SET @fim_mes = '2026-10-31';
SET @dia_livre = '2026-11-05';
SET @id_paciente = 12;

-- G01 — Quais consultas estão marcadas para os próximos 7 dias, por dentista, e quais já foram confirmadas?
-- Atende: P1 (organização dos agendamentos e horários) e confirmação de consultas (RN49)
SELECT d.nome_completo AS dentista, c.data_consulta, c.hora_consulta, c.duracao_prevista,
       p.nome_completo AS paciente, c.tipo_consulta, c.status
FROM Consulta c
JOIN Dentista d ON d.id_dentista = c.id_dentista
JOIN Paciente p ON p.id_paciente = c.id_paciente
WHERE c.status IN ('agendada', 'confirmada') AND c.data_consulta BETWEEN @data_ref AND @ref_mais_7
ORDER BY c.data_consulta, c.hora_consulta, d.nome_completo;

-- G02 — Quais horários (de hora em hora) estão livres para cada dentista em @dia_livre?
-- Atende: P1 (horários disponíveis, RF03)
SELECT d.nome_completo AS dentista, s.hora AS horario_livre
FROM Dentista d
JOIN Horario_atendimento h ON h.id_dentista = d.id_dentista AND h.dia_semana = WEEKDAY(@dia_livre) + 1
JOIN (SELECT TIME('08:00:00') AS hora UNION ALL SELECT TIME('09:00:00') UNION ALL SELECT TIME('10:00:00')
      UNION ALL SELECT TIME('11:00:00') UNION ALL SELECT TIME('14:00:00') UNION ALL SELECT TIME('15:00:00')
      UNION ALL SELECT TIME('16:00:00') UNION ALL SELECT TIME('17:00:00')) s
      ON s.hora >= h.hora_inicio AND s.hora < h.hora_fim
LEFT JOIN Consulta c ON c.id_dentista = d.id_dentista AND c.data_consulta = @dia_livre AND c.status <> 'cancelada'
      AND TIME_TO_SEC(s.hora) < TIME_TO_SEC(c.hora_consulta) + c.duracao_prevista * 60
      AND TIME_TO_SEC(c.hora_consulta) < TIME_TO_SEC(s.hora) + 3600
WHERE c.id_consulta IS NULL
ORDER BY d.nome_completo, s.hora;

-- G03 — Quantos pacientes novos foram cadastrados por mês?
-- Atende: P2 (controle dos dados dos pacientes). Usa a data de criação do prontuário como data de cadastro.
SELECT DATE_FORMAT(data_criacao, '%Y-%m') AS mes, COUNT(*) AS novos_pacientes
FROM Prontuario
GROUP BY DATE_FORMAT(data_criacao, '%Y-%m')
ORDER BY mes;

-- G04 — Qual o percentual de pacientes ativos (consulta realizada nos últimos 90 dias)?
-- Atende: P2 (controle dos dados dos pacientes) — KPI: percentual de pacientes ativos (meta: >= 60%)
SELECT COUNT(*) AS total_pacientes,
       SUM(CASE WHEN ult.ultima >= @ref_menos_90 THEN 1 ELSE 0 END) AS ativos_90_dias,
       SUM(CASE WHEN ult.ultima IS NULL THEN 1 ELSE 0 END) AS nunca_realizaram_consulta,
       ROUND(100.0 * SUM(CASE WHEN ult.ultima >= @ref_menos_90 THEN 1 ELSE 0 END) / COUNT(*), 1) AS percentual_ativos
FROM Paciente p
LEFT JOIN (SELECT id_paciente, MAX(data_consulta) AS ultima
           FROM Consulta WHERE status = 'realizada' GROUP BY id_paciente) ult
       ON ult.id_paciente = p.id_paciente;

-- G05 — Qual o histórico completo (consultas e procedimentos) de um paciente?
-- Atende: P3 (organização dos prontuários e históricos)
SELECT 'consulta' AS tipo_registro, c.data_consulta AS data_registro, c.tipo_consulta AS descricao,
       d.nome_completo AS dentista, c.status AS situacao, NULL AS valor
FROM Consulta c
JOIN Dentista d ON d.id_dentista = c.id_dentista
WHERE c.id_paciente = @id_paciente
UNION ALL
SELECT 'procedimento', pr.data_procedimento, pr.nome_procedimento, d.nome_completo, 'realizado', pr.valor_cobrado
FROM Procedimento pr
JOIN Consulta c ON c.id_consulta = pr.id_consulta
JOIN Dentista d ON d.id_dentista = c.id_dentista
WHERE c.id_paciente = @id_paciente
ORDER BY data_registro, tipo_registro;

-- G06 — Quantos procedimentos cada dentista realizou por mês e qual o valor cobrado?
-- Atende: P4 (registro e acompanhamento dos procedimentos)
SELECT DATE_FORMAT(pr.data_procedimento, '%Y-%m') AS mes, d.nome_completo AS dentista,
       COUNT(*) AS procedimentos, SUM(pr.valor_cobrado) AS valor_total
FROM Procedimento pr
JOIN Consulta c ON c.id_consulta = pr.id_consulta
JOIN Dentista d ON d.id_dentista = c.id_dentista
GROUP BY DATE_FORMAT(pr.data_procedimento, '%Y-%m'), d.id_dentista, d.nome_completo
ORDER BY mes, dentista;

-- G07 — Quais procedimentos têm saldo em aberto (pagamento pendente ou sem pagamento registrado)?
-- Atende: P5 (controle de pagamentos e pendências) — KPI: valor em aberto (meta: nenhum saldo com mais de 30 dias)
SELECT pa.nome_completo AS paciente, pr.nome_procedimento, pr.data_procedimento, pr.valor_cobrado,
       IFNULL(SUM(CASE WHEN pg.status_pagamento = 'pago' THEN pg.valor END), 0) AS total_pago,
       pr.valor_cobrado - IFNULL(SUM(CASE WHEN pg.status_pagamento = 'pago' THEN pg.valor END), 0) AS saldo_em_aberto,
       DATEDIFF(@data_ref, pr.data_procedimento) AS dias_em_aberto
FROM Procedimento pr
JOIN Consulta c ON c.id_consulta = pr.id_consulta
JOIN Paciente pa ON pa.id_paciente = c.id_paciente
LEFT JOIN Pagamento pg ON pg.id_procedimento = pr.id_procedimento
WHERE pr.valor_cobrado IS NOT NULL AND pr.data_procedimento <= @data_ref
GROUP BY pr.id_procedimento, pa.nome_completo, pr.nome_procedimento, pr.data_procedimento, pr.valor_cobrado
HAVING saldo_em_aberto > 0
ORDER BY saldo_em_aberto DESC, pr.data_procedimento
LIMIT 20;

-- G08 — Quanto foi recebido por mês e por forma de pagamento?
-- Atende: P5 (controle de pagamentos) — KPI: faturamento recebido (acompanhamento mensal, sem meta definida pela clínica)
SELECT DATE_FORMAT(data_pagamento, '%Y-%m') AS mes, forma_pagamento, COUNT(*) AS lancamentos, SUM(valor) AS total_recebido
FROM Pagamento
WHERE status_pagamento = 'pago'
GROUP BY DATE_FORMAT(data_pagamento, '%Y-%m'), forma_pagamento
ORDER BY mes, total_recebido DESC;

-- G09 — Quais materiais são mais usados em cada tipo de procedimento?
-- Atende: P6 (controle dos materiais usados nos procedimentos)
SELECT pr.nome_procedimento, m.nome_material, SUM(pm.quantidade_utilizada) AS total_utilizado, m.unidade
FROM Procedimento_Material pm
JOIN Procedimento pr ON pr.id_procedimento = pm.id_procedimento
JOIN Material m ON m.id_material = pm.id_material
GROUP BY pr.nome_procedimento, m.id_material, m.nome_material, m.unidade
ORDER BY pr.nome_procedimento, total_utilizado DESC;

-- G10 — Quais materiais estão com estoque no mínimo ou abaixo, ou com validade vencida ou nos próximos 60 dias?
-- Atende: P7 (controle do estoque de materiais) — KPI: materiais em risco (meta: 0)
SELECT nome_material, unidade, quantidade_estoque, estoque_minimo, data_validade,
       CASE WHEN quantidade_estoque <= estoque_minimo AND data_validade <= @ref_mais_60 THEN 'estoque baixo e validade próxima ou vencida'
            WHEN quantidade_estoque <= estoque_minimo THEN 'estoque baixo'
            ELSE 'validade próxima ou vencida' END AS alerta
FROM Material
WHERE quantidade_estoque <= estoque_minimo OR data_validade <= @ref_mais_60
ORDER BY alerta, nome_material;

-- G11 — Qual a taxa de cancelamento de consultas por mês e por dentista?
-- Atende: P8 (cancelamentos e remarcações) — KPI: taxa de cancelamento (meta: <= 15% ao mês)
SELECT DATE_FORMAT(c.data_consulta, '%Y-%m') AS mes, d.nome_completo AS dentista, COUNT(*) AS total_consultas,
       SUM(CASE WHEN c.status = 'cancelada' THEN 1 ELSE 0 END) AS canceladas,
       ROUND(100.0 * SUM(CASE WHEN c.status = 'cancelada' THEN 1 ELSE 0 END) / COUNT(*), 1) AS taxa_cancelamento_pct
FROM Consulta c
JOIN Dentista d ON d.id_dentista = c.id_dentista
GROUP BY DATE_FORMAT(c.data_consulta, '%Y-%m'), d.id_dentista, d.nome_completo
ORDER BY mes, dentista;

-- G12 — Quantas remarcações foram registradas na auditoria por mês?
-- Atende: P8 (cancelamentos e remarcações)
SELECT DATE_FORMAT(data_hora, '%Y-%m') AS mes, COUNT(*) AS remarcacoes
FROM Log_auditoria
WHERE tipo_acao = 'REMARCACAO'
GROUP BY DATE_FORMAT(data_hora, '%Y-%m')
ORDER BY mes;

-- G13 — Quem acessou prontuários, de que forma e quantas vezes?
-- Atende: P9 (controle dos acessos aos prontuários)
SELECT u.nome_usuario, u.perfil_acesso, a.tipo_acesso, COUNT(*) AS acessos,
       MIN(a.data_acesso) AS primeiro_acesso, MAX(a.data_acesso) AS ultimo_acesso
FROM Acesso_prontuario a
JOIN Usuario u ON u.id_usuario = a.id_usuario
GROUP BY u.id_usuario, u.nome_usuario, u.perfil_acesso, a.tipo_acesso
ORDER BY acessos DESC;

-- G14 — Qual o ticket médio de cada tipo de procedimento?
-- Atende: P4 (acompanhamento dos procedimentos) — KPI: ticket médio por procedimento (acompanhamento mensal, sem meta)
SELECT nome_procedimento, COUNT(*) AS quantidade, ROUND(AVG(valor_cobrado), 2) AS ticket_medio,
       MIN(valor_cobrado) AS menor_valor, MAX(valor_cobrado) AS maior_valor
FROM Procedimento
WHERE valor_cobrado IS NOT NULL
GROUP BY nome_procedimento
ORDER BY ticket_medio DESC;

-- G15 — Quantas consultas foram realizadas por dia de atendimento em outubro?
-- Atende: P1 (organização dos agendamentos) — KPI: atendimentos por dia (acompanhamento; capacidade informada na Entrega 1: até 9 por dia)
SELECT COUNT(*) AS consultas_realizadas, COUNT(DISTINCT data_consulta) AS dias_com_atendimento,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT data_consulta), 1) AS media_por_dia
FROM Consulta
WHERE status = 'realizada' AND data_consulta BETWEEN @inicio_mes AND @fim_mes;

-- G16 — Qual a taxa de ocupação da agenda de cada dentista em outubro?
-- Atende: P1 (organização dos agendamentos e horários) — KPI: ocupação da agenda (meta: >= 70%)
-- Capacidade = horas de Horario_atendimento (RN42) em cada dia do mês, sem o feriado de 12/10
-- (a clínica fecha em feriados nacionais); uso = duração das consultas realizadas.
WITH RECURSIVE dias AS (
    SELECT CAST(@inicio_mes AS DATE) AS dia
    UNION ALL
    SELECT DATE_ADD(dia, INTERVAL 1 DAY) FROM dias WHERE dia < @fim_mes
),
capacidade AS (
    SELECT h.id_dentista, SUM(TIME_TO_SEC(TIMEDIFF(h.hora_fim, h.hora_inicio)) / 60) AS minutos_disponiveis
    FROM dias
    JOIN Horario_atendimento h ON h.dia_semana = WEEKDAY(dias.dia) + 1
    WHERE dias.dia <> '2026-10-12'
    GROUP BY h.id_dentista
),
uso AS (
    SELECT id_dentista, SUM(duracao_prevista) AS minutos_usados
    FROM Consulta
    WHERE status = 'realizada' AND data_consulta BETWEEN @inicio_mes AND @fim_mes
    GROUP BY id_dentista
)
SELECT d.nome_completo AS dentista, cap.minutos_disponiveis,
       COALESCE(u.minutos_usados, 0) AS minutos_usados,
       ROUND(100 * COALESCE(u.minutos_usados, 0) / cap.minutos_disponiveis, 1) AS ocupacao_percentual
FROM Dentista d
JOIN capacidade cap ON cap.id_dentista = d.id_dentista
LEFT JOIN uso u ON u.id_dentista = d.id_dentista
ORDER BY d.nome_completo;

-- G17 — Quantas consultas ocorreram por mês, por status?
-- Atende: P1 e P8 (agendamentos, cancelamentos e faltas) — KPI: consultas por período (acompanhamento mensal)
SELECT DATE_FORMAT(data_consulta, '%Y-%m') AS mes, status, COUNT(*) AS consultas
FROM Consulta
GROUP BY DATE_FORMAT(data_consulta, '%Y-%m'), status
ORDER BY mes, status;

-- G18 — Quais são os procedimentos mais realizados?
-- Atende: P4 (registro e acompanhamento dos procedimentos) — KPI: procedimentos mais realizados (acompanhamento mensal)
SELECT nome_procedimento, COUNT(*) AS quantidade, SUM(valor_cobrado) AS valor_total
FROM Procedimento
GROUP BY nome_procedimento
ORDER BY quantidade DESC, nome_procedimento
LIMIT 10;

-- G19 — Qual a taxa de faltas por mês e por dentista?
-- Atende: P1 e P8 (confirmação de consultas e faltas, RN49 e RN50) — KPI: taxa de faltas (meta: <= 10% ao mês)
-- Considera só consultas já ocorridas ou perdidas (realizadas + faltas).
SELECT DATE_FORMAT(c.data_consulta, '%Y-%m') AS mes, d.nome_completo AS dentista,
       SUM(CASE WHEN c.status IN ('realizada', 'falta') THEN 1 ELSE 0 END) AS consultas_ocorridas,
       SUM(CASE WHEN c.status = 'falta' THEN 1 ELSE 0 END) AS faltas,
       ROUND(100.0 * SUM(CASE WHEN c.status = 'falta' THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN c.status IN ('realizada', 'falta') THEN 1 ELSE 0 END), 0), 1) AS taxa_faltas_pct
FROM Consulta c
JOIN Dentista d ON d.id_dentista = c.id_dentista
WHERE c.data_consulta <= @data_ref
GROUP BY DATE_FORMAT(c.data_consulta, '%Y-%m'), d.id_dentista, d.nome_completo
ORDER BY mes, dentista;

-- G20 — Quanto foi comprado de cada material por mês e de qual fornecedor, comparado ao consumo?
-- Atende: P7 (controle do estoque) e compra de materiais (RN51)
SELECT co.mes, m.nome_material, co.fornecedor, co.quantidade_comprada, m.unidade,
       COALESCE(us.consumo, 0) AS consumo_no_mes
FROM (SELECT DATE_FORMAT(data_entrada, '%Y-%m') AS mes, id_material, fornecedor, SUM(quantidade) AS quantidade_comprada
      FROM Entrada_estoque
      WHERE fornecedor <> 'Saldo inicial (inventário)'
      GROUP BY DATE_FORMAT(data_entrada, '%Y-%m'), id_material, fornecedor) co
JOIN Material m ON m.id_material = co.id_material
LEFT JOIN (SELECT DATE_FORMAT(data_utilizacao, '%Y-%m') AS mes, id_material, SUM(quantidade_utilizada) AS consumo
           FROM Procedimento_Material
           GROUP BY DATE_FORMAT(data_utilizacao, '%Y-%m'), id_material) us
       ON us.mes = co.mes AND us.id_material = co.id_material
ORDER BY co.mes, m.nome_material;



-- ---------------------------------------------------------------------
-- 8. CONSULTAS DE AUDITORIA
-- Cada consulta deve retornar ZERO linhas quando os dados estão consistentes.
-- Exceções plantadas de propósito (uma ocorrência cada): A01, A05, A08, A12 e A14.
-- ---------------------------------------------------------------------

-- A01 — Existem consultas sobrepostas para o mesmo dentista?
-- Verifica: RN10 (impedir consultas sobrepostas)
SELECT a.id_consulta AS consulta_a, b.id_consulta AS consulta_b, d.nome_completo AS dentista, a.data_consulta,
       a.hora_consulta AS inicio_a, a.duracao_prevista AS duracao_a, b.hora_consulta AS inicio_b, b.duracao_prevista AS duracao_b
FROM Consulta a
JOIN Consulta b ON b.id_dentista = a.id_dentista AND b.data_consulta = a.data_consulta AND a.id_consulta < b.id_consulta
JOIN Dentista d ON d.id_dentista = a.id_dentista
WHERE a.status <> 'cancelada' AND b.status <> 'cancelada'
  AND TIME_TO_SEC(a.hora_consulta) < TIME_TO_SEC(b.hora_consulta) + b.duracao_prevista * 60
  AND TIME_TO_SEC(b.hora_consulta) < TIME_TO_SEC(a.hora_consulta) + a.duracao_prevista * 60;

-- A02 — Existe consulta marcada fora dos horários de atendimento do dentista?
-- Verifica: RN09 e RN42 (disponibilidade e horários de atendimento)
SELECT c.id_consulta, d.nome_completo AS dentista, c.data_consulta, c.hora_consulta, c.duracao_prevista
FROM Consulta c
JOIN Dentista d ON d.id_dentista = c.id_dentista
WHERE c.status <> 'cancelada'
  AND NOT EXISTS (SELECT 1 FROM Horario_atendimento h
                  WHERE h.id_dentista = c.id_dentista AND h.dia_semana = WEEKDAY(c.data_consulta) + 1
                    AND c.hora_consulta >= h.hora_inicio
                    AND TIME_TO_SEC(c.hora_consulta) + c.duracao_prevista * 60 <= TIME_TO_SEC(h.hora_fim));

-- A03 — Existe consulta marcada como realizada ou falta com data futura?
-- Verifica: RN15 e RN50 (só é realizada ou falta depois que o horário passou)
SELECT id_consulta, id_paciente, id_dentista, data_consulta, status
FROM Consulta
WHERE status IN ('realizada', 'falta') AND data_consulta > @data_ref;

-- A04 — Existe procedimento com data diferente da data da consulta em que foi feito?
-- Verifica: RN19 e RN35 (todo procedimento é feito durante a sua consulta)
SELECT pr.id_procedimento, pr.id_consulta, pr.data_procedimento, c.data_consulta
FROM Procedimento pr
JOIN Consulta c ON c.id_consulta = pr.id_consulta
WHERE pr.data_procedimento <> c.data_consulta;

-- A05 — Existe procedimento com pagamentos confirmados acima do valor cobrado?
-- Verifica: RN25 e RN28 (pagamentos de um procedimento e correção financeira)
SELECT pr.id_procedimento, pr.nome_procedimento, pr.valor_cobrado, SUM(pg.valor) AS total_pago
FROM Procedimento pr
JOIN Pagamento pg ON pg.id_procedimento = pr.id_procedimento AND pg.status_pagamento = 'pago'
WHERE pr.valor_cobrado IS NOT NULL
GROUP BY pr.id_procedimento, pr.nome_procedimento, pr.valor_cobrado
HAVING SUM(pg.valor) > pr.valor_cobrado;

-- A06 — Existe paciente sem prontuário?
-- Verifica: RN05 (cada paciente possui exatamente um prontuário)
SELECT p.id_paciente, p.nome_completo
FROM Paciente p
LEFT JOIN Prontuario pr ON pr.id_paciente = p.id_paciente
WHERE pr.id_prontuario IS NULL;

-- A07 — Existe dentista sem conta de usuário?
-- Verifica: premissa de escopo (cada dentista cadastrado tem uma conta individual) e RN29
SELECT d.id_dentista, d.nome_completo
FROM Dentista d
LEFT JOIN Usuario u ON u.id_dentista = d.id_dentista
WHERE u.id_usuario IS NULL;

-- A08 — Existe material usado em procedimento depois da data de validade?
-- Verifica: RN40 (material vencido não deve ser usado)
SELECT pm.id_procedimento, m.nome_material, m.data_validade, pm.data_utilizacao
FROM Procedimento_Material pm
JOIN Material m ON m.id_material = pm.id_material
WHERE pm.data_utilizacao > m.data_validade;

-- A09 — Existe alteração de prontuário feita por usuário da recepção?
-- Verifica: RN21 (recepção não altera registros clínicos)
SELECT a.id_acesso, u.nome_usuario, u.perfil_acesso, a.id_prontuario, a.data_acesso
FROM Acesso_prontuario a
JOIN Usuario u ON u.id_usuario = a.id_usuario
WHERE a.tipo_acesso = 'alteracao' AND u.perfil_acesso = 'recepcao';

-- A10 — Existe procedimento vinculado a uma consulta que não foi realizada?
-- Verifica: RN19 (procedimento só em consulta realizada), RN12 (cancelada) e RN50 (falta)
SELECT pr.id_procedimento, pr.nome_procedimento, c.id_consulta, c.data_consulta, c.status
FROM Procedimento pr
JOIN Consulta c ON c.id_consulta = pr.id_consulta
WHERE c.status <> 'realizada';

-- A11 — Existem pacientes abaixo de 8 anos ou consultas agendadas/confirmadas com data passada?
-- Verifica a idade mínima informada pela clínica e RN50 (consulta que passou
-- precisa terminar como realizada, cancelada ou falta).
-- A auditoria usa @data_ref para manter a data de referência reproduzível.
SELECT
    'PACIENTE_MENOR_DE_8_ANOS' AS tipo_inconsistencia,
    p.id_paciente AS registro_id,
    p.nome_completo AS identificacao,
    CONCAT('Nascimento: ', DATE_FORMAT(p.data_nascimento, '%d/%m/%Y'),
           '; idade na referência: ', TIMESTAMPDIFF(YEAR, p.data_nascimento, @data_ref)) AS detalhe
FROM Paciente p
WHERE TIMESTAMPDIFF(YEAR, p.data_nascimento, @data_ref) < 8

UNION ALL

SELECT
    'CONSULTA_EM_ABERTO_COM_DATA_PASSADA' AS tipo_inconsistencia,
    c.id_consulta AS registro_id,
    CONCAT('Paciente: ', p.nome_completo) AS identificacao,
    CONCAT('Data prevista: ', DATE_FORMAT(c.data_consulta, '%d/%m/%Y'),
           ' às ', TIME_FORMAT(c.hora_consulta, '%H:%i'),
           '; status: ', c.status,
           '. Revisar possível falta ou atualizar o status.') AS detalhe
FROM Consulta c
JOIN Paciente p ON p.id_paciente = c.id_paciente
WHERE c.status IN ('agendada', 'confirmada')
  AND c.data_consulta < @data_ref
ORDER BY tipo_inconsistencia, registro_id;

-- A12 — Existe paciente atendido sem consentimento LGPD registrado (ou com consentimento depois do primeiro atendimento)?
-- Verifica: RN46 (consentimento antes do primeiro atendimento, LGPD — dados de saúde)
SELECT p.id_paciente, p.nome_completo, p.data_consentimento_lgpd, MIN(c.data_consulta) AS primeiro_atendimento
FROM Paciente p
JOIN Consulta c ON c.id_paciente = p.id_paciente AND c.status = 'realizada'
GROUP BY p.id_paciente, p.nome_completo, p.data_consentimento_lgpd
HAVING p.data_consentimento_lgpd IS NULL OR p.data_consentimento_lgpd > MIN(c.data_consulta);

-- A13 — Existe acesso a prontuário feito por usuário sem permissão?
-- Verifica: RN48 (só usuário com acessa_prontuario = TRUE abre prontuário) e RN47 (sigilo)
SELECT a.id_acesso, u.nome_usuario, u.perfil_acesso, a.id_prontuario, a.data_acesso, a.tipo_acesso
FROM Acesso_prontuario a
JOIN Usuario u ON u.id_usuario = a.id_usuario
WHERE u.acessa_prontuario = FALSE;

-- A14 — O estoque registrado de cada material bate com entradas − usos?
-- Verifica: RN51 (estoque = entradas registradas − usos registrados)
SELECT m.id_material, m.nome_material, m.unidade, m.quantidade_estoque,
       e.total_entradas - COALESCE(u.total_usos, 0) AS estoque_calculado,
       m.quantidade_estoque - (e.total_entradas - COALESCE(u.total_usos, 0)) AS diferenca
FROM Material m
JOIN (SELECT id_material, SUM(quantidade) AS total_entradas FROM Entrada_estoque GROUP BY id_material) e
     ON e.id_material = m.id_material
LEFT JOIN (SELECT id_material, SUM(quantidade_utilizada) AS total_usos FROM Procedimento_Material GROUP BY id_material) u
     ON u.id_material = m.id_material
WHERE m.quantidade_estoque <> e.total_entradas - COALESCE(u.total_usos, 0);

-- =====================================================================
-- Fim do script
-- =====================================================================
