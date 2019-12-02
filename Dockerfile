FROM python:3.7.5

RUN apt-get -q update && apt-get install -y -q \
  sqlite3 --no-install-recommends \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG C.UTF-8

RUN pip install --upgrade pip

RUN mkdir -p /app
WORKDIR /app

# Add requirements file separately so dependencies are cached.
ADD ./requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

ADD ./appy /app

# CMD python manage.py runserver
CMD gunicorn -b :8000 --capture-output --enable-stdio-inheritance appy.wsgi