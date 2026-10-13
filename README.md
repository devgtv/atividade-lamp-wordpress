# Atividade Prática – Servidor LAMP com WordPress

**Disciplina:** CIC1001 – Redes de Computadores II
**Grupo:** 1
**Domínio interno:** `www.grupo1.redes2.internal`
**IP do servidor:** `192.168.56.10`
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
├── scripts/                           # scripts comentados, na ordem de execução
│   ├── 00-variaveis.sh                # variáveis comuns (dados do grupo/banco)
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
│   ├── chaves-seguranca.sh            # corrige as chaves SALT (funciona offline)
│   ├── testar-conexao.sh              # valida conexão WordPress <-> MariaDB
│   ├── diagnostico.sh                 # ajuda a achar o problema de "site travando"
│   ├── coletar-diagnostico.sh         # gera um relatório completo p/ depuração
│   ├── configurar-rede.sh             # configura IP fixo (host-only) + Apache + UFW
│   └── setup-completo.sh              # executa tudo (01 a 06 + 09) de uma vez
├── config/                            # cópias de referência dos .conf do Apache
│   ├── wordpress.conf                 # VirtualHost HTTP
│   ├── wordpress-ssl.conf             # VirtualHost HTTPS
│   └── README-config.md
└── docs/                              # documentação da apresentação
    ├── 01-rede-da-vm.md               # como foi configurada a rede da VM
    ├── 02-wireshark.md                # roteiro da captura HTTP
    ├── 03-questoes-apresentacao.md    # respostas das 5 questões
    ├── 04-roteiro-apresentacao.md     # checklist da apresentação
    └── 05-pagina-integrantes.md       # HTML da página dos integrantes
```

---

## Pré-requisitos

- Máquina virtual (VirtualBox, VMware, Hyper-V...) com **Ubuntu Server** ou **Debian**.
- Rede da VM configurada (host-only/bridge) com IP fixo — ver `docs/01-rede-da-vm.md`.
- Máquina hospedeira com **navegador** e **Wireshark**.
- Acesso à internet na VM (para `apt`/`wget`) durante a instalação.

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
(09: cria `admin`, a página dos integrantes e a define como inicial), garante as
chaves de segurança e roda a verificação final de conexão. Depois é só abrir
`http://192.168.56.10/`.

Flags disponíveis:

```bash
sudo bash scripts/setup-completo.sh --com-dependencias  # instala todas as deps via apt antes
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
sudo bash scripts/09-finalizar-wordpress.sh  # Parte 7 (PHP) - OU pelo navegador
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
| 8 | Testes e logs | `08-testes-logs.sh` |
| 9 | Captura no Wireshark | `docs/02-wireshark.md` |
| Extra | HTTPS autoassinado | `07-https-opcional.sh` |
