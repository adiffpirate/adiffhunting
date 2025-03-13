FROM python:3.11-slim

# Install Python dependencies
COPY _requirements.txt /src/_requirements.txt
RUN python3 -m pip install --no-cache-dir -r /src/_requirements.txt

# Copy utils
ENV UTILS=/src/_utils
COPY _utils $UTILS

# Run app
COPY recon/rootenum/app.py /src/app.py
CMD ["python3", "/src/app.py"]
