package_nagios_plugins
====================

Scripts to build and package nagios_plugins

verified on:

* EL 5 32bit                 1.5
* EL 5 64bit                 1.5
* EL 6 32bit                 1.5
* EL 6 64bit                 1.5
* SLEx 10 32bit              1.5
* SLEx 10 64bit              1.5
* SLEx 11 32bit              1.5
* SLEx 11 64bit              1.5
* Solaris  8 sparc           1.4.16   no perl modules
* Solaris  9 sparc           1.4.16
* Solaris 10 sparc update 8  1.4.16
* Solaris 10 x86             1.4.16
* Solaris 11 sparc           1.5
* Solaris 11 x86             1.5
* Ubuntu 12.04 LTS 64bit     1.5


Defaults
========

* pkgname=op5-nagios-plugins
* prefix=/opt/op5
* nrpe_user=op5nrpe
* nrpe_group=nfsnobody
* nrpe_user_solaris=op5nrpe
* nrpe_group_solaris=nogroup


Build
=====

* be root on server
* uninstall previous package and remove /opt/op5
* http_proxy=[your proxy:port]
* https_proxy=[your proxy:port]
* copy the repo to /tmp/
* cd /tmp/package_nagios_plugins/
* ./build-nagios-plugins-(1.5 or 1.4.16).sh
