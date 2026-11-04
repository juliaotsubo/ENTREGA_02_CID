# Justificativas técnicas das decisões de modelagem

**Sistema de Gestão Odontológica — E.K. Consultório Odontológico.** Versão 2 (Entrega 2), alinhada ao `docs/script.sql`. O texto completo das justificativas, com a regra de negócio de cada restrição, está na seção 1.5 do `README.md`.

## 1. Uso de chaves primárias

Cada tabela tem um identificador técnico próprio (`id_paciente`, `id_consulta` etc.), `INT AUTO_INCREMENT`. Ele não depende de atributos que podem mudar (nome, endereço, login) e mantém os relacionamentos estáveis. CPF, CRO e login são chaves candidatas e ficam garantidos por UNIQUE.

## 2. Uso de chaves estrangeiras

As FKs garantem que cada referência aponte para um registro existente: uma consulta sempre tem paciente e dentista cadastrados, todo procedimento pertence a uma consulta, todo pagamento a um procedimento e toda compra a um material. Nenhuma FK usa `ON DELETE CASCADE`: apagar um registro que ainda tem histórico é bloqueado (RN22).

## 3. Normalização e tabela associativa

Pacientes, dentistas, consultas, procedimentos, materiais, compras e pagamentos ficam em tabelas próprias, sem repetição de dados. **Procedimento_Material** resolve o N:N entre procedimentos e materiais e guarda os atributos da associação (quantidade e data de uso). **Procedimento** guarda só a consulta em que foi feito: paciente e dentista vêm dela (3FN).

## 4. Separação entre Usuario e Dentista

Os dados de autenticação e autorização (login, hash de senha, perfil e permissão de prontuário) ficam em **Usuario**; os dados profissionais (CRO, especialidade, contato) ficam em **Dentista**. Assim, a recepção tem conta sem ser dentista, e a permissão de abrir prontuário (`acessa_prontuario`) é controlada por usuário: na clínica, só duas das três dentistas têm esse acesso (RN48).

## 5. Auditoria e controle de acesso

**Log_auditoria** registra confirmações, faltas, cancelamentos, remarcações e confirmações de pagamento; **Acesso_prontuario** registra cada consulta ou alteração de prontuário. Os dois apoiam a responsabilização exigida pela LGPD (RN46 a RN48) e são conferidos pelas auditorias A09 e A13.

## 6. Recomendações da versão anterior e o que foi decidido

| Recomendação | Decisão |
|---|---|
| Definir a cardinalidade Usuario–Dentista e aplicar UNIQUE em `id_dentista` se for 1:1 | Feito: 1:1 opcional, `uq_usuario_dentista` |
| Guardar data e hora completas da consulta | Mantidos `data_consulta` (DATE) e `hora_consulta` (TIME) separados: as consultas gerenciais filtram por data e por horário de atendimento (G02, A02); juntos eles identificam o momento sem ambiguidade |
| Impedir procedimento com paciente, dentista ou consulta incompatíveis | Resolvido pelo modelo: Procedimento só tem `id_consulta`; a data é conferida pela A04 e a consulta não realizada pela A10 |
| Confirmar se pagamento é por procedimento ou por consulta | A clínica cobra por procedimento, em até 3 parcelas no cartão: Pagamento → Procedimento (1:N) |
| UNIQUE em login, CPF e CRO | Feito: `uq_usuario_login`, `uq_paciente_cpf`, `uq_dentista_cpf`, `uq_dentista_cro` |
| Definir retenção, acesso e proteção de dados pessoais e clínicos | RN46 (consentimento LGPD, A12), RN47 (guarda do prontuário por 20 anos, sem exclusão), RN48 (permissão de acesso, A13) |

## Conclusão

As decisões mantêm os dados consistentes, eliminam redundâncias e garantem relacionamentos confiáveis. O que o banco não garante sozinho (sobreposição de horário, estoque = entradas − usos, consentimento antes do atendimento) é verificado pelas consultas de auditoria A01 a A14 do script.
