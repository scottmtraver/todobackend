PROJECT_NAME ?= todobackend
ORG_NAME ?= scottmtraver
REPO_NAME ?= todobackend

DEV_COMPOSE_FILE := docker/dev/docker-compose.yml
REL_COMPOSE_FILE := docker/release/docker-compose.yml

REL_PROJECT := $(PROJECT_NAME)$(BUILD_ID)
DEV_PROJECT := $(REL_PROJECT)dev

DOCKER_REGISTRY ?= docker.io

APP_SERVICE_NAME := app

BUILD_TAG_EXPRESSION ?= date -u +%Y%m%d%H%M%S

BUILD_EXPRESSION := $(shell $(BUILD_TAG_EXPRESSION))

BUILD_TAG ?= $(BUILD_EXPRESSION)

INSPECT := $$(docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
	if [[ $(INSPECT) -ne 0 ]]; \
	then exit $(INSPECT); fi' VALUE

DOCKER_REGISTRY_AUTH ?=

.PHONY: test build release clean tag buildtag login logout publish

test:
	${INFO} "Creating Volumes..."
	@ docker volume create --name cache
	${INFO} "Pulling Latest Images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) pull
	${INFO} "Building Images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build --pull test
	${INFO} "Ensuring Database Is Available..."
	@ docker-compose  -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	${INFO} "Running Unit Tests..."
	@ docker-compose  -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test
	${INFO} "Testing Complete"

build:
	${INFO} "Creating Builder Image..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build builder
	${INFO} "Building Application Artifacts..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	${INFO} "Copying Artifacts..."
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	${INFO} "Build Complete"

release:
	${INFO} "Pulling Latest Images..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) pull test
	${INFO} "Building Images..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build app
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build --pull nginx
	${INFO} "Ensuring Database Is Available..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm agent
	${INFO} "Collecting Static Files..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	${INFO} "Running Database Migrations..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	${INFO} "Running Acceptance Tests..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(REL_PROJECT) $(REL_COMPOSE_FILE) test
	${INFO} "Acceptance Testing Complete"

clean:
	${INFO} "Destroying Development Environment..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) down -v
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) kill
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) rm -f -v
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) down -v
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) kill
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) rm -f -v
	@ docker images -q -f dangling=true -f label=application=$(REPO_NAME) | xargs -I ARGS docker rmi -f ARGS
	@ docker volume rm cache
	${INFO} "Clean Complete"

tag:
	${INFO} "Tagging Release Images with Tags [$(TAG_ARGS)]..."
	@ $(foreach tag,$(TAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)
	${INFO} "Tagging Complete"

buildtag:
	${INFO} "Tagging Release Images with suffix $(BUILD_TAG) and build tags [$(BUILDTAG_ARGS)]..."
	@ $(foreach tag,$(BUILDTAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag).$(BUILD_TAG);)
	${INFO} "Tagging Complete"

login:
	${INFO} "Logging in to Docker Registry $$DOCKER_REGISTRY..."
	@ docker login -u $$DOCKER_USER -p $$DOCKER_PASSWORD $(DOCKER_REGISTRY_AUTH)
	${INFO} "Logged in to Docker Registry $$DOCKER_REGISTRY"

logout:
	${INFO} "Logging Out from Docker Registry $$DOCKER_REGISTRY..."
	@ docker logout
	${INFO} "Logged Out from Docker Registry $$DOCKER_REGISTRY"

publish:
	${INFO} "Publishing Release Image $(IMAGE_ID) to $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)..."
	@ $(foreach tag,$(shell echo $(REPO_EXPR)), docker push $(tag);)
	${INFO} "Publish Complete"


YELLOW := "\e[1;33m"
NC := "\e[0m"

INFO := @bash -c '\
	printf $(YELLOW); \
	echo "=> $$1"; \
	printf $(NC)' VALUE

APP_CONTAINER_ID := $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))

IMAGE_ID := $$(docker inspect -f '{{ .Image }}' $(APP_CONTAINER_ID))

# This should be wrapped in an IF statement or match the filtering mechanism of your private repo!
# From: Enhancing the Workflow: Publishing the Release Image
REPO_FILTER := $(ORG_NAME)/$(REPO_NAME)[^[:space:]|\$$]*

REPO_EXPR := $$(docker inspect -f '{{range .RepoTags}}{{.}} {{end}}' $(IMAGE_ID) | grep -oh "$(REPO_FILTER)" | xargs)

ifeq (tag,$(firstword $(MAKECMDGOALS)))
    TAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    ifeq ($(TAG_ARGS),)
        $(error You must specify a tag)
    endif
    $(eval $(TAG_ARGS):;@:)
endif

ifeq (buildtag,$(firstword $(MAKECMDGOALS)))
    BUILDTAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    ifeq ($(BUILDTAG_ARGS),)
        $(error You must specify a build tag)
    endif
    $(eval $(BUILDTAG_ARGS):;@:)
endif
