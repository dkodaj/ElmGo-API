# Elm/Go API

An Elm webapp sends requests to a Go server connected to a Postgres database.

If you have Docker and docker-compose, run

```
$ git clone https://github.com/dkodaj/ElmGo-API.git
$ cd elmgo-api
$ docker-compose up
```

If you have Elm, Go, and Postgres installed, then create a Postgres database called `elmgoapi` (user `elmgoapi`, password `elmgoapi`), and run

```
$ git clone https://github.com/dkodaj/ElmGo-API.git
$ cd elmgo-api
$ make
```

Assumption: Postgres is listening on localhost:5432.