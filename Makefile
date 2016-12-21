
#
# to build this package, you need to have the following components installed:
# dbus-glib-devel libnotify-devel gtk2-devel curl-devel
#

BINDIR=/usr/bin
SBINDIR=/usr/sbin
LOCALESDIR=/usr/share/locale
MANDIR=/usr/share/man/man8
CC?=gcc
PKG_CONFIG?=pkg-config

CFLAGS ?= -O2 -g -fstack-protector -D_FORTIFY_SOURCE=2 -Wall -W -Wstrict-prototypes -Wundef -fno-common -Werror-implicit-function-declaration -Wdeclaration-after-statement -Wformat -Wformat-security -Werror=format-security

MY_CFLAGS = $(shell $(PKG_CONFIG) --cflags libnotify gtk+-2.0 dbus-glib-1)
#
# pkg-config tends to make programs pull in a ton of libraries, not all 
# are needed. -Wl,--as-needed tells the linker to just drop unused ones,
# and that makes the applet load faster and use less memory.
#
LDF_A ?= -Wl,--as-needed $(shell $(PKG_CONFIG) --libs libnotify gtk+-2.0 dbus-glib-1) $(LDFLAGS)
LDF_D ?= -Wl,--as-needed $(shell $(PKG_CONFIG) --libs glib-2.0 dbus-glib-1) $(shell curl-config --libs) -Wl,"-z relro" -Wl,"-z now" $(LDFLAGS)

all:	kerneloops kerneloops-applet kerneloops.8.gz

noui:	kerneloops kerneloops.8.gz

.c.o:
	$(CC) $(MY_CFLAGS) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<


kerneloops:	kerneloops.o submit.o dmesg.o configfile.o kerneloops.h
	$(CC) kerneloops.o submit.o dmesg.o configfile.o $(LDF_D) -o kerneloops
	@(cd po/ && $(MAKE))

kerneloops-applet: kerneloops-applet.o
	$(CC) kerneloops-applet.o $(LDF_A) -o kerneloops-applet

kerneloops.8.gz: kerneloops.8
	gzip -9 -c $< > $@

clean:
	rm -f *~ *.o *.ko DEADJOE kerneloops kerneloops-applet *.out */*~ kerneloops.8.gz test/*.dbg
	@(cd po/ && $(MAKE) $@)

dist: clean
	rm -rf .git .gitignore push.sh .*~  */*~ test/*dbg

install-system: kerneloops.8.gz
	-mkdir -p $(DESTDIR)$(MANDIR)
	-mkdir -p $(DESTDIR)/etc/dbus-1/system.d/
	install -m 0644 kerneloops.conf $(DESTDIR)/etc/kerneloops.conf
	install -m 0644 kerneloops.dbus $(DESTDIR)/etc/dbus-1/system.d/
	install -m 0644 kerneloops.8.gz $(DESTDIR)$(MANDIR)/
	@(cd po/ && env LOCALESDIR=$(LOCALESDIR) DESTDIR=$(DESTDIR) $(MAKE) install)

install-kerneloops: kerneloops
	-mkdir -p $(DESTDIR)$(SBINDIR)
	install -m 0755 kerneloops $(DESTDIR)$(SBINDIR)/

install-applet: kerneloops-applet
	-mkdir -p $(DESTDIR)$(BINDIR)
	-mkdir -p $(DESTDIR)/etc/xdg/autostart
	-mkdir -p $(DESTDIR)/usr/share/kerneloops
	install -m 0755 kerneloops-applet $(DESTDIR)$(BINDIR)/
	desktop-file-install --mode 0644 --dir=$(DESTDIR)/etc/xdg/autostart/ kerneloops-applet.desktop
	install -m 0644 icon.png $(DESTDIR)/usr/share/kerneloops/icon.png

install: install-system install-kerneloops install-applet

install-noui: install-system install-kerneloops


# This is for translators. To update your po with new strings, do :
# svn up ; make uptrans LG=fr # or de, ru, hu, it, ...
uptrans:
	xgettext -C -s -k_ -o po/kerneloops.pot *.c *.h
	@(cd po/ && env LG=$(LG) $(MAKE) $@)

	

tests: kerneloops
	desktop-file-validate *.desktop
	for i in test/*txt ; do echo -n . ; ./kerneloops --debug $$i > $$i.dbg ; diff -u $$i.out $$i.dbg ; done ; echo
	[ -e /usr/bin/valgrind ] && for i in test/*txt ; do echo -n . ; valgrind -q --leak-check=full ./kerneloops --debug $$i > $$i.dbg ; diff -u $$i.out $$i.dbg ; done ; echo

valgrind: kerneloops tests
	valgrind -q --leak-check=full ./kerneloops --debug test/*.txt


