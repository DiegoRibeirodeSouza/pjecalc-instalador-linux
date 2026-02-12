#!/bin/bash
set -e

# PJeCalc .deb Builder
# Run this script from the PJeCalc root folder (where bin/pjecalc.jar is located)

if [ ! -f "bin/pjecalc.jar" ]; then
    echo "Error: bin/pjecalc.jar not found."
    echo "Please run this script from the PJeCalc installation folder."
    exit 1
fi

PACKAGE_NAME="pjecalc"
VERSION="2.15.1"
ARCH="amd64"
DEB_DIR="${PACKAGE_NAME}_${VERSION}-8_${ARCH}"

echo "=== Building .deb package for $PACKAGE_NAME $VERSION (Revision 8) ==="

# 1. Clean and Create Directory Structure
echo "[*] Creating directory structure..."
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/opt/pjecalc/bin"
mkdir -p "$DEB_DIR/opt/pjecalc/tomcat" # Needed for logs/work
mkdir -p "$DEB_DIR/opt/pjecalc/.dados" # Database template
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"

# 2. Copy Files
echo "[*] Copying files..."

# Copy Jar and Libs
cp -r bin/lib "$DEB_DIR/opt/pjecalc/bin/"
cp bin/pjecalc.jar "$DEB_DIR/opt/pjecalc/bin/"

# Copy JRE (Linux only) - Try local first, then system
if [ -d "pjecalc-linux-installer/bin/jre-linux" ]; then
    cp -r pjecalc-linux-installer/bin/jre-linux "$DEB_DIR/opt/pjecalc/bin/"
elif [ -d "bin/jre-linux" ]; then
    cp -r bin/jre-linux "$DEB_DIR/opt/pjecalc/bin/"
else
    echo "Error: bin/jre-linux not found. Please run the install.sh script first to download the JRE."
    exit 1
fi

# Copy Splash
if [ -f "pjecalc_splash.gif" ]; then
    cp pjecalc_splash.gif "$DEB_DIR/opt/pjecalc/"
fi

