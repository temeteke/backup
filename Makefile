.PHONY: all install uninstall
all:

install:
	cp -a ${PWD}/backup.sh ~/bin/

uninstall:
	rm ~/bin/backup.sh
