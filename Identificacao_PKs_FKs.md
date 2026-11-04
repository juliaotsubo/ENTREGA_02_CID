# Identificação das chaves primárias e estrangeiras

**Sistema de Gestão Odontológica — E.K. Consultório Odontológico.** Versão 2 (Entrega 2), alinhada ao `docs/script.sql` e ao modelo lógico em `diagramas/modelo_logico.png`.

## 1. Conceitos

- **PK (Primary Key):** identifica unicamente cada registro de uma tabela. Não aceita nulo nem repetição.
- **FK (Foreign Key):** referencia a PK de outra tabela, implementa o relacionamento e garante a integridade referencial: o banco recusa uma referência a um registro inexistente e impede apagar um registro ainda referenciado (nenhuma FK usa `ON DELETE CASCADE`, RN22).

## 2. Identificação por tabela (13 tabelas)

| Tabela | Chave primária (PK) | Chave(s) estrangeira(s) (FK) | Observação |
|---|---|---|---|
| Paciente | id_paciente | — | `cpf` é chave candidata (UNIQUE, opcional) |
| Prontuario | id_prontuario | id_paciente → Paciente | `id_paciente` UNIQUE: um prontuário por paciente |
| Dentista | id_dentista | — | `cpf` e `cro` UNIQUE |
| Horario_atendimento | id_horario | id_dentista → Dentista | UNIQUE (id_dentista, dia_semana, hora_inicio) |
| Usuario | id_usuario | id_dentista → Dentista (opcional) | `id_dentista` UNIQUE: um dentista, uma conta; `login` UNIQUE |
| Log_auditoria | id_log | id_usuario → Usuario | |
| Acesso_prontuario | id_acesso | id_usuario → Usuario; id_prontuario → Prontuario | |
| Consulta | id_consulta | id_paciente → Paciente; id_dentista → Dentista | |
| Procedimento | id_procedimento | id_consulta → Consulta | paciente e dentista vêm da consulta (3FN) |
| Pagamento | id_pagamento | id_procedimento → Procedimento | |
| Material | id_material | — | |
| Entrada_estoque | id_entrada | id_material → Material | |
| Procedimento_Material | id_procedimento + id_material | id_procedimento → Procedimento; id_material → Material | PK composta |

## 3. Chave composta

Em **Procedimento_Material**, a PK é composta por `id_procedimento` e `id_material`, e cada um deles é também FK para sua tabela de origem. A combinação identifica o uso de um material em um procedimento e impede registrar o mesmo par duas vezes. `quantidade_utilizada` e `data_utilizacao` dependem do par inteiro (2FN).

## 4. Relacionamentos e cardinalidades

| Relacionamento | Cardinalidade (mín., máx.) | Implementação |
|---|---|---|
| Paciente — Prontuario | 1:1 — (1,1) e (1,1) | FK `Prontuario.id_paciente` NOT NULL + UNIQUE |
| Paciente — Consulta | 1:N — (1,1) e (0,n) | FK `Consulta.id_paciente` NOT NULL |
| Dentista — Consulta | 1:N — (1,1) e (0,n) | FK `Consulta.id_dentista` NOT NULL |
| Dentista — Horario_atendimento | 1:N — (1,1) e (1,n) | FK `Horario_atendimento.id_dentista` NOT NULL |
| Dentista — Usuario | 1:1 opcional — (0,1) e (1,1) | FK `Usuario.id_dentista` NULL + UNIQUE (a recepção não é dentista) |
| Consulta — Procedimento | 1:N — (1,1) e (0,n) | FK `Procedimento.id_consulta` NOT NULL |
| Procedimento — Pagamento | 1:N — (1,1) e (0,n) | FK `Pagamento.id_procedimento` NOT NULL (parcelas) |
| Procedimento — Material | N:N — (0,n) e (0,n) | tabela associativa Procedimento_Material |
| Material — Entrada_estoque | 1:N — (1,1) e (0,n) | FK `Entrada_estoque.id_material` NOT NULL |
| Usuario — Log_auditoria | 1:N — (1,1) e (0,n) | FK `Log_auditoria.id_usuario` NOT NULL |
| Usuario — Acesso_prontuario | 1:N — (1,1) e (0,n) | FK `Acesso_prontuario.id_usuario` NOT NULL |
| Prontuario — Acesso_prontuario | 1:N — (1,1) e (0,n) | FK `Acesso_prontuario.id_prontuario` NOT NULL |

## 5. O que mudou em relação à versão anterior

- **Procedimento** não tem mais `id_paciente` e `id_dentista`: a clínica confirmou que todo procedimento é feito durante uma consulta, então esses dados vêm da consulta (eliminação de dependência transitiva).
- **Usuario — Dentista** passou de "1:N conforme a FK" para **1:1 opcional**, com UNIQUE em `id_dentista`.
- **Paciente — Prontuario** passou de "1:N conforme o modelo" para **1:1**, com UNIQUE em `id_paciente`.
- Nova tabela **Entrada_estoque** (compras de material).
