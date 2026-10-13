# Captura no Wireshark (HTTP em texto puro)

O objetivo é **observar o protocolo HTTP** e mostrar que, sem TLS, a senha do
login trafega em **texto puro**.

## Preparação
1. Instale o Wireshark na **máquina hospedeira**.
2. Inicie a captura na interface que fala com a VM
   (no Host-only: `VirtualBox Host-Only Network`; no NAT: interface de loopback/NAT).
3. Aplique o filtro de exibição:
   ```
   http
   ```

## Roteiro da captura
1. No navegador, acesse `http://192.168.56.10/` → observe o **GET /** e a
   resposta **200 OK**.
2. Acesse `http://192.168.56.10/wp-admin` → observe os **302** (redirecionamentos)
   e o **GET /wp-login.php** (**200**).
3. Faça login com um usuário/senha errados → observe o **POST /wp-login.php**.
4. Clique com o botão direito na requisição POST → **Follow → HTTP Stream**
   (ou *Follow TCP Stream*). No corpo aparecerá algo como:
   ```
   log=admin&pwd=MinhaSenhaSecreta&wp-submit=Log+In&...
   ```
   → **a senha aparece em texto puro** (URL-encoded).
5. Procure um recurso inexistente (ex.: `http://192.168.56.10/naoexiste.php`)
   → observe o **404 Not Found**.

## Códigos de status que você vai encontrar
| Código | Significado | Onde aparece |
|---|---|---|
| 200 OK | sucesso | página inicial, wp-login.php |
| 302 Found | redirecionamento | após login, wp-admin → wp-login |
| 301 Moved Permanently | redirecionamento permanente | URLs canônicas |
| 404 Not Found | recurso inexistente | URL digitada errada |
| 500 Internal Server Error | erro no servidor/PHP | quebra de plugin, por exemplo |

## Comparação com HTTPS (desafio extra)
Repita o login acessando `https://192.168.56.10/wp-admin` (após rodar o script
`07-https-opcional.sh`). Filtre por `tls` (ou `ssl`) em vez de `http`:
- Você **não** conseguirá ver a senha.
- O tráfego aparece como **Application Data** criptografado (TLS).

> Conclusão: HTTP é inseguro para credenciais; HTTPS (TLS) protege o conteúdo.

## Dica para a apresentação
Deixe o filtro `http.request.method == "POST"` pronto para achar rapidamente o
POST do `wp-login.php`. Também é válido filtrar por `ip.addr == 192.168.56.10`.
