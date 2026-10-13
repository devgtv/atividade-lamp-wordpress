# Roteiro da apresentação (checklist)

## Antes de começar
- [ ] VM ligada, com IP `192.168.56.10` (`ip a`).
- [ ] Hospedeira pinga e acessa `http://192.168.56.10/` no navegador.
- [ ] Wireshark aberto e pronto para capturar (filtro `http`).
- [ ] Terminal com os scripts do repositório à mão.

## Demonstrações
1. **Rede:** mostrar o adaptador host-only no VirtualBox e o IP fixo na VM
   (`ip a`, `ip route`). Explicar a escolha (host-only + IP fixo).
2. **Pilha funcionando:** `systemctl status apache2 mariadb` e `php -v`.
3. **WordPress:** abrir `http://192.168.56.10/` → mostrar a página dos integrantes.
4. **Banco:** `sudo mariadb -e "SHOW DATABASES; SELECT user,host FROM mysql.user;"`
5. **Logs:** `sudo tail -f /var/log/apache2/wordpress_access.log` enquanto navega
   → mostrar método, recurso e código (200/302/404).
6. **Wireshark:** repetir login e mostrar o **POST wp-login.php** com a senha em
   texto puro; mostrar um **404** e um **302**.
7. **(Extra) HTTPS:** `https://192.168.56.10/` e nova captura mostrando que a
   senha não aparece.

## Pontos para explicar (respostas em `03-questoes-apresentacao.md`)
- Papel de cada letra do LAMP.
- GET vs POST.
- Classes de status 2xx/3xx/4xx/5xx.
- VirtualHost e ServerName.
- Por que usuário próprio no banco.

## Comandos úteis para "quebrar o gelo" durante a apresentação
```bash
# Ver IP e rotas
ip a ; ip route

# Status dos serviços
systemctl status apache2 mariadb --no-pager

# Testar HTTP e ver cabeçalhos
curl -I http://192.168.56.10/

# Ver logs de acesso ao vivo
sudo tail -f /var/log/apache2/wordpress_access.log

# Testar sintaxe do Apache
sudo apache2ctl configtest

# Conferir sites habilitados
ls -l /etc/apache2/sites-enabled/
```
