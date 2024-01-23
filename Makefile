
DOCKER_IMAGE = "infrabuilder/benchmark-k8s-cni-2024-01"

docker:
	@docker build -t $(DOCKER_IMAGE) .
	@docker push $(DOCKER_IMAGE)

results: explorer_start explorer_import

explorer_start:
	./explorer/explorer.sh stop
	./explorer/explorer.sh start

explorer_import:
	./explorer/explorer.sh import results