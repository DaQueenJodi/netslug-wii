###############################################################################
# makefile
#  by Alex Chadwick
#
# A makefile script for generation of the brainslug project
###############################################################################

###############################################################################
# helper variables
C := ,

###############################################################################
# devkitpro settings
ifeq ($(strip $(DEVKITPPC)),)
  $(error "Please set DEVKITPPC in your environment. export DEVKITPPC=<path to>devkitPPC")
endif
ifeq ($(strip $(DEVKITPRO)),)
  $(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitPRO")
endif

ifeq ($(OS),Windows_NT)
  $(info Compiling from $(OS))

  PORTLIBS := $(DEVKITPRO)/portlibs/ppc
  PATH := $(DEVKITPPC)/bin:$(PORTLIBS)/bin:$(PATH)
  ifeq ($(DEVKITPRO),$(subst :, ,$(DEVKITPRO)))
    DEVKITPRO := $(patsubst /$(firstword $(subst /, ,$(DEVKITPRO)))/%,$(firstword $(subst /, ,$(DEVKITPRO))):/%,$(DEVKITPRO))
    $(info DEVKITPRO corrected to $(DEVKITPRO))
  else
    $(info DEVKITPRO is $(DEVKITPRO))
  endif
  PORTLIBS := $(DEVKITPRO)/portlibs/ppc
  ifeq ($(DEVKITPPC),$(subst :, ,$(DEVKITPPC)))
    DEVKITPPC := $(patsubst /$(firstword $(subst /, ,$(DEVKITPPC)))/%,$(firstword $(subst /, ,$(DEVKITPPC))):/%,$(DEVKITPPC))
    $(info DEVKITPPC corrected to $(DEVKITPPC))
  else
    $(info DEVKITPPC is $(DEVKITPPC))
  endif
else
  $(info Compiling from Unix)

  PORTLIBS := $(DEVKITPRO)/portlibs/ppc
  $(info DEVKITPRO is $(DEVKITPRO))
  $(info DEVKITPPC is $(DEVKITPPC))
endif

###############################################################################
# Compiler settings

# The toolchain to use.
PREFIX  ?= powerpc-eabi-
# Tools to use
AS      := $(PREFIX)as
LD      := $(PREFIX)g++
CC      := $(PREFIX)g++
OBJDUMP := $(PREFIX)objdump
OBJCOPY := $(PREFIX)objcopy
ELF2DOL ?= elf2dol

# -O2: optimise lots
# -Wl$C--gc-sections: remove unneeded symbols
# -mrvl: enable wii/gamecube compilation
# -mcpu=750: enable processor specific compilation
# -meabi: enable eabi specific compilation
# -Wl$C--section-start$C.init=0x80a00000:
#    start the executable after 0x80a00000 so we don't have to move in order to
#    load a dol file from a disk.
# -Wl$C-Map$C: generate a map file
LDFLAGS  += -O2 -Wl$C--gc-sections \
            -mrvl -mcpu=750 -meabi \
            -Wl$C--section-start$C.init=0x80a00000 \
            $(patsubst %,-Wl$C-Map$C%,$(strip $(MAP)))
# -O2: optimise lots
# -Wall: generate lots of warnings
# -x c: compile as C code
# -std=gnu99: use the C99 standard with GNU extensions
# -DGEKKO: define the symbol GEKKO (used in some libogc headers)
# -DHW_RVL: define the symbol HW_RVL (used in some libogc headers)
# -D__wii__: define the symbol __wii__ (used in some libogc headers)
# -mrvl: enable wii/gamecube compilation
# -mcpu=750: enable processor specific compilation
# -meabi: enable eabi specific compilation
# -mhard-float: enable hardware floating point instructions
# -msdata=eabi: use r2 and r13 as small data areas
# -memb: enable embedded application specific compilation
# -ffunction-sections: split up functions so linker can garbage collect
# -fdata-sections: split up data so linker can garbage collect
CFLAGS   += -O2 -Wall -x c -std=gnu99 \
            -DGEKKO -DHW_RVL -D__wii__ \
            -mrvl -mcpu=750 -meabi -mhard-float \
            -msdata=eabi -memb -ffunction-sections -fdata-sections

ifdef DEBUG
else
  CFLAGS += -DNDEBUG
endif

###############################################################################
# Parameters

# Used to suppress command echo.
Q      ?= @
LOG    ?= @echo $@
# The intermediate directory for compiled object files.
BUILD  ?= build
# The output directory for compiled results.
BIN    ?= bin
# The output directory for releases.
RELEASE?= release
# The name of the output file to generate.
TARGET ?= $(BIN)/boot.dol
# The name of the assembler listing file to generate.
LIST   ?= $(BIN)/boot.list
# The name of the map file to generate.
MAP    ?= $(BIN)/boot.map

###############################################################################
# Variable init

# The names of libraries to use.
LIBS     := ogc mxml fat bte wiiuse m
# The source files to compile.
SRC      :=
# Phony targets
PHONY    :=
# Include directories
INC_DIRS := .
# Library directories
LIB_DIRS := $(DEVKITPPC) $(DEVKITPPC)/powerpc-eabi \
            $(DEVKITPRO)/libogc $(DEVKITPRO)/libogc/lib/wii \
            $(wildcard $(DEVKITPPC)/lib/gcc/powerpc-eabi/*) \
            $(PORTLIBS) $(PORTLIBS)/wii

###############################################################################
# Rule to make everything.
PHONY += all

all : $(TARGET) $(BIN)/boot.elf

###############################################################################
# Release rules

PHONY += release
release: $(TARGET) meta.xml icon.png
	$(LOG)
	$(addprefix $Qrm -rf ,$(wildcard $(RELEASE)))
	$Qmkdir $(RELEASE)
	$Qmkdir $(RELEASE)/apps
	$Qmkdir $(RELEASE)/apps/netslug
	$Qcp -r $(TARGET) $(RELEASE)/apps/netslug
	$Qcp -r symbols $(RELEASE)/apps/netslug
	$Qmkdir $(RELEASE)/apps/netslug/modules
	$Qcp -r USAGE $(RELEASE)/readme.txt
	$Qcp config.ini $(RELEASE)/apps/netslug/config.ini
	$Q$(MAKE) -C modules release RELEASE_DIR=../$(RELEASE)/apps/netslug/modules

###############################################################################
# Recursive rules

include src/makefile.mk

LDFLAGS += $(patsubst %,-l %,$(LIBS)) $(patsubst %,-l %,$(LIBS)) \
           $(patsubst %,-L %,$(LIB_DIRS)) $(patsubst %,-L %/lib,$(LIB_DIRS))
CFLAGS  += $(patsubst %,-I %,$(INC_DIRS)) \
           $(patsubst %,-I %/include,$(LIB_DIRS)) -iquote src

OBJECTS := $(patsubst %.c,$(BUILD)/%.c.o,$(filter %.c,$(SRC)))
          
ifeq ($(words $(filter clean%,$(MAKECMDGOALS))),0)
ifeq ($(words $(filter install%,$(MAKECMDGOALS))),0)
ifeq ($(words $(filter uninstall%,$(MAKECMDGOALS))),0)
  include $(patsubst %.c,$(BUILD)/%.c.d,$(filter %.c,$(SRC)))
endif
endif
endif

###############################################################################
# Special build rules

# Rule to make the image file.
$(TARGET) : $(BUILD)/output.elf | $(BIN)
	$(LOG)
	-$Qmkdir -p $(dir $@)
	$Q$(ELF2DOL) $(BUILD)/output.elf $(TARGET) 
	
$(BIN)/boot.elf : $(BUILD)/output.elf | $(BIN)
	$(LOG)
	$Qcp $< $@
	$Q$(PREFIX)strip $@
	$Q$(PREFIX)strip -g $@

# Rule to make the elf file.
$(BUILD)/output.elf : $(OBJECTS) $(LINKER) | $(BIN) $(BUILD)
	$(LOG)
	$Q$(LD) $(OBJECTS) $(LDFLAGS) -o $@ 

# Rule to make intermediate directory
$(BUILD) : 
	$Qmkdir $@

# Rule to make output directory
$(BIN) : 
	$Qmkdir $@

###############################################################################
# Standard build rules

$(BUILD)/%.c.o: %.c | $(BUILD)
	$(LOG)
	-$Qmkdir -p $(dir $@)
	$Q$(CC) -c $(CFLAGS) $< -o $@
$(BUILD)/%.c.d: %.c | $(BUILD)
	$(LOG)
	-$Qmkdir -p $(dir $@)
	$Q$(RM) $(wildcard $@)
	$Q{ $(CC) -MP -MM -MT $(@:.d=.o) $(CFLAGS) $< > $@ \
	&& $(RM) $@.tmp; } \
	|| { $(RM) $@.tmp && false; }

###############################################################################
# Assembly listing rules

# Rule to make assembly listing.
PHONY += list
list  : $(LIST)

# Rule to make the listing file.
%.list : $(BUILD)/output.elf $(BUILD)
	$(LOG)
	-$Qmkdir -p $(dir $@)
	$Q$(OBJDUMP) -d $(BUILD)/output.elf > $@

###############################################################################
# Clean rule

# Rule to clean files.
PHONY += clean
clean : 
	$Qrm -rf $(wildcard $(BUILD) $(BIN) $(RELEASE))
	$Q$(MAKE) -C modules clean

###############################################################################
# Phony targets

.PHONY : $(PHONY)
