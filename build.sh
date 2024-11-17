docker built -t $1 .
docker run -p 8080:8080 $1