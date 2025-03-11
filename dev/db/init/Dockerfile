# Use an official Python image as the base
FROM python:3.11-slim

# Copy utils dir
COPY _utils /src/_utils

# Install Python dependencies
RUN pip install --no-cache-dir -r /src/_utils/requirements.txt

# Set the working directory
WORKDIR /app

# Copy the application files
COPY main.py .

# Run app
CMD ["python", "main.py"]
