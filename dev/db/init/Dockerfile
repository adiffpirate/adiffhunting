# Use an official Python image as the base
FROM python:3.11-slim

# Install Python dependencies
COPY _requirements.txt /src/_requirements.txt
RUN python3 -m pip install --no-cache-dir -r /src/_requirements.txt

# Copy the application files
COPY _utils /src/_utils
COPY db/init/app.py /src/app.py

# Run app
CMD ["python3", "/src/app.py"]
