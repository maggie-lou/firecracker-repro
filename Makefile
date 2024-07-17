.PHONY: test clean

test: test.sh firecracker vmlinux initrd.cpio
	./test.sh

clean:
	git clean -fdx

vmlinux: vmlinux_url.txt
	curl -fL $$(cat $^) -o $@
	chmod +x vmlinux

firecracker: firecracker_url.txt
	curl -fL $$(cat $^) -o firecracker.tgz
	tar xvf firecracker.tgz
	cp release-*/firecracker-*-x86_64 $@
	chmod +x $@
	rm -rf firecracker.tgz release-*

initrd.cpio: init
	find init -print0 | cpio --null --create --verbose --format=newc > $@
	chmod +x $@

init: init.go
	go build -o $@ $^
