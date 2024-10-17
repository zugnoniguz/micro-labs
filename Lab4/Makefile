.PHONY: build

BUILDDIR := out/

build: $(BUILDDIR) $(BUILDDIR)main.hex

$(BUILDDIR):
	mkdir -p $@

upload: build
	avrdude -c xplainedmini -p m328p -U flash:w:$(BUILDDIR)main.hex:i

$(BUILDDIR)main.o: main.c 7seg.h defs.h
	avr-gcc $^ -mmcu=atmega328p -Wall -Wextra -pedantic -fdiagnostics-show-option -Werror -Os -o $@

$(BUILDDIR)main.hex: $(BUILDDIR)main.o
	avr-objcopy -O ihex $< $@

clean:
	rm -rf $(BUILDDIR)
