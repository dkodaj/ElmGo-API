package main


import (
	"context"
	"encoding/json"
	"crypto/rand"
	"fmt"
	"github.com/jackc/pgx"
	"github.com/jackc/pgx/pgxpool"
	"github.com/valyala/fasthttp"
	"log"
	"strings"
)


type ApiData struct {
    Id int `json:"id"`
    Garble string `json:"garble"`
}


type RequestError struct {
    Error string `json:"error"`
}


func main() {

	// Create & populate test table
	err := ApiTable("elmgoapi", "elmgoapi", "elmgoapi")

	if err != nil {
		log.Println("Error creating API table:")
		log.Fatal(err)
	}

	// Connect to db
	db, err := ConnectDB("elmgoapi", "elmgoapi", "elmgoapi")

	if err != nil {
		log.Println("Error connecting to db:")
		log.Fatal(err)
	}

	// Web router
	httpHandler := func(ctx *fasthttp.RequestCtx){
		
		requestURI := string(ctx.RequestURI())

		URIsegments := strings.Split(strings.TrimPrefix(requestURI, "/"), "/")
		// "/asset/index.html"  => ["asset", "index.html"]

		if len(URIsegments) > 0 {
			switch URIsegments[0] {
				case "":
					// requested 'localhost:8080/'
					fasthttp.ServeFile(ctx, "frontend/index.html")

				case "api":
					// extract POST request parameter
					id := string(ctx.Request.PostArgs().Peek("id"))
					// fetch from postgres
					ctx.Write(Fetch(id,db))

				case "asset":
					if len(URIsegments) > 1 {
						fasthttp.ServeFile(ctx, "frontend/" + strings.TrimPrefix(requestURI, "/asset/"))
					}
			}
		}		
	}	
	
	// Define HTTP server
	httpServer := &fasthttp.Server{	    
	    Handler: httpHandler,
	}

	// Start HTTP server in a goroutine
	go func() {
		if err := httpServer.ListenAndServe(":8080"); err != nil {
			log.Fatalf("Error in http ListenAndServe: %s", err)
		}
	}()

	log.Println("Server started! Browse to localhost:8080.")
	
	// Wait forever (allow the goroutine to run indefinitely)
	select {}
}


func ApiTable(dbname, user, pwd string) error {

	connString := "user=" + user + " password=" + pwd + " host=localhost port=5432 dbname=" + dbname

	config, _ := pgx.ParseConfig(connString)

	db, err := pgx.ConnectConfig(context.Background(), config)	

	if err != nil {
		return err
	}

	create :=
	    `DROP TABLE IF EXISTS apitable;
	     CREATE TABLE apitable
	        (  id SERIAL PRIMARY KEY,
	           garble text DEFAULT ''
	        );
	    `
	
	_, err = db.Exec(context.Background(), create)

	if err != nil {
		return err
	}

	for i := 0; i < 100; i++ {

		b := make([]byte, 20)
		_, err := rand.Read(b)
		if err != nil {
			log.Println(err)
		}
		garble := fmt.Sprintf("%x", b)

		_, err = db.Exec(context.Background(), `INSERT INTO apitable (id, garble) values ($1,$2)`, i, garble)

	    if err != nil {
	    	return err
	    }
	}

    return nil
}


func ConnectDB(dbname, user, pwd string) (*pgxpool.Pool, error) {

	connString := "user=" + user + " password=" + pwd + " host=localhost port=5432 dbname=" + dbname
	// official template:
	// 		"user=jack password=secret host=pg.example.com port=5432 dbname=mydb sslmode=verify-ca pool_max_conns=10"

	config, _ := pgxpool.ParseConfig(connString)

	config.AfterConnect = func(context context.Context, conn *pgx.Conn) error {

		// Prepared statements make SQl queries faster
		_, err := conn.Prepare(context, "fetch", "SELECT * FROM apitable WHERE id = $1")

		return err
	}

	return pgxpool.ConnectConfig(context.Background(), config)	
}


func Fetch(id string, db *pgxpool.Pool) []byte {
	row := db.QueryRow(context.Background(), "fetch", id)
	var apiData ApiData
	err := row.Scan(&apiData.Id, &apiData.Garble)
	if err != nil {
		requestError := RequestError { Error : err.Error() }
		bytes, err2 := json.Marshal(requestError)
		if err2 != nil {
			log.Println(err)
			return []byte("Server error: can't generate JSON.")
		} else {
			return bytes
		}
	}
	bytes, err := json.Marshal(apiData)
	if err != nil {
		log.Println(err)
		return []byte("Server error: can't generate JSON.")
	}
	return bytes
}
