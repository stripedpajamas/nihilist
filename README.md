# nihilist

## use
after cloning: 

```shell
$ zig build-exe main.zig --name nihilist

$ ./nihilist
Usage: nihilist <encrypt|decrypt> <polybius_key> <nihilist_key> <plaintext|ciphertext>

$ ./nihilist encrypt asdf fdsa "hello world"
38 35 44 43 49 65 47 54 46 26

$ ./nihilist decrypt asdf fdsa "38 35 44 43 49 65 47 54 46 26"
HELLOWORLD
```

## what is it
it's this: https://en.wikipedia.org/wiki/Nihilist_cipher

it's not a secure cipher at all. it's for playing.

## license
AGPL 3.0

