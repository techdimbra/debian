# Techdim Guardião – Estação Base Debian 13

Este repositório agora distribui um **playbook Ansible** (`ansible/techdim-guardian.yml`) para provisionar e realizar o hardening de uma estação base Debian 13 (Trixie) com XFCE para a missão **Techdim Guardião**. A migração do antigo script Bash para Ansible garante repetibilidade, baixa entropia e manutenção simplificada.

## Pré-requisitos
- Estação Debian 13 (Trixie) com XFCE recém-instalada e acesso à Internet.
- Usuário humano padrão: **`kether1-256`** (todas as automações assumem esse usuário).
- Pacote `ansible-core` 2.13+ instalado (o playbook roda contra `localhost`).

### Instalando o Ansible (como `kether1-256`)
```bash
sudo apt update
sudo apt install -y ansible-core git
```

## Passo a passo para `kether1-256`
1. Abra um terminal na sessão gráfica do usuário `kether1-256`.
2. Certifique-se de que o repositório esteja em `/home/kether1-256/Documentos/Logs e configurações Debian13 NucleoTechdim/`. Caso ainda não exista, crie o diretório e traga os arquivos:
   ```bash
   mkdir -p "/home/kether1-256/Documentos/Logs e configurações Debian13 NucleoTechdim"
   cd "/home/kether1-256/Documentos/Logs e configurações Debian13 NucleoTechdim"
   if [ ! -d techdim-guardiao ]; then
     git clone <URL-do-repositório> techdim-guardiao
   fi
   cd techdim-guardiao
   ```
   > Substitua `<URL-do-repositório>` pelo endereço Git utilizado na missão. Se o repositório já estiver presente, apenas acesse a pasta.
3. Eleve privilégios (ex.: `sudo -s` ou `su -`) e execute o playbook a partir da pasta do projeto:
   ```bash
   cd "/home/kether1-256/Documentos/Logs e configurações Debian13 NucleoTechdim/techdim-guardiao"
   ansible-playbook ansible/techdim-guardian.yml
   ```
   O playbook já está pré-configurado para aplicar todas as ações ao usuário `kether1-256`. Caso deseje forçar explicitamente, use `ansible-playbook ansible/techdim-guardian.yml -e "non_root_user=kether1-256"`.
4. Aguarde o término. A execução pode ser repetida sempre que necessário para garantir conformidade.

> **Importante:** o usuário `kether1-256` receberá permissões adicionais (ex.: `docker`, `libvirt`) e terá CLIs Python instaladas via pipx em `~/.local`. Nunca execute o playbook apontando para `root`.

## Principais capacidades do playbook
- **Hardening inicial** – aplica parâmetros `sysctl` endurecidos, ativa `unattended-upgrades`, reforça AppArmor/Auditd e detecta ambientes virtualizados para ajustes específicos.
- **Firewall e mitigação de ataques** – reseta e fortalece UFW, integra Fail2Ban e ativa monitoramentos antivírus (ClamAV) com atualizações e scans agendados.
- **Auditoria e integridade** – agenda execuções do Lynis, Logwatch e ClamAV, mantém `debsums`/`chkrootkit`/`rkhunter` presentes e gera script seguro de backup EFI.
- **Ecossistema de desenvolvimento** – instala toolchain completa (build-essential, Python 3 completo, Git, tmux, etc.), provisiona Docker + Buildx + Compose, Podman, Buildah, Skopeo e ferramentas HashiCorp.
- **CLIs de nuvem e automação** – adiciona e configura repositórios de terceiros para Google Cloud SDK, Azure CLI, AWS CLI, GitHub CLI, 1Password CLI e agora também `kubectl` a partir do novo repositório do Kubernetes (`pkgs.k8s.io`).
- **Ambiente desktop e colaboração** – instala Visual Studio Code, Telegram Desktop, Signal Desktop e Thunderbird.
- **Desenvolvimento mobile moderno** – substitui a extração manual do Android Studio pelo **JetBrains Toolbox**, garantindo atualizações automatizadas para IDEs JetBrains/Android Studio, além de SDKs Android e ferramentas ADB/Fastboot.
- **Isolamento, virtualização e privacidade** – prepara Firejail com perfil reforçado, Bubblewrap, QEMU/KVM + Libvirt, virt-manager, WireGuard, Tor, ProxyChains, Nmap, Wireshark e muito mais.
- **Ferramentas de IA** – instala CLIs Python (OpenAI, Google Generative AI, Anthropic, LangChain, Tiktoken) via **pipx**, garantindo isolamento do Python do sistema e atualizações independentes.

## Inventário de software
| Categoria | Componentes principais |
|-----------|-----------------------|
| Segurança & Hardening | UFW, Fail2Ban, AppArmor, Auditd, ClamAV, Rkhunter, Lynis, Chkrootkit, Debsums, Logwatch, WireGuard |
| Administração | Unattended-upgrades, Needrestart, Apt-listchanges, script de backup EFI |
| Desenvolvimento | Build-essential, Python 3 (full/dev/venv/pip), Git, tmux, htop, tree, jq, yq |
| Contêineres & IaC | Docker CE (CLI, Compose, Buildx), Podman, Buildah, Skopeo, Terraform, Packer, Ansible |
| CLIs de Nuvem & Segurança | Google Cloud SDK, AWS CLI, Azure CLI, GitHub CLI, 1Password CLI, kubectl |
| IDEs & Ferramentas | Visual Studio Code, JetBrains Toolbox (com Android Studio gerenciado) |
| Mobile & Android | Default-JDK, Android SDK, ADB, Fastboot, Scrcpy |
| Virtualização | QEMU-KVM, Libvirt (clientes/daemon), virt-manager, virt-viewer, virtinst, bridge-utils, dnsmasq-base, spice-client-gtk |
| Comunicação | Telegram Desktop, Signal Desktop, Thunderbird |
| Privacidade & Análise | Tor Browser Launcher, Tor, Tor-geoipdb, Nyx, Proxychains4, Nmap, Wireshark, TCPDump |
| Inteligência Artificial | openai, google-generativeai, anthropic, tiktoken, langchain-cli (instalados via pipx) |

## Ações pós-provisionamento recomendadas
1. Faça logout/login para aplicar as permissões de grupo (`docker`, `libvirt`).
2. Execute as etapas de autenticação das CLIs: `gcloud init`, `gh auth login`, `az login`, `aws configure`, `1password signin`, etc.
3. Ajuste regras do UFW conforme políticas internas e valide serviços expostos.
4. Execute `/opt/techdim-guardian/bin/backup-efi.sh` e armazene o arquivo gerado em local seguro.
5. Abra o JetBrains Toolbox e escolha as IDEs desejadas (Android Studio já fica disponível para instalação/atualização contínua).

## Suporte e personalização
O playbook é idempotente: sinta-se à vontade para adaptá-lo às necessidades da missão. Recomenda-se testar alterações em uma VM Debian 13 recém-instalada antes de aplicá-las em produção.
