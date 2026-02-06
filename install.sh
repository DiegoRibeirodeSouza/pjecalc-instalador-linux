#!/bin/bash

# PJeCalc Linux Installer (Unofficial)
# Automates the setup of PJeCalc Cidadão on Linux (Debian/Ubuntu/Mint)

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== PJeCalc Linux Installer ===${NC}"

# 1. Verify location
if [ ! -f "bin/pjecalc.jar" ] && [ ! -f "../bin/pjecalc.jar" ]; then
    echo -e "${RED}[ERROR] PJeCalc files not found!${NC}"
    echo "Please place this folder/script INSIDE the PJeCalc installation folder."
    echo "(e.g. inside pjecalc-windows64-2.15.1)"
    exit 1
fi

# Adjust path if running from subfolder
if [ ! -f "bin/pjecalc.jar" ] && [ -f "../bin/pjecalc.jar" ]; then
    cd ..
    echo -e "${YELLOW}[INFO] Moved to parent directory: $(pwd)${NC}"
fi

APP_DIR=$(pwd)
echo -e "${GREEN}[INFO] Installation target: $APP_DIR${NC}"

# 2. Check & Install Dependencies
echo -e "${GREEN}[INFO] Checking system dependencies...${NC}"
MISSING_DEPS=""

if ! command -v zenity &> /dev/null; then MISSING_DEPS="$MISSING_DEPS zenity"; fi
if ! command -v convert &> /dev/null; then MISSING_DEPS="$MISSING_DEPS imagemagick"; fi
if ! command -v xdg-open &> /dev/null; then MISSING_DEPS="$MISSING_DEPS xdg-utils"; fi

if [ -n "$MISSING_DEPS" ]; then
    echo -e "${YELLOW}[WARN] Installing missing packages:$MISSING_DEPS${NC}"
    sudo apt-get update
    sudo apt-get install -y $MISSING_DEPS
else
    echo -e "${GREEN}[OK] All system dependencies found.${NC}"
fi

# 3. Setup Portable Java 8
if [ -x "bin/jre-linux/bin/java" ]; then
    echo -e "${GREEN}[OK] Embedded Java 8 already exists.${NC}"
else
    echo -e "${GREEN}[INFO] Downloading OpenJDK 8 (Temurin)...${NC}"
    mkdir -p bin/jre-linux
    wget -q --show-progress -O /tmp/java8.tar.gz "https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jre/hotspot/normal/eclipse?project=jdk"
    
    echo -e "${GREEN}[INFO] Extracting Java...${NC}"
    tar -xzf /tmp/java8.tar.gz -C bin/jre-linux --strip-components=1
    rm /tmp/java8.tar.gz
fi

# 4. Create Launcher Script (iniciarPjeCalc.sh)
echo -e "${GREEN}[INFO] Creating launcher script...${NC}"
cat > iniciarPjeCalc.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

# Define local Java path
JAVA_CMD="./bin/jre-linux/bin/java"

# Verify if local java exists
if [ ! -x "$JAVA_CMD" ]; then
    zenity --error --text="Erro Crítico: Java embutido não encontrado em bin/jre-linux."
    exit 1
fi

# Cleanup old processes
pkill -f "pjecalc.jar"

LOG_FILE="/tmp/pjecalc_startup.log"
> "$LOG_FILE"

# Start application
"$JAVA_CMD" \
     -splash:pjecalc_splash.gif \
     -Duser.timezone=GMT-3 \
     -Dfile.encoding=ISO-8859-1 \
     -Dseguranca.pjecalc.tokenServicos=pW4jZ4g9VM5MCy6FnB5pEfQe \
     -Dseguranca.pjekz.servico.contexto="https://pje.trtXX.jus.br/pje-seguranca" \
     -Xms1024m -Xmx2048m \
     -jar bin/pjecalc.jar > "$LOG_FILE" 2>&1 &

PID=$!

zenity --info --timeout=5 --text="Iniciando PJeCalc...\nIsso pode levar alguns segundos." &

# Wait for URL
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
    zenity --error --text="Falha ao iniciar PJeCalc.\nVerifique o log em $LOG_FILE"
fi

wait $PID
EOF

chmod +x iniciarPjeCalc.sh

# 5. Fix Icon
echo -e "${GREEN}[INFO] Generating application icon...${NC}"
if [ -f "icone_calc.ico" ]; then
    convert "icone_calc.ico" "pjecalc.png"
fi

# 6. Create Desktop Shortcut
echo -e "${GREEN}[INFO] Creating desktop shortcut...${NC}"
DESKTOP_FILE="$HOME/.local/share/applications/PJeCalc.desktop"
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Name=PJeCalc
Comment=Calculo Trabalhista
Exec=$APP_DIR/iniciarPjeCalc.sh
Icon=$APP_DIR/pjecalc-0.png
Terminal=false
Type=Application
Categories=Office;Java;
Path=$APP_DIR
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"
update-desktop-database "$HOME/.local/share/applications" &> /dev/null || true

echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo -e "You can now run PJeCalc from your application menu."
echo -e "Required Java 8 is installed in local 'bin/jre-linux' folder."
