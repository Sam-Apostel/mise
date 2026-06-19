.PHONY: help shared server-build server-run server-test app-gen app-build app-test test docker railway-deploy

SIM ?= iPhone 17

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

shared: ## Build the shared models package
	cd Shared && swift build

server-build: ## Build the Vapor server
	cd server && swift build

server-run: ## Run the server locally on :8080
	cd server && swift run App serve --hostname 0.0.0.0 --port 8080

server-test: ## Run server tests
	cd server && swift test

app-gen: ## Generate the Xcode project from project.yml
	cd app && xcodegen generate

app-build: app-gen ## Build the iOS app for the simulator
	cd app && xcodebuild -project Mise.xcodeproj -scheme Mise \
		-destination 'platform=iOS Simulator,name=$(SIM)' build

app-test: app-gen ## Run iOS app tests
	cd app && xcodebuild -project Mise.xcodeproj -scheme Mise \
		-destination 'platform=iOS Simulator,name=$(SIM)' test

test: server-test app-test ## Run all tests

docker: ## Build the server Docker image (uses repo root as build context)
	docker build -f server/Dockerfile -t mise-server .

railway-deploy: ## Deploy the server to Railway (requires `railway link` first)
	railway up
