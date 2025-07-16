# make_env.mk
# This file defines a function to load environment variables from .env
# It is designed to be included at the top of a main Makefile.
# Define 'empty' and 'space' variables for robust string manipulation
empty :=
space := $(empty) $(empty)
define load_env_vars
$(foreach line,$(shell cat .env | grep -v '^\s*#'),\
	$(eval processed_line := $(strip $(firstword $(subst #,$(space),$(line)))))\
	$(if $(findstring =,$(processed_line)),\
		$(eval $(processed_line))\
    	$(eval export $(processed_line))\
	)\
)
endef