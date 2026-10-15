# Questões da apresentação — respostas

> Trabalho: **servidor LAMP com WordPress** (CIC1001 – Redes de Computadores II).
> Cada resposta liga a teoria ao que o projeto realmente faz — scripts em
> `scripts/` e configurações em `config/`.

---

## 1. Qual o papel de cada componente da pilha LAMP?

A sigla **LAMP** reúne as quatro camadas de software que, juntas, publicam um
site dinâmico (no nosso caso, o WordPress):

- **L — Linux (Ubuntu Server / Debian):** é a **base**. Gerencia processos,
  arquivos, permissões, usuários e a **rede**. Todos os outros serviços rodam
  sobre ele, como serviços do `systemd` (`apache2`, `mariadb`).
- **A — Apache (`httpd`):** é o **servidor web**. Fica escutando as portas
  **80 (HTTP)** e **443 (HTTPS)**, recebe a requisição do navegador, decide
  qual *VirtualHost* responde e entrega o conteúdo. No projeto: `02-apache.sh`
  e o VirtualHost em `scripts/06-virtualhost.sh` / `config/wordpress.conf`.
- **M — MySQL/MariaDB:** é o **SGBD** (Sistema Gerenciador de Banco de Dados).
  Guarda de forma estruturada tudo que é dinâmico: posts, páginas, usuários,
  comentários e as configurações do site. No projeto: `03-mariadb.sh` cria o
  banco `wordpress` e o usuário `wpuser`.
- **P — PHP:** é a **linguagem do lado do servidor**. Quando o recurso pedido é
  `.php`, o Apache entrega o arquivo ao interpretador PHP; este conversa com o
  banco, monta o HTML final e devolve ao Apache. O **WordPress é escrito em
  PHP**. No projeto: `04-php.sh` (PHP + `libapache2-mod-php` + `php-mysql`) e as
  credenciais do banco no `wp-config.php`.

**Fluxo de uma requisição:**
```
navegador ──HTTP──▶ Apache ──▶ PHP ──▶ MariaDB
    ▲                                       │
    └────────── HTML gerado ◀───────────────┘
```

---

## 2. Qual a diferença entre os métodos GET e POST?

Os dois são **métodos do protocolo HTTP** usados para enviar requisições, mas
com semântica diferente:

| Característica        | **GET**                              | **POST**                              |
|-----------------------|--------------------------------------|---------------------------------------|
| Onde vão os dados     | na **URL** (querystring `?a=b`)      | no **corpo** da requisição            |
| Visibilidade          | visível na URL/histórico/marcadores  | não aparece na URL                    |
| Cache / marcadores    | sim (pode ser cacheado)              | não deve ser cacheado                 |
| Tamanho dos dados     | limitado (limite da URL)             | praticamente ilimitado                |
| Uso típico            | **ler**/buscar um recurso            | **enviar**/alterar dados (formulários) |
| Idempotência          | sim (repetir não muda nada)          | não (pode mudar o estado)             |

Aplicando ao projeto:

- Abrir a página dos integrantes é um **GET** (`GET /`); os parâmetros, se
  houvesse, iriam na URL.
- O **login do WordPress** é um **POST para `wp-login.php`** — usuário e senha
  vão no **corpo** da requisição. Por isso a captura no **Wireshark**
  (`docs/02-wireshark.md`) mostra a senha em texto puro quando o acesso é
  HTTP **sem TLS**.
- Importante: o POST esconde os dados da **URL**, mas **não os criptografa**.
  Sem HTTPS, o corpo trafega em claro — reforçando a necessidade de TLS.

---

## 3. O que indicam os códigos de status 2xx, 3xx, 4xx e 5xx?

O **código de status** (na primeira linha da resposta HTTP) resume o resultado
da requisição; o primeiro dígito indica a **classe**:

- **2xx — Sucesso:** a requisição foi recebida, entendida e aceita.
  Ex.: **200 OK** (página entregue), 201 Created, 204 No Content.
  *No projeto:* abrir `http://<IP>/` retorna **200**.
