# Step 1: Use a lightweight Python image
FROM python:3.10-slim

# Step 2: Set the working directory inside the container
WORKDIR /app

# Step 3: Copy requirements.txt first
COPY requirements.txt .

# Step 4: Install dependencies (Flask)
RUN pip install --no-cache-dir -r requirements.txt

# Step 5: Copy the rest of your project files
COPY . .

# Expose Cloud Run port
ENV PORT=8080
EXPOSE 8080

# Step 7: Command to run your app
CMD ["python", "app.py"]

# Run with Gunicorn (recommended for production)
CMD exec gunicorn --bind :$PORT main:app
