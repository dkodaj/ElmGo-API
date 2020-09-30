default:
	cd src/backend && go get -d	
	elm make src/frontend/Main.elm --output src/frontend/Main.js
	cd src && go run backend/api.go
