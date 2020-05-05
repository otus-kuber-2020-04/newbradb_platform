FROM httpd:2.4

RUN usermod -u 1001 nobody 

COPY app/ /app
COPY httpd.conf /usr/local/apache2/conf/

RUN chown -R nobody: /app
RUN chown -R nobody: /usr/local/apache2/logs/

EXPOSE 8000 
USER 1001
