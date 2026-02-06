# PJeCalc para Linux (Instalador Automático)

Este repositório contém scripts de automação para executar o **PJeCalc Cidadão** nativamente em distribuições Linux (Debian, Ubuntu, Mint, Pop!_OS, etc).

Ele resolve automaticamente os principais problemas:
- Baixa o Java 8 (versão portátil) compatível com o PjeCalc.
- Cria os lançadores e ícones no menu do sistema.
- Abre o navegador automaticamente na porta correta.

## 📦 Como Usar

1. Baixe o PJeCalc (Windows) oficial do site do TRT.
2. Baixe/Clone este repositório **dentro** da pasta do PJeCalc.
   *(Ou copie todos os arquivos deste repositório para dentro da pasta do PJeCalc)*
3. Abra um terminal na pasta e execute:
   ```bash
   ./install.sh
   # ou
   bash install.sh
   ```
4. Siga as instruções na tela.

## 🛠 O que o script faz?
- Verifica se você tem `zenity`, `xdg-utils` e `imagemagick`.
- Baixa o **OpenJDK 8** (Temurin) para a pasta `bin/jre-linux`.
- Gera o script `iniciarPjeCalc.sh` personalizado.
- Cria o arquivo `.desktop` para integração com o menu do sistema.

## Requisitos
- Acesso à internet (para baixar o Java na primeira vez).
- Senha de superusuário (sudo) para instalar dependências se faltarem.
