FROM python:3.7.5

RUN apt-get -q update && apt-get install -y -q \
  sqlite3 --no-install-recommends \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG C.UTF-8

RUN pip install --upgrade pip

RUN mkdir -p /app
WORKDIR /app

ADD ./appy /app

# TODO: Poetry vs pip. Doesn't seem to pick up poetry installed deps
RUN pip install .

# CMD python manage.py runserver
CMD gunicorn -b :8000 appy.wsgi