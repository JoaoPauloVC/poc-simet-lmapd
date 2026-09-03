# Teste com simet-lmapd - POC local passo a passo

## Objetivo

Este documento registra o caminho usado para compilar e executar o simet-lmapd localmente, criar uma Measurement Task simples ("Hello World"), declarar a capability correspondente, montar uma Instruction local com Event/Schedule/Action e observar a execução pelo lmapctl.

Projeto: simet-lmapd

## Modelo Mental do projeto

Na raiz do projeto criamos um diretório que servirá como laboratório (lab). sua composição é:

```text
lab/  
|— bin/  
|   └── programas executáveis da POC. A presença de um programa
|						neste diretório, por si só, não faz com que
|       o lmapd o reconheça como um Task disponível.  
|  
|— capabilities/  
|    └── o que este MA declara conseguir executar.  
|  
|— config/  
|    └── Instruction/Configuração carregada pelo lmapd.  
|  
|— queue/  
|    └── workspace operacional das execuções  
|  
|— run/  
|    └── PID e estado do daemon.  
|  
|— hello.log
```

### bin/

Contém os programas executáveis que o Measurement Agent (MA) pode executar. Podem ser scripts ou binários compilados. No exemplo, o programa é hello-world.sh.

### capabilities/

Descreve o que este MA possui e está autorizado/capaz de executar. Não é a mesma coisa que uma Instruction. A capability funciona como uma espécie de catálogo/allowlist local de Measurement Tasks disponíveis no MA.

### config/

Contém a configuração carregada pelo lmapd. No nosso experimento, hello.json funciona conceitualmente como uma Instruction local: define a Task Configuration, o Event, o Schedule e a Action que será executada.

### queue/

É o workspace operacional do lmapd. O daemon cria automaticamente subdiretórios por Schedule e Action. Eles podem ficar vazios após a execução, pois arquivos temporários são limpos quando a Action termina.

### run/

Contém arquivos de estado do daemon, principalmente o PID enquanto o lmapd está ativo e o arquivo lmapd-state.json quando o estado é solicitado.

### hello.log

Não é um arquivo padrão do LMAP. Foi criado pelo nosso script de Hello World para registrar, de forma simples e persistente, cada execução da Task.

## “Montagem” do MA

### Criação do programa “hello-world”

Vamos criar um programa simples, hello-world.sh, que servirá como implementação da Task de teste "Hello World". No passo seguinte, declararemos uma capability informando ao lmapd que o MA possui essa Task disponível. O contéudo de hello-world é:

```sh
#!/bin/sh

echo "$(date) - Hello World executado pelo lmapd" >> "$(dirname "$0")/../hello.log"
```

Logo em seguida, devemos dar permissão de execução para o arquivo com:

```sh
chmod +x lab/bin/hello-world.sh
```

### Criação da Capability para o MA

O próximo passo é indicar que o MA possui a capacidade (Capability) correspondente à Task hello-world que acabamos de criar. Dentro de lab/capabilities criamos o arquivo hello-world.json, com o seguinte:

<details>
<summary>Código hello-world.json</summary>
```json
{
  "ietf-lmap-control:lmap": {
    "capabilities": {
      "tasks": {
        "task": [
          {
            "name": "hello-world",
            "program": "/CAMINHO/ABSOLUTO/ATE/lab/bin/hello-world.sh"
          }
        ]
      }
    }
  }
}
```

</details>
Para validar a sintaxe JSON, usamos o comando:

```sh
jq . lab/capabilities/hello-world.json
```

O próximo passo é indicarmos quando/como a o programa se executado. Para fins de exemplo, vamos supor que queremos que a Task seja executada a cada 15 segundos. 

### Criação da Instruction

A Capability informa apenas que o MA possui a Task disponível. Ainda é necessário informar ao lmapd o que deve ser executado e quando. Para isso, criamos lab/config/hello.json, que representa a Instruction local utilizada nesta POC.

O modelo mental da Instruction é:

Event every-15-seconds  
     → dispara o Schedule hello-schedule  
     → que contém a Action run-hello  
     → que referencia a Task Configuration hello-world  
     → que utiliza o programa hello-world.sh.

A Capability não faz parte dessa sequência de execução. Ela declara separadamente que o MA possui a Task utilizada pela Instruction.

O arquivo lab/config/hello.json utilizado nesta POC possui o seguinte conteúdo:

<details>
<summary>Código hello.json</summary>
```json
{
  "ietf-lmap-control:lmap": {
    "tasks": {
      "task": [
        {
          "name": "hello-world",
          "program": "/CAMINHO/ABSOLUTO/ATE/lab/bin/hello-world.sh"
        }
      ]
    },
    "events": {
      "event": [
        {
          "name": "every-15-seconds",
          "periodic": {
            "interval": 15
          }
        }
      ]
    },
    "schedules": {
      "schedule": [
        {
          "name": "hello-schedule",
          "start": "every-15-seconds",
          "execution-mode": "sequential",
          "action": [
            {
              "name": "run-hello",
              "task": "hello-world"
            }
          ]
        }
      ]
    }
  }
}
```

