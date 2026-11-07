# Immagine piccola
FROM python:3.12-slim

WORKDIR /app

# Prima solo le dipendenze: questo layer resta in cache finche' requirements.txt non cambia
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Poi il codice: cambia spesso, quindi sta in fondo
COPY app/ .

# Non girare come root
RUN useradd --system --uid 1000 appuser
USER appuser

EXPOSE 8000
CMD ["python", "app.py"]
