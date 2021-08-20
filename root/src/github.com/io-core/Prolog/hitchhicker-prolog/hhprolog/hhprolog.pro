# Description: hitchhicker Prolog
#
# Original Java code by Paul Tarau.
# The reference document: http://www.cse.unt.edu/~tarau/research/2017/eng.pdf
#
# Author: Carlo Capelli
# Version: 1.0.0
# License: MIT
# Copyright (c) 2018 Carlo Capelli

TEMPLATE = app

CONFIG += console c++11
CONFIG -= app_bundle qt

SOURCES += \
    main.cpp \
    engine.cpp \
    prog.cpp \
    toks.cpp

HEADERS += \
    hhprolog.h \
    file2string.h
