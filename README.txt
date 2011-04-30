
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
hypnotoad --config /usr/local/www/NikoloCMS/bin/hypnotoad.conf /usr/local/www/NikoloCMS/bin/nikolo.psgi
starman -R PATH_TO_NikoloCMS/lib/,PATH_TO_NikoloCMS/templates/ nikolo.psgi

Nginx:
upstream backendurl {
        server 0:5000;
}
server {
        listen       80;
        server_name  poscheck.ru;
        access_log   /var/log/nginx-posckeck-access.log;
        error_log    /var/log/nginx-posckeck-error.log;
        root         /usr/local/www/NikoloCMS;
        location / {
                proxy_read_timeout 300;
                proxy_set_header Host $http_host;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_pass       http://backendurl;
        }
}


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

