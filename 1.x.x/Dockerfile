FROM python:3.6-slim-stretch

ARG VERSION

ENV AIRFLOW_HOME        /opt/airflow
ENV AIRFLOW_VERSION     ${VERSION}

RUN buildDeps=" \
        build-essential \
    " && \
    runtimeDeps=" \
        libmariadbclient-dev \
    " && \
    apt-get update && apt-get install -y --no-install-recommends $buildDeps $runtimeDeps && \
    pip install apache-airflow[crypto,mysql,oracle]==$AIRFLOW_VERSION && \
    apt-get purge -y --auto-remove $buildDeps && \
	rm -rf /var/lib/apt/lists/*

VOLUME ["${AIRFLOW_HOME}/dags"]
EXPOSE 8080
WORKDIR ${AIRFLOW_HOME}

ADD script/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["airflow","webserver"]