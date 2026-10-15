# Atividade Prática – Servidor LAMP com WordPress

**Disciplina:** CIC1001 – Redes de Computadores II
**Grupo:** 1
**Domínio interno:** `www.grupo1.redes2.internal`
**IP do servidor:** `192.168.56.10` (padrão — os scripts detectam automaticamente o IP real da VM e mostram o endereço correto no final de cada execução)
**Banco de dados:** `wordpress` / usuário `wpuser`
**Entrega/apresentação:** até 16/10/2026

Este repositório reúne os scripts comentados (.sh), os arquivos de configuração e
a documentação necessários para **montar um servidor LAMP e publicar um site
WordPress** em uma máquina virtual, com o site acessível pelo navegador da
máquina hospedeira.

---

## Estrutura do repositório

```
atividade-lamp-wordpress/
├── README.md                          # este arquivo
├── host/                              # scripts para rodar na HOSPEDEIRA (PC físico)
│   ├── configurar-virtualbox.ps1      # Windows: cria host-only, adaptador, hosts, port-forward
│   └── configurar-virtualbox.sh       # Linux/WSL: mesma automação
├── scripts/                           # scripts comentados, na ordem de execução
│   ├── 00-variaveis.sh                # variáveis comuns (dados do grupo/banco/rede)
│   ├── dependencias.sh                # instala TODAS as dependências via apt
│   ├── 01-atualizacao-firewall.sh     # apt update/upgrade + UFW (22, 80)
│   ├── 02-apache.sh                   # instala e testa o Apache
│   ├── 03-mariadb.sh                  # instala MariaDB, cria banco e usuário
│   ├── 04-php.sh                      # instala PHP e módulos do WordPress
│   ├── 05-wordpress.sh                # baixa, instala e configura o WordPress
│   ├── 06-virtualhost.sh              # VirtualHost do Apache (porta 80)
│   ├── 07-https-opcional.sh           # desafio extra: HTTPS autoassinado
│   ├── 08-testes-logs.sh              # testes com curl e leitura dos logs
│   ├── 09-finalizar-wordpress.sh      # Parte 7 via PHP (admin + página inicial)
│   ├── garantir-htaccess.sh           # permalinks + .htaccess (REST API / editor)
│   ├── chaves-seguranca.sh            # corrige as chaves SALT (funciona offline)
│   ├── ajustar-url-dinamica.sh        # WordPress aceita IP OU domínio (portátil)
│   ├── testar-conexao.sh              # valida conexão WordPress <-> MariaDB
│   ├── diagnostico.sh                 # ajuda a achar o problema de "site travando"
│   ├── coletar-diagnostico.sh         # gera um relatório completo p/ depuração
│   ├── configurar-rede.sh             # IP fixo + /etc/hosts + VirtualHost + URL (auto)
│   ├── definir-url-site.sh            # força um endereço fixo (opcional)
│   └── setup-completo.sh              # executa tudo (01 a 06 + 09 + URL) de uma vez
├── config/                            # cópias de referência dos .conf do Apache
│   ├── wordpress.conf                 # VirtualHost HTTP
│   ├── wordpress-ssl.conf             # VirtualHost HTTPS
│   └── README-config.md
└── docs/                              # documentação da apresentação
    ├── 01-rede-da-vm.md               # rede automática (host-only/NAT, domínio)
    ├── 02-wireshark.md                # roteiro da captura HTTP
    ├── 03-questoes-apresentacao.md    # respostas das 5 questões
    ├── 04-roteiro-apresentacao.md     # checklist da apresentação
    └── 05-pagina-integrantes.md       # HTML da página dos integrantes
```

---

## Pré-requisitos

- Máquina virtual (VirtualBox, VMware, Hyper-V...) com **Ubuntu Server** ou **Debian**.
- Máquina hospedeira com **navegador** e **Wireshark**.
- Acesso à internet na VM (para `apt`/`wget`) durante a instalação.
- A rede da VM é configurada **automaticamente** pelos scripts (não precisa editar
  arquivos na mão) — ver `docs/01-rede-da-vm.md`.

---

## Começando do zero (funciona em qualquer PC)

**1) Na hospedeira** — prepara o VirtualBox (rede host-only + adaptador + hosts):
```powershell
.\host\configurar-virtualbox.ps1 -VM "lampredes"     # Windows
# ou
bash host/configurar-virtualbox.sh --vm lampredes     # Linux/WSL
```

**2) Na VM** — instala tudo e configura a rede/URL de uma vez:
```bash
git clone <URL-do-repo> atividade-lamp-wordpress
cd atividade-lamp-wordpress
sudo bash scripts/setup-completo.sh --com-dependencias --com-rede
```

**3) Acesse na hospedeira:**
- IP: `http://192.168.56.10/`
- Domínio: `http://www.grupo1.redes2.internal/`
- Painel: `/wp-login.php` — `admin` / `AdminWordPress123!`

> O site é **portátil**: graças à URL dinâmica (`scripts/ajustar-url-dinamica.sh`)
> ele responde por IP, por domínio ou por `localhost:8080`, sem trocar endereço ao
> mudar de PC.

---

## Como usar

### Instalar só as dependências (apt)
Prepara a VM do zero, instalando todas as libs/pacotes num comando:

```bash
sudo bash scripts/dependencias.sh              # instala tudo
sudo bash scripts/dependencias.sh --so-baixar  # apenas baixa (não instala)
```

### Opção rápida (tudo de uma vez)
Copie a pasta `scripts/` para a VM e execute:

