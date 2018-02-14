# Based on https://github.com/puckel/docker-airflow
FROM debian:9

ARG VERSION

ENV AIRFLOW_HOME        /opt/airflow
ENV AIRFLOW_VERSION     ${VERSION}

RUN set -x && \
    apt-get update -yqq && \
    apt-get install -yqq python-pip python-dev libmariadbclient-dev && \
    pip install apache-airflow[crypto,mysql,oracle,sqlite]==$AIRFLOW_VERSION && \
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
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["airflow","webserver"]