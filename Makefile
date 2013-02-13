#
# Copyright 2011, Ben Langmead <langmea@cs.jhu.edu>
#
# This file is part of Bowtie 2.
#
# Bowtie 2 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Bowtie 2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Bowtie 2.  If not, see <http://www.gnu.org/licenses/>.
#

#
# Makefile for bowtie, bowtie2-build, bowtie2-inspect
#

INC =
GCC_PREFIX = $(shell dirname `which gcc`)
GCC_SUFFIX =
CC = $(GCC_PREFIX)/gcc$(GCC_SUFFIX)
CPP = $(GCC_PREFIX)/g++$(GCC_SUFFIX)
CXX = $(CPP)
HEADERS = $(wildcard *.h)
BOWTIE_PTHREADS = 1
BOWTIE_MM = 1
BOWTIE_SHARED_MEM = 0

# Detect Cygwin or MinGW
WINDOWS = 0
ifneq (,$(findstring CYGWIN,$(shell uname)))
WINDOWS = 1
# POSIX memory-mapped files not currently supported on Windows
BOWTIE_MM = 0
BOWTIE_SHARED_MEM = 0
else
ifneq (,$(findstring MINGW,$(shell uname)))
WINDOWS = 1
# POSIX memory-mapped files not currently supported on Windows
BOWTIE_MM = 0
BOWTIE_SHARED_MEM = 0
endif
endif

MACOS = 0
ifneq (,$(findstring Darwin,$(shell uname)))
MACOS = 1
endif

MM_DEF = 
ifeq (1,$(BOWTIE_MM))
MM_DEF = -DBOWTIE_MM
endif
SHMEM_DEF = 
ifeq (1,$(BOWTIE_SHARED_MEM))
SHMEM_DEF = -DBOWTIE_SHARED_MEM
endif
PTHREAD_PKG =
PTHREAD_LIB =
PTHREAD_DEF =
ifeq (1,$(BOWTIE_PTHREADS))
PTHREAD_DEF = -DBOWTIE_PTHREADS
ifeq (1,$(WINDOWS))
# pthreads for windows forces us to be specific about the library
PTHREAD_LIB = -lpthreadGC2
PTHREAD_PKG = pthreadGC2.dll
else
# There's also -pthread, but that only seems to work on Linux
PTHREAD_LIB = -lpthread
endif
endif

LIBS = 
SEARCH_LIBS = $(PTHREAD_LIB)
BUILD_LIBS =

SHARED_CPPS = ccnt_lut.cpp ref_read.cpp alphabet.cpp shmem.cpp \
              edit.cpp bt2_idx.cpp bt2_io.cpp bt2_util.cpp \
              reference.cpp ds.cpp multikey_qsort.cpp limit.cpp \
              random_source.cpp
SEARCH_CPPS = qual.cpp pat.cpp sam.cpp \
              read_qseq.cpp aligner_seed_policy.cpp \
              aligner_seed.cpp \
              aligner_seed2.cpp \
              aligner_sw.cpp \
              aligner_sw_driver.cpp aligner_cache.cpp \
              aligner_result.cpp ref_coord.cpp mask.cpp \
              pe.cpp aln_sink.cpp dp_framer.cpp \
              scoring.cpp presets.cpp unique.cpp \
              simple_func.cpp \
              random_util.cpp \
              aligner_bt.cpp sse_util.cpp \
              aligner_swsse.cpp outq.cpp \
              aligner_swsse_loc_i16.cpp \
              aligner_swsse_ee_i16.cpp \
              aligner_swsse_loc_u8.cpp \
              aligner_swsse_ee_u8.cpp \
              aligner_driver.cpp
SEARCH_CPPS_MAIN = $(SEARCH_CPPS) bowtie_main.cpp

BUILD_CPPS = diff_sample.cpp
BUILD_CPPS_MAIN = $(BUILD_CPPS) bowtie_build_main.cpp

