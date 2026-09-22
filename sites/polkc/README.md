# Polibiuro K C

Strona firmy **Polibiuro KC Andrzej Siejak** (Jarocin): sprzedaż, serwis i naprawa drukarek i kserokopiarek oraz leasing.

Statyczny HTML/CSS/JS, bez kroku budowania — ten sam wzorzec co `s3lcsum/miedzysztuka`. Publiczny host: [https://polkc.dominiksiejak.pl](https://polkc.dominiksiejak.pl) (Cloudflare Pages project `polkc`).

## Lokalnie

```sh
python3 -m http.server 8000
```

Otwórz [http://localhost:8000](http://localhost:8000).

## Deploy

```sh
npx wrangler pages deploy . --project-name=polkc
```

## Dane na stronie

Tylko to, co jest publiczne w katalogach i Google Maps. Nie dopisywać maila, NIP-u ani godzin „na oko”.
