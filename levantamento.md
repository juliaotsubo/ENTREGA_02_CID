# Levantamento — E.K. Consultório Odontológico

Texto organizado pelo grupo a partir de três fontes:

1. levantamento da Entrega 1;
2. respostas da responsável enviadas por mensagem em 01/11/2026;
3. entrevista no consultório em 02/11/2026 ([`entrevista_EK_consultorio_odontologico.pdf`](entrevista_EK_consultorio_odontologico.pdf)).

**Entrevista de 02/11/2026:** entrevistada a Dra. Kátia Pinheiro, cirurgiã-dentista e responsável pelo consultório, no próprio consultório. Visita presencial feita por Karine dos Santos Nogueira; os demais integrantes participaram da conversa com a Dra. Kátia pelo WhatsApp. Evidências: foto da visita, foto do ambiente de atendimento e prints da conversa de 01/11/2026 em [`../evidencias/`](../evidencias/).

## 1. A organização

Consultório odontológico particular de pequeno porte no Butantã (São Paulo/SP), administrado pelas cirurgiãs-dentistas responsáveis, Dra. Kátia Pinheiro e Dra. Elielma Gomes. A equipe tem 3 cirurgiãs-dentistas de Clínica Geral e 1 funcionária de atendimento telefônico. O atendimento é só particular, sem planos odontológicos.

## 2. Volume

| Dado | Valor | Fonte |
|---|---|---|
| Pacientes por dia | 5 a 9 (média de 6 a 7) | E1 e mensagem de 01/11 |
| Dias de atendimento | Segunda a sábado (6 dias por semana) | Mensagem de 01/11 e entrevista |
| Pacientes cadastrados | Cerca de 30, contando os que já terminaram o tratamento | Entrevista |
| Pacientes recorrentes | 7 a 8, em geral com tratamento em andamento | Entrevista |
| Compras de material | Mensais | Entrevista |

> **Decisão do grupo:** o "5 a 9 pacientes por dia" da Entrega 1 era a capacidade informada na época. A entrevista de 02/11 trouxe o volume real (cerca de 30 pacientes cadastrados, 7 a 8 recorrentes), que dá em torno de 2 a 3 atendimentos por dia. A massa de dados foi dimensionada pelo volume real: 30 pacientes e 57 consultas realizadas em outubro.

## 3. Cadastro, prontuário e avaliação

- No primeiro atendimento é feita uma anamnese, registrada no prontuário.
- A avaliação odontológica define os tratamentos e os valores. Ela fica no prontuário, junto com a anamnese e o orçamento.
- Os valores são definidos pelas Dras. Kátia e Elielma. Referências: profilaxia cerca de R$ 250; restauração de R$ 300 a R$ 350, conforme o dente e a complexidade.
- O paciente assina um termo de consentimento em todos os procedimentos.
- A clínica atende crianças a partir de 8 anos, sempre com o responsável legal (pai ou mãe), que assina os documentos.
- Só a Dra. Kátia e a Dra. Elielma acessam os prontuários.
- Segundo a clínica, os prontuários são guardados por 1 ano. Esse prazo é menor que o orientado pelo CFO (no mínimo 20 anos); o projeto segue a norma (RN47) e registra a divergência como recomendação à clínica.

## 4. Agenda, confirmação, faltas e cancelamentos

- Atendimento de segunda a sábado. Os horários de cada dentista ainda não foram confirmados.
- Duração: profilaxia cerca de 20 minutos; tratamento de canal de 30 a 40 minutos.
- As consultas são confirmadas antes pelo WhatsApp.
- Quando o paciente falta, a clínica marca uma nova consulta.
- Atraso grande: a consulta é remarcada, em geral para a semana seguinte.
- Cancelamento ou impossibilidade de comparecer: a consulta é remarcada. O horário liberado é oferecido a pacientes que aguardam avaliação ou orçamento.
- O motivo do cancelamento não é registrado.

## 5. Procedimentos e materiais

- Os materiais usados em cada procedimento são anotados.
- O estoque e a validade são controlados pela equipe, verificando com frequência o que está acabando.
- As compras são mensais: a equipe faz uma lista do que está em falta e compra na Dental, por contato com o vendedor.

## 6. Pagamentos

- Dinheiro e cartão, com parcelamento em até 3 vezes.
- A cobrança é por procedimento; em geral o paciente paga a cada atendimento.
- Emissão de recibo: não confirmada.

## 7. O que mudou em relação à Entrega 1

| Tema | Entrega 1 | Agora |
|---|---|---|
| Confirmação e faltas | Não levantado | Confirmação pelo WhatsApp; falta gera nova marcação |
| Compras de material | Não levantado | Mensais, por lista de faltas, na Dental |
| Acesso aos prontuários | "Usuário identificado" | Só as duas dentistas responsáveis |
| Consentimento | Não levantado | Termo assinado em todos os procedimentos |
| Menores | Não levantado | A partir de 8 anos, com responsável |
| Orçamento | Não levantado | Fica no prontuário com a anamnese |
| Guarda do prontuário | Não levantado | 1 ano (a rever) |

## 8. Pontos ainda não confirmados

- Horários exatos de cada dentista.
- Emissão de recibo.
- Como o orçamento é registrado (documento próprio? aprovado pelo paciente?).
- Nenhum ponto da caracterização ficou sem confirmação; as divergências (volume, guarda do prontuário) estão registradas acima.

## 9. Achados da observação no local

Observado pela Karine na visita de 02/11/2026, separado do que foi respondido na entrevista:

| O que foi observado | O que isso significa para o modelo |
|---|---|
| A agenda é controlada em papel | Confirma o problema P1; o sistema passa a registrar agendamento, confirmação, falta, cancelamento e remarcação (Consulta e Log_auditoria) |
| As fichas dos pacientes ficam com a doutora | Confirma o acesso restrito aos prontuários (RN48, `acessa_prontuario`) |
| O estoque fica num espaço exclusivo para os materiais | Base para o controle de Material, Entrada_estoque e uso por procedimento |
| Produtos e utensílios são higienizados e descartados de forma correta | Rotina física de biossegurança, sem dado de gestão: reforça a decisão de não modelar a esterilização |
