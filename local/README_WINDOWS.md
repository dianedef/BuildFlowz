# BuildFlowz - Installation pour Windows

## 🎯 Options d'installation

Windows offre **3 options** pour utiliser BuildFlowz localement:

---

## ✅ Option 1: WSL (Recommandé)

**Avantages:**
- ✅ Meilleure compatibilité avec les outils Linux
- ✅ Support complet de autossh
- ✅ Expérience identique à Linux/macOS
- ✅ Menu interactif disponible

**Installation:**

1. **Installer WSL:**
   ```powershell
   wsl --install
   ```
   Redémarrez votre ordinateur si nécessaire.

2. **Lancer WSL et installer les dépendances:**
   ```bash
   sudo apt update
   sudo apt install autossh git
   ```

3. **Cloner le repo et installer:**
   ```bash
   cd /mnt/c/Users/VotreNom/Documents  # Ou votre dossier préféré
   git clone https://github.com/votre-org/BuildFlowz.git
   cd BuildFlowz/local
   ./install.sh
   ```

4. **Utiliser les tunnels:**
   ```bash
   urls      # ou tunnel
   ```

---

## ⚡ Option 2: PowerShell Natif

**Avantages:**
- ✅ Pas besoin de WSL
- ✅ Utilise OpenSSH natif de Windows
- ✅ Simple et rapide

**Limitations:**
- ❌ Pas de autossh (tunnels manuels)
- ❌ Pas de menu interactif

**Installation:**

1. **Vérifier OpenSSH Client:**

   OpenSSH est installé par défaut sur Windows 10/11. Sinon:
   ```powershell
   # PowerShell en tant qu'administrateur
   Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
   ```

2. **Exécuter le script d'installation:**
   ```powershell
   cd local
   .\install_local.ps1
   ```

3. **Créer des tunnels SSH:**

   **Méthode simple:**
   ```powershell
   .\start-tunnel.ps1 -Port 3001
   ```

   **Avec alias (après rechargement du profil):**
   ```powershell
   tunnel 3001
   ```

   **Tunnel manuel:**
   ```powershell
   ssh -N -L 3001:localhost:3001 hetzner
   ```

---

## 🔧 Option 3: Git Bash

**Avantages:**
- ✅ Environnement bash familier
- ✅ Git inclus

**Limitations:**
- ❌ Pas de autossh
- ❌ Compatibilité limitée avec certains scripts

**Installation:**

1. **Installer Git for Windows:**
   https://git-scm.com/download/win

2. **Lancer Git Bash et créer des tunnels manuels:**
   ```bash
   ssh -N -L 3001:localhost:3001 root@5.75.134.202
   ```

---

## 🔑 Configuration SSH (Toutes les options)

### Générer une clé SSH

**PowerShell ou Git Bash:**
```bash
ssh-keygen -t ed25519 -C "votre_email@example.com"
```

**Emplacement par défaut:**
- Windows: `C:\Users\VotreNom\.ssh\id_ed25519`
- WSL: `~/.ssh/id_ed25519` (dans le système WSL)

### Ajouter la clé au serveur

**PowerShell:**
```powershell
# Copier la clé publique dans le presse-papiers
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | clip

# Se connecter au serveur
ssh root@5.75.134.202

# Sur le serveur, ajouter la clé
echo "COLLEZ_VOTRE_CLE_ICI" >> ~/.ssh/authorized_keys
```

**WSL / Git Bash:**
```bash
# Copier manuellement la clé
cat ~/.ssh/id_ed25519.pub

# Se connecter et ajouter
ssh root@5.75.134.202
echo "COLLEZ_VOTRE_CLE_ICI" >> ~/.ssh/authorized_keys
```

---

## 📊 Comparaison des options

| Fonctionnalité | WSL | PowerShell | Git Bash |
|----------------|-----|------------|----------|
| Tunnels automatiques (autossh) | ✅ | ❌ | ❌ |
| Menu interactif | ✅ | ❌ | ❌ |
| Simplicité | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Compatibilité scripts | ✅ 100% | ⭐ 70% | ⭐ 80% |
| Performance | ✅ Excellent | ✅ Excellent | ✅ Bon |

---

## 🚀 Utilisation

### WSL (avec menu)
```bash
urls                  # Ouvre le menu interactif
```

### PowerShell
```powershell
# Démarrer un tunnel
.\start-tunnel.ps1 -Port 3001

# Ou avec alias (après rechargement)
tunnel 3001

# Arrêter: Ctrl+C dans la fenêtre du tunnel
```

### Tunnel SSH manuel (toutes options)
```bash
# Tunnel simple
ssh -N -L 3001:localhost:3001 hetzner

# Tunnel en arrière-plan (PowerShell)
Start-Job -ScriptBlock { ssh -N -L 3001:localhost:3001 hetzner }
```

---

## 🆘 Dépannage

### "Permission denied (publickey)"

**Solution:** Votre clé SSH n'est pas configurée sur le serveur.

1. Vérifiez que vous avez une clé SSH:
   ```powershell
   dir $env:USERPROFILE\.ssh\id_ed25519.pub
   ```

2. Si elle n'existe pas, créez-la:
   ```powershell
   ssh-keygen -t ed25519
   ```

3. Ajoutez-la au serveur (voir section Configuration SSH)

### "ssh: command not found" (PowerShell)

**Solution:** OpenSSH n'est pas installé.

```powershell
# PowerShell en tant qu'administrateur
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### Le tunnel se ferme automatiquement

**Solution:** Utilisez des paramètres de keep-alive.

Ajoutez dans `~/.ssh/config` (ou `C:\Users\VotreNom\.ssh\config`):
```
Host hetzner
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### WSL: "autossh: command not found"

**Solution:**
```bash
sudo apt update
sudo apt install autossh
```

---

## 💡 Conseils

1. **Pour les développeurs:** WSL offre la meilleure expérience
2. **Pour un usage occasionnel:** PowerShell est plus simple
3. **Gardez vos tunnels actifs:** Les tunnels SSH peuvent s'interrompre. Utilisez autossh (WSL) ou relancez manuellement (PowerShell)
4. **Sécurité:** Ne partagez jamais votre clé privée (`id_ed25519`), seulement la clé publique (`id_ed25519.pub`)

---

## 🔗 Ressources

- **WSL Documentation:** https://aka.ms/wsl
- **OpenSSH pour Windows:** https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
- **Git for Windows:** https://git-scm.com/download/win
