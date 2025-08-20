DIST_DIR = public

all: help

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  dev - Run Hugo server in development mode"
	@echo "  new - Create a new post"
	@echo "  build - Build the site"
	@echo "  clean - Clean the generated files"
	@echo "  deploy - Deploy the site"

dev:
	@hugo server -p 3000 -D

.PHONY: new
new:
	@if [ -z "$(title)" ]; then \
		echo "Error: Please provide a title parameter"; \
		echo "Usage: make new title=my-post-title"; \
		exit 1; \
	fi; \
	title_clean=$$(echo "$(title)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g'); \
	if [ -z "$$title_clean" ]; then \
		echo "Error: Title contains no valid characters"; \
		exit 1; \
	fi; \
	echo "Creating new post: $$title_clean"; \
	hugo new posts/"$$title_clean"/index.md

.PHONY: build
build:
	@hugo --minify --destination=$(DIST_DIR) --gc
	
.PHONY: clean
clean:
	@echo "Cleaning Hugo generated files..."
	@rm -rf $(DIST_DIR)/
	@rm -rf resources/_gen/
	@rm -f .hugo_build.lock
	@echo "Clean completed!"

.PHONY: deploy
deploy:
	cd $(DIST_DIR) && \
	git add . && \
	git commit -m "Upload blog" && \
	git push origin master && \
	cd ..
