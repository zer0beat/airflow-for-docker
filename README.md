# Apache Airflow for Docker
## Version 1.9.0

## Sample Usage:

From your checkout directory:

1. Build the image

        VERSION=1.9.0
        FOLDER=1.x.x
        cd ${FOLDER}
        docker build --build-arg VERSION=${VERSION} -t airflow:${VERSION} .
		
2. Run the image

        VERSION=1.9.0
        docker run --rm -p 18080:18080 airflow:${VERSION}

## Useful links

* [Apache Airflow docs](https://airflow.incubator.apache.org/index.html)
* [Docker Swarm secrets](https://docs.docker.com/engine/swarm/secrets/#advanced-example-use-secrets-with-a-wordpress-service)
* [MySQL entrypoint](https://raw.githubusercontent.com/docker-library/mysql/dc60c4b80f3eb5b7ef8b9ae09f16f6fab7a2fbf5/8.0/docker-entrypoint.sh)