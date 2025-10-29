# Usa immagine ufficiale di Janus
FROM meetecho/janus-gateway:latest

# Copia configurazioni
COPY janus.jcfg /usr/local/etc/janus/janus.jcfg
COPY janus.plugin.videoroom.jcfg /usr/local/etc/janus/janus.plugin.videoroom.jcfg
COPY janus.transport.http.jcfg /usr/local/etc/janus/janus.transport.http.jcfg

# Esponi porte
EXPOSE 8088 8188 10000-20000/udp

# Comando di avvio
CMD ["janus", "--configs-folder=/usr/local/etc/janus"]
