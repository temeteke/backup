.PHONY: all install uninstall
all:
install:
	cp ${PWD}/backup.sh ~/bin/
uninstall:
	rm ~/bin/backup.sh
