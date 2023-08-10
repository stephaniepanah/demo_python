FROM python:3.8-slim-buster

WORKDIR /app

COPY . .

RUN pip3 install -r requirements.txt

RUN pytest --cov=. --cov-report html 

RUN flake8 --format=html --htmldir=flake-report


CMD ["python3", "-m" , "flask", "run", "--host=0.0.0.0"]
