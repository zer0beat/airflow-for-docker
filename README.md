# Apache Airflow for Docker

[![Build Status](https://travis-ci.org/zer0beat/airflow-for-docker.svg?branch=master)](https://travis-ci.org/zer0beat/airflow-for-docker)

A Docker image based on Apache Airflow. Airflow is a platform to programmatically author, schedule, and monitor workflows.

## Image features

With the default configuration scripts this image:
* Supports Sequential, Local, Celery and Dask executors
* Supports single node execution (webserver and scheduler on the same container)
* Supports MySQL and Postgres backends
* Supports all the RabbitMQ and Redis as Celery backends

## How to use this image

### Run image manually

```
$ docker run --rm z0beat/airflow
```

With this command you get the Airflow version used on this image.

### Use docker compose

This repository contains some example compose files to run Airflow with different configurations.

#### Sequential executor + SQLite backend (Single node)
```
$ docker-compose -f docker-compose-sequential-sqlite.yml up -d
```

#### Local executor + MySQL backend
```
$ docker-compose -f docker-compose-local-mysql.yml up -d
```

#### Local executor + Postgres backend
```
$ docker-compose -f docker-compose-local-postgres.yml up -d
```

#### Dask executor + MySQL backend
```
$ docker-compose -f docker-compose-dask-mysql.yml up -d
```

#### Celery executor + Redis broker + MySQL backend
```
$ docker-compose -f docker-compose-celery-mysql-redis.yml up -d
```

#### Celery executor + RabbitMQ broker + MySQL backend
```
$ docker-compose -f docker-compose-celery-mysql-rabbitmq.yml up -d
```

## Airflow configuration

To configure Airflow, this image, run the scripts located on `/opt/airflow.d` inside container. The default scripts provides the ability to configure the application [using environment variables](https://airflow.incubator.apache.org/configuration.html#setting-configuration-options).

Supported variables with default scripts:

### Single node configuration

* **SINGLE_NODE**: (True|**False**) Runs initdb and scheduler on background on background.

### Multi node configuration

* **INITDB**: (True|**False**) Runs initdb before run CMD on container
* **START_DELAY**: (in seconds, **1**) Runs a sleep with START_DELAY to prevent race conditions with the initdb commands.

### Airflow configuration

* **EXECUTOR**: Executor used by Airflow
  - SequentialExecutor
  - LocalExecutor
  - CeleryExecutor
  - DaskExecutor
* **BACKEND**: Backend used by Airflow
  - sqlite
  - mysql
  - postgres

### Backend configuration

Variables only used if **mysql** or **postgres** backends are selected.

* **BACKEND_USER**
* **BACKEND_PASSWORD**
* **BACKEND_DATABASE**
* **BACKEND_HOST**
* **BACKEND_PORT**

### Celery configuration

Variables only used if **CeleryExecutor** is selected.

* **BROKER**: Broker used by Celery
  - redis
  - rabbitq
* **CELERY_BACKEND**: Backend used by Celery (defaults to BACKEND)
  - mysql
  - postgres

### Celery broker configuration

* **CELERY_BROKER_USER**
* **CELERY_BROKER_PASSWORD**
* **CELERY_BROKER_HOST**
* **CELERY_BROKER_PORT**

### Celery backend configuration

This variables defaults to BACKEND_* values

* **CELERY_BACKEND_USER**
* **CELERY_BACKEND_PASSWORD**
* **CELERY_BACKEND_DATABASE**
* **CELERY_BACKEND_HOST**
* **CELERY_BACKEND_PORT**

### Dask configuration

Variables only used if **DaskExecutor** is selected.

* **DASK_HOST**
* **DASK_PORT**

## Add, replace or disable Airflow configuration scripts

As mentioned before, this image run the scripts from `/opt/airflow.d` to configure the application. This behaviour gives you the ability of run your own configuration scripts if you mount a volume.

To disable the auto configuration with the scripts mentioned above, you can set the variable `AIRFLOW_AUTOCONF=False`.

You can also change the path of the configuration scripts modifying the variable `AIRFLOW_CONF`.

## Useful links

* [Apache Airflow docs](https://airflow.incubator.apache.org/index.html)
* [Docker Swarm secrets](https://docs.docker.com/engine/swarm/secrets/#advanced-example-use-secrets-with-a-wordpress-service)
* [MySQL entrypoint](https://raw.githubusercontent.com/docker-library/mysql/dc60c4b80f3eb5b7ef8b9ae09f16f6fab7a2fbf5/8.0/docker-entrypoint.sh)