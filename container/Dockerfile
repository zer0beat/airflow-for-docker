# Based on https://github.com/puckel/docker-airflow
FROM debian:9

ENV AIRFLOW_VERSION=1.8.1
ENV AIRFLOW_HOME=/opt/airflow

RUN set -x && \
    apt-get update -yqq && \
    apt-get install -yqq python-pip python-dev libmariadbclient-dev && \
    pip install apache-airflow[crypto,mysql]==$AIRFLOW_VERSION && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

VOLUME ["${AIRFLOW_HOME}/dags"]
EXPOSE 8080
WORKDIR ${AIRFLOW_HOME}

ADD script/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["airflow","webserver"]