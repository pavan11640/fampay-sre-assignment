# bran
A django app

# setup 

```bash
poetry install # install deps
cd backend # project dir
python manage.py migrate # run db migrations 
python manage.py runserver # run local server
```

- On app start it loads .env file into os env variables for the configuration, optionally it works with os variables supplied to process too.
- By default it uses sqlite db, you can provide valid [URL schema](https://github.com/jazzband/dj-database-url/#url-schema) to use postgres/mysql
- http://127.0.0.1:8000/bran/* will return list users stored in db
- http://127.0.0.1:8000/metrics - returns app metrics