SEARCH_FRAGMENTS = $(wildcard search_*_phase*.c)
VERSION = $(shell cat VERSION)
EXTRA_FLAGS =

# Convert BITS=?? to a -m flag
BITS=32
ifeq (x86_64,$(shell uname -m))
BITS=64
endif
BITS_FLAG =
ifeq (32,$(BITS))
BITS_FLAG = -m32
endif
ifeq (64,$(BITS))
BITS_FLAG = -m64
endif

SSE_FLAG=-msse2

DEBUG_FLAGS    = -O0 -g3 $(BITS_FLAG) $(SSE_FLAG)
DEBUG_DEFS     = -DCOMPILER_OPTIONS="\"$(DEBUG_FLAGS) $(EXTRA_FLAGS)\""
RELEASE_FLAGS  = -O3 $(BITS_FLAG) $(SSE_FLAG) -funroll-loops -g3
RELEASE_DEFS   = -DCOMPILER_OPTIONS="\"$(RELEASE_FLAGS) $(EXTRA_FLAGS)\""
NOASSERT_FLAGS = -DNDEBUG
FILE_FLAGS     = -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE

GENERAL_LIST = $(wildcard scripts/*.sh) \
               $(wildcard scripts/*.pl) \
               doc/manual.html \
               doc/README \
               doc/style.css \
               $(wildcard example/index/*.bt2) \
               $(wildcard example/reads/*.fq) \
               $(wildcard example/reads/*.pl) \
               example/reference/lambda_virus.fa \
               $(PTHREAD_PKG) \
               bowtie2 \
               AUTHORS \
               LICENSE \
               NEWS \
               MANUAL \
               MANUAL.markdown \
               TUTORIAL \
               VERSION

# This is helpful on Windows under MinGW/MSYS, where Make might go for
# the Windows FIND tool instead.
FIND=$(shell which find)

SRC_PKG_LIST = $(wildcard *.h) \
               $(wildcard *.hh) \
               $(wildcard *.c) \
               $(wildcard *.cpp) \
               doc/strip_markdown.pl \
               Makefile \
               $(GENERAL_LIST)

BIN_PKG_LIST = $(GENERAL_LIST)

.PHONY: all

all: libbowtie2

allall: $(BOWTIE2_BIN_LIST) $(BOWTIE2_BIN_LIST_AUX)



DEFS=-fno-strict-aliasing \
     -DBOWTIE2_VERSION="\"`cat VERSION`\"" \
     -DBUILD_HOST="\"`hostname`\"" \
     -DBUILD_TIME="\"`date`\"" \
     -DCOMPILER_VERSION="\"`$(CXX) -v 2>&1 | tail -1`\"" \
     $(FILE_FLAGS) \
     $(PTHREAD_DEF) \
     $(PREF_DEF) \
     $(MM_DEF) \
     $(SHMEM_DEF)


# bowtie targets
#

libbowtie2: bt2_search.cpp $(SEARCH_CPPS) $(SHARED_CPPS) $(HEADERS) $(SEARCH_FRAGMENTS)
	$(CXX) -fPIC -shared $(RELEASE_FLAGS) $(RELEASE_DEFS) $(EXTRA_FLAGS) \
		$(DEFS) -DBOWTIE2 $(NOASSERT_FLAGS) -Wall \
		$(INC) \
		-o $@.so $< \
		$(SHARED_CPPS) $(SEARCH_CPPS_MAIN) \
		$(LIBS) $(SEARCH_LIBS)

.PHONY: clean
clean:
	rm -f $(BOWTIE2_BIN_LIST) $(BOWTIE2_BIN_LIST_AUX) \
	$(addsuffix .exe,$(BOWTIE2_BIN_LIST) $(BOWTIE2_BIN_LIST_AUX)) \
	bowtie2-src.zip bowtie2-bin.zip
	rm -f core.* .tmp.head
	rm -rf *.dSYM
	rm libbowtie2.so
