FROM python:3.11-slim

# Installa dipendenze di sistema
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Crea utente non-root
RUN useradd --create-home --shell /bin/bash securevox

# Imposta variabili d'ambiente
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Imposta directory di lavoro
WORKDIR /app

# Copia requirements e installa dipendenze Python
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copia il codice
COPY src/ /app/src/
COPY manage.py /app/manage.py

# Crea directory per log
RUN mkdir -p /var/log/securevox && chown -R securevox:securevox /var/log/securevox

# Cambia proprietario dei file
RUN chown -R securevox:securevox /app

# Cambia utente
USER securevox

# Esponi porta
EXPOSE 8080

# Comando di avvio
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "--timeout", "120", "src.wsgi:application"]
