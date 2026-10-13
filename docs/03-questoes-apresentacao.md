# Questões para a apresentação (com respostas)

## 1. Qual o papel de cada componente da pilha LAMP?
- **L (Linux):** sistema operacional base; gerencia processos, arquivos, rede e
  usuários. É onde todos os outros serviços rodam.
- **A (Apache):** servidor web. Recebe requisições HTTP/HTTPS (portas 80/443) e
  entrega as páginas (HTML/CSS/JS) e respostas ao navegador.
- **M (MySQL/MariaDB):** sistema gerenciador de banco de dados (SGBD). Guarda de
  forma estruturada os posts, usuários, comentários e configurações do site.
- **P (PHP):** linguagem de programação do lado do servidor. O Apache entrega o
  arquivo `.php` ao interpretador PHP, que conversa com o banco e gera o HTML
  final. O WordPress é escrito em PHP.

## 2. Qual a diferença entre os métodos GET e POST?
- **GET:** solicita um recurso; os parâmetros vão na **URL** (querystring). É
  visível, tem tamanho limitado e **não deve** ser usado para dados sensíveis.
  Ex.: abrir uma página (o navegador pode guardar em cache/marcadores).
- **POST:** envia dados no **corpo** da requisição. Não fica na URL, admite
  arquivos grandes e é o método usado para **login e formulários**. Ainda assim,
  em HTTP **sem TLS** o corpo trafega em texto puro (por isso o Wireshark mostra
  a senha).

## 3. O que indicam os códigos de status 2xx, 3xx, 4xx e 5xx?
- **2xx – Sucesso:** requisição recebida, entendida e aceita.
  Ex.: **200 OK**, 201 Created, 204 No Content.
- **3xx – Redirecionamento:** o recurso está em outro lugar; o cliente deve seguir.
  Ex.: 301 Moved Permanently, **302 Found**.
- **4xx – Erro do cliente:** o pedido tem problema (recurso não existe, acesso
  negado, requisição malformada). Ex.: 400, 401, 403, **404 Not Found**.
- **5xx – Erro do servidor:** o pedido era válido, mas o servidor falhou ao
  processá-lo. Ex.: **500 Internal Server Error**, 502, 503.

## 4. Para que serve o VirtualHost e a diretiva ServerName?
- **VirtualHost:** permite que **um único servidor Apache** hospede **vários
  sites**, separando cada um pelas suas configurações (DocumentRoot, logs,
  regras). Diferencia-se por **IP, porta e/ou nome de domínio**.
- **ServerName:** define o **nome de domínio principal** que aquele VirtualHost
  atende (ex.: `www.grupo1.redes2.internal`). Quando a requisição chega, o Apache
  compara o cabeçalho `Host:` com o `ServerName`/`ServerAlias` para decidir qual
  site responder.

## 5. Por que o WordPress usa um usuário próprio no banco em vez do root?
- **Princípio do menor privilégio:** o `wpuser` tem acesso **somente** ao banco
  `wordpress`, com as permissões necessárias; o `root` controla **todos** os
  bancos e usuários.
- **Segurança:** se o site for comprometido (plugin vulnerável, por exemplo), o
  atacante não ganha controle do servidor de banco inteiro — fica limitado ao
  banco do WordPress.
- **Rastreabilidade/boa prática:** ações do site ficam atribuídas ao usuário
  específico da aplicação; evita reutilizar credenciais administrativas.
