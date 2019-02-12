SHELL := /bin/bash
all:
	$(MAKE) -C util
	$(MAKE) -C mme/sec MACHINE=BIT64
	pushd mme; ./build; popd

clean:
	$(MAKE) -C util clean
	$(MAKE) -C mme/sec clean
	pushd mme; ./clean; popd

#install:
#	$(MAKE) -C c3poutil install
