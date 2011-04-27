
Необходимые для работы модули:
Template
DBIx::Class
Config::JSON
Any::Moose
JSON
MojoX::Session
Data::UUID
MIME::Lite

Необходимые модули для PSGI
Plack::Handler::Apache2

Запуск в режиме PSGI:
starman -R PATH_TO_NikoloCMS/lib/,PATH_TO_NikoloCMS/templates/ nikolo.psgi

Запуск в режиме CGI:
<VirtualHost *:80>
    ServerAdmin e@mail.ru
    DocumentRoot "PATH_TO_NikoloCMS"
    ServerName SITENAME
    ErrorLog "/var/log/apache2/nikoloCMS-error_log"
    CustomLog "/var/log/apache2/nikoloCMS-access_log" common
    ScriptAlias /bin/ PATH_TO_NikoloCMS/bin/
    <Directory "PATH_TO_NikoloCMS/">
        AllowOverride All
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Order allow,deny
        Allow from all
    </Directory>
    <Location /bin>
        AddHandler cgi-script .cgi
    </Location>
</VirtualHost>
