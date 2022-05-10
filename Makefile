# -*- mode:makefile; coding:utf-8 -*-

.DEFAULT_GOAL = dependency-pre-commit

#
# pre-commit
#

dependency-pre-commit:
	pre-commit install
