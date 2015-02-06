.PHONY: all install uninstall
all:
install:
	ln -fs ${PWD}/backup.sh ~/bin/
uninstall:
	rm ~/bin/backup.sh
