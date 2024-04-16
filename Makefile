
DOCKER_IMAGE = "infrabuilder/benchmark-k8s-cni-2024-01"

help:
	echo "Usage: make <target>"
	echo "Targets:"
	echo "- results: (Re)start the explorer stack, import the results and open Grafana"
	echo "- docker: Build and push the docker image"
	echo "- explorer_stop: Stop the explorer"
	echo "- explorer_start: Start the explorer"
	echo "- explorer_import: Import the
	echo "- help: Show this help"
	"

results: explorer_stop explorer_start explorer_import

docker:
	@docker build -t $(DOCKER_IMAGE) .
	@docker push $(DOCKER_IMAGE)

explorer_stop:
	./explorer/explorer.sh stop

explorer_start:
	./explorer/explorer.sh start

explorer_import:
	./explorer/explorer.sh import results