</details>
O campo program deve conter o mesmo caminho absoluto utilizado na Capability.

```bash
jq . lab/config/hello.json
```

Depois, validamos a Instruction com o próprio lmapctl:

```bash
./build/src/lmapctl \
  -j \
  -q lab/queue \
  -r lab/run \
  -c lab/config/hello.json \
  validate
```

### Inicialização do simet-lmapd

Após criar a Capability e a Instruction, podemos iniciar o daemon:

```bash
./build/src/lmapd \
  -j \
  -b lab/capabilities \
  -c lab/config/hello.json \
  -q lab/queue \
  -r lab/run
```

Quando o daemon inicia corretamente, é apresentada uma mensagem semelhante a:

```
lmapd[37452]: [DBG] lmapd_run: event loop starting
```

Em outro terminal, podemos observar as execuções do programa com:

```
tail -f lab/hello.log
```

## Consulta do estado do daemon com lmapctl

Com o lmapd em execução, podemos verificar se o daemon está ativo:

```sh
./build/src/lmapctl \
		-j \
		-q lab/queue \
		-r lab/run \
		-c lab/config/hello.json \
		running
```

Quando o daemon está ativo, o comando termina sem apresentar erro.

Também é possível consultar o estado dos Schedules e Actions:

```
./build/src/lmapctl \
  -j \
  -q lab/queue \
  -r lab/run \
  -c lab/config/hello.json \
  status
```

## O que foi criado em queue/ e run/

Com o daemon ainda rodando, para verificar os arquivo criados dentro das pasta, vamos utilizar

```sh
find lab/queue -maxdepth 3 -print
```

Com o lmapd em execução, vemos a seguinte estrutura:

```text
lab/queue
└── hello-schedule
			├── _incoming
			└── run-hello
```

- hello-schedule/ corresponde ao Schedule hello-schedule;
- run-hello/ corresponde à Action run-hello;
- \_incoming/ é utilizado internamente pelo mecanismo de movimentação/entrada de dados do workspace.

Rodando find para o diretório run, com o comando

```sh
find lab/run -maxdepth 2 -type f -print
```

vemos dois arquivos dentro da pasta

```text
lab/run/lmapd.pid
lab/run/lmapd-state.json
```

- lmapd.pid: armazena o identiicador do processo do daemon em execução;
- lmapd-state.json: representa um snapshot do estado conhecido pelo lmapd

Analisando o lmapd-state.json a fundo, vemos que ele é composto de 4 grupos importantes:

- capabilities: mostra o que o MA declara possuir como capacidade disponível (dentro de tasks). Também aparecerem informações do próprio MA, como versão do simet-lmapd e tags
- tasks: representa as Task Configurations que fazem parte da Instruction atualmente carregada;
- schedules: traz detalhes das schedules em execução, como nome, start, estado e as actions que formam o schedule
- events: eventos programados.

## Testes

### 1) Alterar 15s para 5s

#### Passo a passo

Com o lmapd rodando, usar

```sh
tail -f lab/hello.log
```

para acompanhar mudanças no arquivo hello.log.

Após confirmar a execução de 15 em 15 segundos, ir no arquivo hello.json (lab/config/hello.json) e mudar o campo “interval” de 15 para 5 e salvar, sem fazer reload no daemon. O fato de ver que o programa continua executando de 15 em 15 segundos evidencia que não basta atualizar o arquivo de configuração.

Ao derrubar o daemon e subir ele de novo, vemos que a mudança fez efeito e que o prgorama passou a executar de 5 em 5 segundos.

### 1.1) Alteração fazendo reload

Seguir o processo anterior e, depois de fazer a alteração de 15s para 5s, aplicar o comando reload do lmapctl. Fazendo isso, vemos que o daemon (terminal onde executamos o lmapd) encerra e inicializa novamente e passa a valer a mudança de 15s para 5s. Além disso, através deste processo, vemos que o pid (em lab/run/lmapd.pid) se mantém o mesmo.

### 2.1) Event periódico com `start` absoluto

Foi adicionado ao Event periódico um horário absoluto de início.

Com isso, as execuções passaram a permanecer alinhadas à grade temporal definida pelo `start`. No teste realizado, os segundos das execuções terminavam sempre em `0` ou `5`, compatível com um intervalo de 5 segundos ancorado em 10:30:00.

Isso confirma que o `lmapd` calcula as próximas ocorrências a partir da referência temporal definida no Event, inclusive após reload.