#!/usr/bin/env bash

if [[ -z "${HTTP_URL:-}" ]]; then
    echo "HTTP_URL not set"
    exit 3
fi

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$HTTP_URL")

case "$code" in
    200)
        echo "$HTTP_URL answered 200"
        exit 0
        ;;
    000)
        echo "$HTTP_URL did not answer (connection failed or took over 5s)"
        exit 2
        ;;
    5??)
        echo "$HTTP_URL answered HTTP $code (server error)"
        exit 2
        ;;
    "")
        echo "could not run curl"
        exit 3
        ;;
    *)
        echo "$HTTP_URL answered HTTP $code (expected 200)"
        exit 1
        ;;
esac
