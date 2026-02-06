# Manual: Executando PJeCalc no Linux (Debian/Ubuntu)

Este guia descreve como configurar o **PJeCalc Cidadão** (originalmente para Windows) para rodar nativamente no Linux, solucionando problemas de compatibilidade do Java e criando um atalho na área de trabalho.

## 📋 Pré-requisitos
- Sistema Operacional: Debian, Ubuntu ou derivados.
- Pacotes básicos para interface gráfica: `zenity` (para janelas de aviso) e `xdg-utils` (para abrir navegador).

## 🚀 Passo a Passo da Instalação

### 1. Preparar a Pasta
Extraia o arquivo do PJeCalc (ex: `pjecalc-windows64-2.15.1`) para sua pasta de documentos. Vamos assumir que o caminho é:
`/home/seu_usuario/Documentos/pjecalc-windows64-2.15.1`

### 2. Resolver o Problema do Java (Erro 404 / Compatibilidade)
O PJeCalc foi feito para **Java 8**. Sistemas Linux modernos usam Java 11, 17 ou 21, o que causa erros (como "HTTP 404" ou falhas ao abrir).
A solução é baixar uma versão portátil do Java 8 e colocá-la dentro da pasta do PjeCalc.

1. Abra o terminal na pasta do PJeCalc.
2. Crie uma pasta para o Java:
   ```bash
   mkdir -p bin/jre-linux
   ```
3. Baixe o OpenJDK 8 (Temurin) e extraia:
   ```bash
   wget -O /tmp/java8.tar.gz "https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jre/hotspot/normal/eclipse?project=jdk"
   tar -xzf /tmp/java8.tar.gz -C bin/jre-linux --strip-components=1
   ```
   *Isso garante que o PJeCalc use o Java correto sem bagunçar o Java do seu sistema.*

### 3. Criar Script de Inicialização
Crie um arquivo chamado `iniciarPjeCalc.sh` dentro da pasta do programa:

```bash
#!/bin/bash
cd "$(dirname "$0")"

# Define o Java local (portátil)
JAVA_CMD="./bin/jre-linux/bin/java"

# Verifica se o Java local existe
if [ ! -x "$JAVA_CMD" ]; then
    # Tenta usar o do sistema se o local falhar
    if command -v java &> /dev/null; then
        JAVA_CMD="java"
    else
        zenity --error --text="Java não encontrado. Verifique a instalação do Java 8 na pasta bin/jre-linux."
        exit 1
    fi
fi

# Mata instâncias anteriores travadas
pkill -f "pjecalc.jar"

LOG_FILE="/tmp/pjecalc_startup.log"
> "$LOG_FILE"

# Inicia o PJeCalc
"$JAVA_CMD" \
     -splash:pjecalc_splash.gif \
     -Duser.timezone=GMT-3 \
     -Dfile.encoding=ISO-8859-1 \
     -Dseguranca.pjecalc.tokenServicos=pW4jZ4g9VM5MCy6FnB5pEfQe \
     -Dseguranca.pjekz.servico.contexto="https://pje.trtXX.jus.br/pje-seguranca" \
     -Xms1024m -Xmx2048m \
     -jar bin/pjecalc.jar > "$LOG_FILE" 2>&1 &

PID=$!

zenity --info --timeout=5 --text="Iniciando PJeCalc...\nAguarde a abertura do navegador." &

# Aguarda o servidor iniciar e captura a URL correta (Porta dinâmica)
MAX_ATTEMPTS=60
COUNT=0
URL=""

while [ $COUNT -lt $MAX_ATTEMPTS ]; do
    if grep -q "URL HTTP:" "$LOG_FILE"; then
        URL=$(grep "URL HTTP:" "$LOG_FILE" | head -n 1 | awk '{print $4}')
        break
    fi
    sleep 1
    COUNT=$((COUNT+1))
done

if [ -n "$URL" ]; then
    sleep 2
    xdg-open "$URL"
else
    zenity --error --text="Falha ao iniciar PJeCalc.\\nVerifique o log em $LOG_FILE"
fi

wait $PID
```

Dê permissão de execução:
```bash
chmod +x iniciarPjeCalc.sh
```

### 4. Criar Atalho na Área de Trabalho (Menu)
Para converter o ícone original (`icone_calc.ico`) para PNG (Linux não lê .ico bem), instale o `imagemagick` e rode:
```bash
sudo apt install imagemagick
convert icone_calc.ico pjecalc.png
```

Crie o arquivo atalho em `~/.local/share/applications/PJeCalc.desktop`:
*(Edite o caminho `/home/seu_usuario/...` conforme necessário)*

```ini
[Desktop Entry]
Version=1.0
Name=PJeCalc
Comment=Calculo Trabalhista
Exec=/home/seu_usuario/Documentos/pjecalc-windows64-2.15.1/iniciarPjeCalc.sh
Icon=/home/seu_usuario/Documentos/pjecalc-windows64-2.15.1/pjecalc-0.png
Terminal=false
Type=Application
Categories=Office;Java;
Path=/home/seu_usuario/Documentos/pjecalc-windows64-2.15.1
StartupNotify=true
```

## ✅ Conclusão
Agora você pode abrir o PJeCalc diretamente pelo menu de aplicativos do seu Linux. Ele usará com segurança o Java 8 embutido, abrirá o navegador automaticamente na porta correta (mesmo que mude) e mostrará feedback visual durante o carregamento.
