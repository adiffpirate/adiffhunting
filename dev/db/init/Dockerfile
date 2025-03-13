# Use an official Python image as the base
FROM python:3.11-slim

# Copy utils dir
ENV UTILS=/src/_utils
COPY _utils $UTILS

# Install Python dependencies
RUN python3 -m pip install --no-cache-dir -r $UTILS/requirements.txt

# Copy the application files
COPY db/init/app.py /src/

# Run app
CMD ["python3", "/src/app.py"]
