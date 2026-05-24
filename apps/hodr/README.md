# hodor
A golang http service

# setup

```bash
go mod download # download deps
go run main.go # run app
```

- App uses OS environment for config
- http://127.0.0.1:8000/metrics - returns app metrics
- http://127.0.0.1:8000/* - returns hodor...hodor..hodor.. 
