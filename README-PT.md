# PBasic

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Interpretador PBasic escrito em assembly MIPS. Roda nos simuladores SPIM e MARS.

## Destaques

- Dialeto PBasic com suporte a LET, PRINT, IF/THEN, GOTO, GOSUB/RETURN, LIST, NEW, EXIT, REM, INPUT, RUN, END, FREE, RND e ABS
- Avaliador de expressões com análise de descida recursiva (+, -, *, /, parênteses, menos unário)
- 26 variáveis (A-Z) armazenadas como inteiros de 32 bits; `*` `/` são 16 bits, `+` `-` e o menos unário são 32 bits
- Área de programa de 52 KB com armazenamento de linhas tokenizadas como uma lista encadeada
- FREE relata os bytes livres entre o fim do programa e `MEM_PROG_LIMIT` (comando ou expressão)
- `INPUT "prompt"; VAR` (ponto e vírgula após o prompt); `RND(x)` devolve 1..x
- I/O via chamadas de sistema (syscalls) padrão do SPIM/MARS (modo `mapped_io` para entrada interativa)

## Visão Geral

O PBasic começou em 2014 como um projeto de paixão durante a minha faculdade de Ciência da Computação.

Originalmente escrito em assembly MIPS para rodar no simulador MARS, criei o projeto como uma forma de demonstrar aos meus colegas de classe que a linguagem assembly MIPS poderia ser usada para construir softwares práticos e funcionais — como um interpretador BASIC completo —, indo além de simples exercícios acadêmicos.

## Pré-requisitos

- **spim** — simulador MIPS; instale com `sudo apt install spim`
- **mars** — MIPS Assembler and Runtime Simulator (opcional, baixe de [missouristate.edu/MARS](https://courses.missouristate.edu/KenVollmar/MARS/))

## Instalação

### Compilar a partir do código-fonte

```bash
git clone https://github.com/carlosrabelo/pbasic.git
cd pbasic
make build
```

## Uso

### Compilar e executar

```bash
make run                           # usa spim
make run EMULATOR=mars             # usa java -jar MARS.jar
make run EMULATOR=mars MARS_JAR=/path/MARS.jar
```

### Apenas compilar

```bash
make build
```

Isso concatena todos os módulos assembly MIPS em um único arquivo fonte:

```bash
# Rodar o código assembly MIPS no simulador SPIM
spim -mapped_io -file bin/pbasic.s

# Rodar o código assembly MIPS no simulador MARS
java -jar MARS.jar bin/pbasic.s
```

### Exemplo de sessão

```
PBasic

> 10 LET A=42
> 20 PRINT A
> 30 PRINT A*2+10
> RUN
42
94
> PRINT FREE
53196
> LIST
10 LET A=42
20 PRINT A
30 PRINT A*2+10
> NEW
OK
```

## Estrutura do Projeto

```
src/                # Fontes em assembly MIPS
demos/              # Programas BASIC de demonstração (`make test` executa 99_test.bas se o SPIM estiver instalado)
bin/                # Código fonte concatenado (ignorado no git)
Makefile            # Orquestrador de build
.make/              # Scripts auxiliares de build
```

## Desenvolvimento

```bash
make help              # Mostra os alvos disponíveis
make build             # Concatena os fontes MIPS
make test              # Compila, confere rótulos; executa 99_test.bas se o SPIM estiver instalado
make run               # Compila e executa no SPIM/MARS
make clean             # Remove os artefatos de build
```

## Licença

Este projeto está licenciado sob a Licença MIT — veja [LICENSE](LICENSE) para detalhes.
