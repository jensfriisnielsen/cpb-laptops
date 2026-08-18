unlock: git-crypt-key
	mkdir -p .git/git-crypt/keys/
	ln -sf ../../../git-crypt-key .git/git-crypt/keys/default
	git-crypt unlock

git-crypt-key: git-crypt-key.enc
	openssl aes-256-cbc -d -pbkdf2 -in $@.enc -out $@

git-crypt-key.enc:
	openssl aes-256-cbc -pbkdf2 -in git-crypt-key -out $@