- **3xx — Redirecionamento:** o recurso está em outro endereço; o cliente deve
  seguir para a nova URL. Ex.: 301 Moved Permanently, **302 Found**.
  *No projeto:* ao acessar `/wp-admin` sem estar logado, o WordPress responde
  **302** redirecionando para o login.
- **4xx — Erro do cliente:** a requisição tem problema (recurso inexistente,
  acesso negado, formato inválido). Ex.: 400 Bad Request, 401 Unauthorized,
  403 Forbidden, **404 Not Found**.
  *No projeto:* pedir uma URL que não existe (ex.: `/naoexiste.php`) dá **404**.
- **5xx — Erro do servidor:** a requisição era válida, mas o servidor falhou ao
  processá-la. Ex.: **500 Internal Server Error**, 502, 503.
  *No projeto:* um erro de PHP/plugin (ou banco fora do ar) gera **500**.

Os códigos são visíveis no log de acesso (`wordpress_access.log`), no formato
`... "GET / HTTP/1.1" 200 ...` — útil para depurar (scripts `08-testes-logs.sh`
e `diagnostico.sh`).

---

## 4. Para que serve o VirtualHost e a diretiva ServerName?

- **VirtualHost:** é um bloco de configuração do Apache que permite que **um
  único servidor** hospede **vários sites**, cada um com seu `DocumentRoot`,
  logs e regras. O Apache separa os sites por **IP**, **porta** e/ou **nome de
  domínio**.
- **ServerName:** define o **nome de domínio principal** que aquele VirtualHost
  atende. Quando a requisição chega, o Apache compara o cabeçalho **`Host:`**
  enviado pelo navegador com o `ServerName` (e com os `ServerAlias`) para
  escolher qual site responder — isso se chama **virtual hosting por nome**.

No projeto, `scripts/06-virtualhost.sh` / `config/wordpress.conf`:

```apache
<VirtualHost *:80>
    ServerName  www.grupo1.redes2.internal
    ServerAlias 192.168.56.10 grupo1.redes2.internal
    DocumentRoot /var/www/wordpress

    <Directory /var/www/wordpress>
        AllowOverride All      # permite o .htaccess do WordPress (permalinks)
        Require all granted
    </Directory>
</VirtualHost>
```

- `ServerName` = domínio principal; `ServerAlias` = nomes alternativos (o IP e
  o domínio sem `www`), para o site abrir por vários nomes.
- `DocumentRoot` aponta para a pasta do WordPress.
- `AllowOverride All` é o que deixa o **`.htaccess`** do WordPress funcionar
  (URLs amigáveis e a **REST API** `/wp-json/` — ver `scripts/garantir-htaccess.sh`).
- Como o domínio é fictício, ele é resolvido localmente via **`/etc/hosts`**
  (na VM, pelo `configurar-rede.sh`) e no `hosts` da hospedeira.

---

## 5. Por que o WordPress usa um usuário próprio no banco em vez do root?

Porque usar o **`root`** do banco para a aplicação viola o **princípio do
menor privilégio**:

- **Menor privilégio:** o `wpuser` recebe acesso **apenas** ao banco
  `wordpress` e somente às operações necessárias. O `root` controla **todos**
  os bancos, usuários e a própria configuração do servidor MariaDB.

  ```sql
  GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
  -- e NUNCA:  GRANT ALL ON *.* TO 'wpuser'@'localhost'
  ```

- **Segurança (contenção de danos):** o WordPress é exposto à web. Se o site
  for comprometido (plugin/tema vulnerável, senha vazada), o atacante herda as
  permissões do usuário da aplicação — ficando **limitado ao banco do
  WordPress**, sem `DROP`/leitura dos demais bancos nem criação de usuários
  administradores.

- **Boa prática e rastreabilidade:** as ações do site ficam atribuídas a um
  usuário específico da aplicação; evita reutilizar credenciais administrativas
  (`root`) no `wp-config.php`, que fica em disco e pode vazar (backup, log).
  No projeto, essas credenciais vêm de `scripts/00-variaveis.sh` e o
  `wp-config.php` está no `.gitignore` justamente para **não** versioná-las.
