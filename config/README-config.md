# Arquivos de configuração (referência)

Esta pasta guarda **cópias de referência** dos arquivos de configuração gerados
pelos scripts. Serve para consulta/estudo e para a apresentação.

| Arquivo | Destino real na VM | Criado por |
|---|---|---|
| `wordpress.conf` | `/etc/apache2/sites-available/wordpress.conf` | `scripts/06-virtualhost.sh` |
| `wordpress-ssl.conf` | `/etc/apache2/sites-available/wordpress-ssl.conf` | `scripts/07-https-opcional.sh` |

Outros arquivos importantes gerados durante a atividade (não versionados neste
repositório, pois vivem na VM):

- `/var/www/wordpress/wp-config.php` – conexão do WordPress com o banco e chaves de segurança.
- `/etc/hosts` (na máquina hospedeira) – mapeia o domínio interno para o IP da VM.