# Copy Tomcat Template (Needed for writing logs)
if [ -d "tomcat" ]; then
    cp -r tomcat/* "$DEB_DIR/opt/pjecalc/tomcat/"
else
    echo "Warning: tomcat folder not found. App likely wont run."
fi

# Copy Database Template (If exists)
if [ -d ".dados" ]; then
    cp -r .dados/* "$DEB_DIR/opt/pjecalc/.dados/"
else
    echo "Warning: .dados folder not found. Starting with empty/default database."
fi

# Generate/Copy Icon
# User provided specific PNGs: pjecalc-0.png (16x16), pjecalc-1.png (32x32), pjecalc-2.png (48x48)

if [ -f "pjecalc-2.png" ]; then
    echo "[*] Installing user-provided icons..."
    
    # 48x48 (pjecalc-2.png) - Primary for menus
    mkdir -p "$DEB_DIR/usr/share/icons/hicolor/48x48/apps"
    cp "pjecalc-2.png" "$DEB_DIR/usr/share/icons/hicolor/48x48/apps/pjecalc.png"
    
    # Also copy 48x48 to pixmaps (safest for legacy/MATE)
    mkdir -p "$DEB_DIR/usr/share/pixmaps"
    cp "pjecalc-2.png" "$DEB_DIR/usr/share/pixmaps/pjecalc.png"
    
    # App icon in opt
    cp "pjecalc-2.png" "$DEB_DIR/opt/pjecalc/pjecalc.png"
    
    # 32x32 (pjecalc-1.png)
    if [ -f "pjecalc-1.png" ]; then
        mkdir -p "$DEB_DIR/usr/share/icons/hicolor/32x32/apps"
        cp "pjecalc-1.png" "$DEB_DIR/usr/share/icons/hicolor/32x32/apps/pjecalc.png"
    fi
    
    # 16x16 (pjecalc-0.png)
    if [ -f "pjecalc-0.png" ]; then
        mkdir -p "$DEB_DIR/usr/share/icons/hicolor/16x16/apps"
        cp "pjecalc-0.png" "$DEB_DIR/usr/share/icons/hicolor/16x16/apps/pjecalc.png"
    fi
    
    # Ensure read permissions
    chmod 644 "$DEB_DIR/usr/share/pixmaps/pjecalc.png"
    find "$DEB_DIR/usr/share/icons" -name "*.png" -exec chmod 644 {} \;

elif [ -f "icone_calc.ico" ] && command -v convert &> /dev/null; then
    # Fallback to ICO conversion if PNGs missing
    echo "[*] Converting icon from ICO..."
    mkdir -p "$DEB_DIR/usr/share/icons/hicolor/48x48/apps"
    convert "icone_calc.ico" -resize 48x48 "$DEB_DIR/usr/share/icons/hicolor/48x48/apps/pjecalc.png"
    
    mkdir -p "$DEB_DIR/usr/share/pixmaps"
    cp "$DEB_DIR/usr/share/icons/hicolor/48x48/apps/pjecalc.png" "$DEB_DIR/usr/share/pixmaps/pjecalc.png"
    cp "$DEB_DIR/usr/share/icons/hicolor/48x48/apps/pjecalc.png" "$DEB_DIR/opt/pjecalc/pjecalc.png"
fi

# 3. Create Control File
echo "[*] Creating DEBIAN/control..."
cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: zenity, xdg-utils
Maintainer: Unofficial Installer <installer@pjecalc.local>
Description: PJeCalc Cidadão (Offline)
 O PJe-Calc Cidadão é uma aplicação desktop para a elaboração de cálculos
 trabalhistas. Esta versão empacota a aplicação oficial do TRT.
 .
 Inclui JRE embutido (Java 8).
EOF

# 4. Create Post-Install Script (Icon Cache)
echo "[*] Creating DEBIAN/postinst..."
cat > "$DEB_DIR/DEBIAN/postinst" << EOF
#!/bin/bash
set -e
if [ "\$1" = "configure" ]; then
    update-icon-caches /usr/share/icons/hicolor || true
fi
EOF
chmod 755 "$DEB_DIR/DEBIAN/postinst"

# 5. Create Startup Script (Handles User Dir)
echo "[*] Creating startup script..."
cat > "$DEB_DIR/opt/pjecalc/iniciarPjeCalc.sh" << 'EOF'
#!/bin/bash

# Define user directory
USER_HOME="$HOME/.pjecalc-cidadao"
INSTALL_DIR="/opt/pjecalc"

# Create user directory if missing
if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
    mkdir -p "$USER_HOME/bin"
    
    # Symlink immutable resource
    ln -sf "$INSTALL_DIR/bin/pjecalc.jar" "$USER_HOME/bin/pjecalc.jar"
    ln -sf "$INSTALL_DIR/bin/lib" "$USER_HOME/bin/lib"
    ln -sf "$INSTALL_DIR/bin/jre-linux" "$USER_HOME/bin/jre-linux"
    ln -sf "$INSTALL_DIR/pjecalc_splash.gif" "$USER_HOME/pjecalc_splash.gif"
    
    # Copy mutable resources (Templates)
    cp -r "$INSTALL_DIR/tomcat" "$USER_HOME/"
    if [ -d "$INSTALL_DIR/.dados" ]; then
        mkdir -p "$USER_HOME/.dados"
        cp -r "$INSTALL_DIR/.dados/"* "$USER_HOME/.dados/"
    fi
    
    zenity --info --text="Configurando PJeCalc pela primeira vez...\nIsso pode levar alguns instantes." --timeout=5
fi

# Ensure permissions (in case of update/issues)
chmod -R u+rw "$USER_HOME/tomcat" 2>/dev/null
chmod -R u+rw "$USER_HOME/.dados" 2>/dev/null

cd "$USER_HOME"

# Java Path
JAVA_CMD="./bin/jre-linux/bin/java"

if [ ! -x "$JAVA_CMD" ]; then
    zenity --error --text="Erro: Java não encontrado em $USER_HOME/bin/jre-linux"
    exit 1
fi

# Cleanup old processes
pkill -f "$USER_HOME/bin/pjecalc.jar"

LOG_FILE="/tmp/pjecalc_start_$USER.log"
> "$LOG_FILE"

# Start App
# Reverting xvfb as it caused issues. Tray icon will be present.
"$JAVA_CMD" \
     -splash:pjecalc_splash.gif \
     -Duser.timezone=GMT-3 \
     -Dfile.encoding=ISO-8859-1 \
     -Dseguranca.pjecalc.tokenServicos=pW4jZ4g9VM5MCy6FnB5pEfQe \
     -Dseguranca.pjekz.servico.contexto="https://pje.trtXX.jus.br/pje-seguranca" \
     -Xms1024m -Xmx2048m \
     -jar bin/pjecalc.jar > "$LOG_FILE" 2>&1 &

PID=$!

(
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
        sleep 3
        
        # Try App Mode
        if command -v google-chrome &> /dev/null; then
            google-chrome --app="$URL" &
        elif command -v chromium &> /dev/null; then
            chromium --app="$URL" &
        elif command -v google-chrome-stable &> /dev/null; then
            google-chrome-stable --app="$URL" &
        else
            xdg-open "$URL" &
        fi
    else
        zenity --error --text="Falha ao iniciar PJeCalc.\nVerifique o log: $LOG_FILE"
    fi
) &

wait $PID
EOF

chmod +x "$DEB_DIR/opt/pjecalc/iniciarPjeCalc.sh"

# 6. Create Desktop File
echo "[*] Creating .desktop file..."
cat > "$DEB_DIR/usr/share/applications/pjecalc.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=PJeCalc Cidadão
Comment=Software de Cálculo Trabalhista
Exec=/opt/pjecalc/iniciarPjeCalc.sh
Icon=/usr/share/pixmaps/pjecalc.png
Terminal=false
Type=Application
Categories=Office;Finance;Java;
StartupNotify=true
EOF

# 7. Build Package
echo "[*] Building .deb package..."
dpkg-deb --build "$DEB_DIR"

echo "=== Success! Package created: ${DEB_DIR}.deb ==="
