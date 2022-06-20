all: dev

dev:
	@hugo server -p 3000 -D

.PHONY: new
new:
	@installdir='$(title)'; \
    [ -n "$$title" ] || { echo "Please add title=... on the command line"; exit 1; };\
	hugo new posts/"$${title}"/index.md;

.PHONY: build
build:
	@hugo --minify --destination=public --gc

.PHONY: deploy
deploy:
	cd public && \
	git add . && \
	git commit -m "Upload blog" && \
	git push origin master && \
	cd ..
