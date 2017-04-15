build: Boxfile
	docker run --rm -ti \
	  -v $(PWD):$(PWD) \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -w $(PWD) \
	    boxbuilder/box:master Boxfile

push: build
	docker push errordeveloper/kxd:kubelet
	docker push errordeveloper/kxd:shell