```bash
sudo bash scripts/setup-completo.sh
```

Sem flags, ele instala a pilha LAMP (01 a 06), conclui o WordPress via PHP
(09: cria `admin`, a página dos integrantes e a define como inicial), aplica a
URL dinâmica, garante as chaves de segurança e roda a verificação final de
conexão. Depois é só abrir `http://192.168.56.10/` (ou o domínio, com `--com-rede`).

Flags disponíveis:

```bash
sudo bash scripts/setup-completo.sh --com-dependencias  # instala todas as deps via apt antes
sudo bash scripts/setup-completo.sh --com-rede          # + IP fixo, /etc/hosts e domínio
sudo bash scripts/setup-completo.sh --https             # + HTTPS autoassinado (07)
sudo bash scripts/setup-completo.sh --sem-finalizar     # Parte 7 feita no navegador
sudo bash scripts/setup-completo.sh --sem-verificar     # pula a verificação final
sudo bash scripts/setup-completo.sh --help              # ajuda
```

### Opção passo a passo (recomendada para a apresentação)
Rode cada etapa na ordem, explicando o que cada uma faz:

```bash
sudo bash scripts/01-atualizacao-firewall.sh
sudo bash scripts/02-apache.sh
sudo bash scripts/03-mariadb.sh
sudo bash scripts/04-php.sh
sudo bash scripts/05-wordpress.sh
sudo bash scripts/06-virtualhost.sh
sudo bash scripts/ajustar-url-dinamica.sh    # site funciona por IP ou domínio
sudo bash scripts/configurar-rede.sh         # IP fixo + /etc/hosts + VirtualHost
sudo bash scripts/09-finalizar-wordpress.sh  # Parte 7 (PHP) - OU pelo navegador
sudo bash scripts/garantir-htaccess.sh       # permalinks + .htaccess (REST API)
bash      scripts/08-testes-logs.sh          # testes (não precisa de root)
sudo bash scripts/07-https-opcional.sh       # opcional: HTTPS
```

> Os scripts usam `source 00-variaveis.sh`, então funcionam tanto se executados
> da pasta `scripts/` quanto de outro diretório (desde que a estrutura seja mantida).

### Parte 7 – Finalizar a instalação
Duas formas (escolha uma):

1. **Automática (PHP)** – rode `sudo bash scripts/09-finalizar-wordpress.sh`
   (já incluída no `setup-completo.sh` por padrão). Ela cria o admin, a página
   dos integrantes e a define como página inicial.
2. **Pelo navegador** – acesse `http://192.168.56.10/`, preencha título do site,
   usuário admin, senha e e-mail; crie a página (HTML em
   `docs/05-pagina-integrantes.md`) e defina-a como inicial
   (*Configurações → Leitura*).

Credenciais padrão do admin (edite em `scripts/00-variaveis.sh`):
`admin` / `AdminWordPress123!`.

---

## O que é entregue/apresentado

- [x] Apache, MariaDB e PHP funcionando.
- [x] WordPress acessível pelo navegador da hospedeira, com a página dos integrantes.
- [x] Requisições registradas no log de acesso (`wordpress_access.log`).
- [x] Captura do Wireshark mostrando HTTP e a senha exposta no login (HTTP sem TLS).
- [x] Arquivos de configuração e scripts `.sh` comentados.
- [x] (Extra) HTTPS com certificado autoassinado e captura comparativa.

---

## Segurança (observações)

As credenciais deste repositório (`SenhaForte123!`, etc.) são **didáticas**, de
um laboratório isolado. Em produção: use senhas fortes, HTTPS com certificado
válido e nunca versione o `wp-config.php` (já está no `.gitignore`).

---

## Problemas comuns

### "Updating failed. The response is not a valid JSON response." no painel
Acontece quando o editor de blocos chama a REST API (`/wp-json/...`) e recebe um
**404 em HTML** em vez de JSON — normalmente porque os permalinks estão "bonitos"
(`/%postname%/`) mas o arquivo **`.htaccess`** não existe/está sem as regras de
rewrite. O `09-finalizar-wordpress.sh` passou a garantir isso automaticamente
(antes, rodando por CLI, o WordPress não gravava o `.htaccess`).

Correção rápida (recria o `.htaccess` e os permalinks):
```bash
sudo bash scripts/garantir-htaccess.sh   # permalinks + .htaccess (idempotente)
sudo bash scripts/testar-conexao.sh      # o item 8 testa a REST API (wp-json)
```
O `setup-completo.sh` já executa o `garantir-htaccess.sh` automaticamente ao final.

## Resumo das partes do roteiro

| Parte | Descrição | Script |
|---|---|---|
| 1 | Atualização e firewall | `01-atualizacao-firewall.sh` |
| 2 | Apache | `02-apache.sh` |
| 3 | MariaDB (banco + usuário) | `03-mariadb.sh` |
| 4 | PHP + módulos | `04-php.sh` |
| 5 | Download/instalação do WordPress | `05-wordpress.sh` |
| 6 | VirtualHost do Apache | `06-virtualhost.sh` |
| 7 | Configuração (navegador ou PHP) | `09-finalizar-wordpress.sh` |
| 7.1 | Permalinks + `.htaccess` (REST API) | `garantir-htaccess.sh` |
| 8 | Testes e logs | `08-testes-logs.sh` |
| 9 | Captura no Wireshark | `docs/02-wireshark.md` |
| Extra | HTTPS autoassinado | `07-https-opcional.sh` |
