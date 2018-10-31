FROM scottmtraver/todobackend-base:latest

MAINTAINER Scott Traver

COPY target /wheelhouse

RUN apt-get update -qy && \
    apt-get install -qy uwsgi-plugin-python3

RUN . /appenv/bin/activate && \
    pip install --no-index -f /wheelhouse todobackend && \
    rm -rf /wheelhouse
