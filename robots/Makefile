.PHONY: all
all:
	rm -f *.robot
	cp ../bin/robot.tcl .robot.tcl
	for user in $$(getent passwd \
	                 | awk -F: '$$3 >= 10000 { print $$1 }'); do \
 	  ln -f .robot.tcl $${user}.robot; \
	done
