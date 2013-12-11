#!/bin/bash
#@(#)Build EIS Configuration Management

pkgname=op5-nagios-plugins
prefix=/opt/op5
PKGDIR=/tmp/op5
build=$PKGDIR/src
SANDBOX=$PKGDIR/sandbox-nagios-plugins
scriptname=${0##*/}
scriptdir=${0%/*}

packagerel=1
nrpe_user=op5nrpe          # uid=95118
nrpe_group=nfsnobody       # gid=65534
nrpe_group_solaris=nogroup # gid=65534

nagiosplugins_version=1.4.16
#nagiosplugins_source="http://downloads.sourceforge.net/project/nagiosplug/nagiosplug/1.4.16/nagios-plugins-1.4.16.tar.gz?r=&ts=1350919997&use_mirror=freefr"
nagiosplugins_source="https://www.nagios-plugins.org/download/nagios-plugins-1.4.16.tar.gz"


#-----------------------------------------------
# Linux Dist
#-----------------------------------------------

linux_dist () {
   if [ -f /etc/redhat-release ] ; then
      typeset dist="rhel"
      typeset ver=$(sed 's/^[^0-9]*\([0-9]*\).*$/\1/' /etc/redhat-release)
   else if [ -f /etc/SuSE-release ] ; then
      typeset dist="suse"
      typeset ver=$(sed -n '1s/^[^0-9]*\([0-9]*\).*$/\1/p' /etc/SuSE-release)
   else if [ -f /etc/debian_version ] ; then
      typeset dist="debian_"
      typeset ver=$(sed -n '1s/^\([^\/]*\)\(\/sid\)*/\1/p' /etc/debian_version)
   fi ; fi ; fi


   if [ -z "$dist" -o -z "$ver" ] ; then
      echo Unsupported linux dist $dist $ver 1>&2
      exit 1
   fi
   echo $dist$ver
   return
}


#-----------------------------------------------
# RootDo
#-----------------------------------------------

rootdo () {
   if [ $UID = 0 ] ; then
      $*
   else
      sudo $*
   fi
}


#-----------------------------------------------
# Get Source
#-----------------------------------------------

get_source () {
   typeset sw=$1
   typeset srcdir=`eval echo ${sw}-'$'${sw}_version`
   typeset url=`eval echo '$'${sw}_source`
   test -d $srcdir && return
   test -s $srcdir.tar.gz || rm -rf $srcdir.tar.gz
   test -f $srcdir.tar.gz || wget --no-check-certificate -O $srcdir.tar.gz $url
   gzip -dc $srcdir.tar.gz | tar xf -
}


#-----------------------------------------------
# Build Nagiosplugins
#-----------------------------------------------

build_nagiosplugins() {
   echo Building nagiosplugins
   cd $build
   cd nagios-plugins-$nagiosplugins_version
   make clean
   case `uname -s` in
      'SunOS')
         hasfiles=`find $prefix -type f`
         if [ -n "$hasfiles" ] ; then
            echo "ERROR: target dir $prefix already exists. Remove it"
            exit 1
         fi
         case `uname -r` in
            '5.8')
               PATH=/app/gcc/3.4.6/bin:/usr/ccs/bin:$PATH
               export PATH
               ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --disable-perl-modules --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group_solaris --without-world-permissions --with-openssl=/opt/csw --without-mysql

               make && make install
            ;;
            '5.9')
               PATH=/app/gcc/3.4.6/bin:/usr/ccs/bin:$PATH
               export PATH
               ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --enable-perl-modules --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group_solaris --without-world-permissions --with-openssl=/opt/csw --without-mysql

               make && make install
            ;;
            *)
               PATH=/usr/sfw/bin:/usr/ccs/bin:$PATH
               export PATH
               ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --enable-perl-modules --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group_solaris --without-world-permissions --enable-ssl --enable-command-args --with-ssl-lib=/usr/sfw/lib --with-ssl-inc=/usr/sfw/include --with-ssl=/usr/sfw --without-mysql
               gmake && gmake install
            ;;
         esac
         cd $prefix
         ln -sf nagios-plugins/libexec/ plugins
         if [ -d nagios-plugins/perl/lib ]; then
            ln -sf nagios-plugins/perl/lib perl
         fi
      ;;
      'HP-UX')
         # FIXME this is completely untested
         PATH=/usr/local/bin:$PATH
         export PATH
         CC=/usr/local/bin/gcc
         export CC
         CFLAGS="-O2 -g -pthread -mlp64 -w -pipe -Wall"
         export CFLAGS

         CPPFLAGS "-DHAVE_HMAC_CTX_COPY -DHAVE_EVP_CHIPER_CTX_COPY -I/opt/eis_cm/include"
         export CPPFLAGS
         LDFLAGS="-L$prefix/lib"
         export LDFLAGS
         ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --enable-perl-modules --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group --without-world-permissions
         make && make install
         break
      ;;
      'Linux')
         DISTVER=`linux_dist`
         if [ "${DISTVER#debian}" != "$DISTVER" ] ; then
            ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --disable-perl-modules --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group --without-world-permissions
            make && make install DESTDIR=$SANDBOX
            rootdo make install
            if [ '!' -x $SANDBOX/$prefix/nagios-plugins/libexec/check_nagios ] ; then
               echo nagios-plugins did not build correctly
               exit 1
            fi
            cd $SANDBOX/$prefix
            ln -sf nagios-plugins/libexec/ plugins
         else
            ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --enable-perl-modules --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group --without-world-permissions
            make && make install DESTDIR=$SANDBOX
            rootdo make install
            if [ '!' -x $SANDBOX/$prefix/nagios-plugins/libexec/check_nagios ] ; then
               echo nagios-plugins did not build correctly
               exit 1
            fi
            cd $SANDBOX/$prefix
            ln -sf nagios-plugins/libexec/ plugins
            ln -sf nagios-plugins/perl/lib perl
         fi
      ;;
      *)
         echo To be implemented
         exit 1
         break
      ;;
   esac
}


#-----------------------------------------------
# Build rpm package (RedHat & SuSE)
#-----------------------------------------------

nagiosplugins_rpm () {
   typeset SPEC=/var/tmp/${pkgname}.spec
   rm -f $SPEC

cat << EOSPEC >> $SPEC
Name: ${pkgname}
URL: https://wiki.lmera.ericsson.se/wiki/ITTE/OP5_Operations_Guide
Summary: Nagios plugins installed in $prefix
Version: ${nagiosplugins_version}
Release: ${packagerel}_$DISTVER
License: GPL
Group: Applications/System
Buildroot: $SANDBOX
AutoReqProv: no

%description
Nagios plugins installed in $prefix

%files
%(cd $SANDBOX; find opt '!' -type d | xargs stat --format "%%%attr(%a,%U,$nrpe_group) %n" | sed s,${prefix#/},$prefix,)

%postun
rm -rf $prefix/nagios-plugins
rm -f $prefix/perl $prefix/plugins
rmdir --ignore-fail-on-non-empty -p $prefix
EOSPEC

   rpmbuild --define "_rpmdir $PKGDIR"  --buildroot=$SANDBOX -bb $SPEC
   mv ${PKGDIR}/`uname -i`/${pkgname}-${nagiosplugins_version}-${packagerel}_${DISTVER}.`uname -i`.rpm /var/tmp/ && echo wrote /var/tmp/${pkgname}-${nagiosplugins_version}-${packagerel}_${DISTVER}.`uname -i`.rpm

   rm -rf $SPEC ${PKGDIR}/`uname -i`
}


#-----------------------------------------------
# Build Debian Package (Ubuntu)
#-----------------------------------------------

nagiosplugins_deb () {
   typeset CTRL=$SANDBOX/DEBIAN/control
   mkdir -p $SANDBOX/DEBIAN

cat << EOSPEC > $CTRL
Package: ${pkgname}
Version: ${nagiosplugins_version}-${packagerel}
Architecture: $architecture
Priority: optional
Section: base
Maintainer: Ericsson internal
Description: This is nagios-plugins installed in $prefix
EOSPEC

   cd $SANDBOX/..
   dpkg-deb --build $(basename $SANDBOX)
   mv $(basename $SANDBOX).deb /var/tmp/${pkgname}-${nagiosplugins_version}-${packagerel}${DISTVER#debian}.`uname -i`.deb
}


#-----------------------------------------------
# Build Solaris Package
#-----------------------------------------------

nagiosplugins_pkg () {
   typeset PKGROOT=/var/tmp/nagios-plugins-pkgroot

   mkdir $PKGROOT
   cd /
   find $prefix | cpio -pmd ${PKGROOT}
   platform=`uname -p`
   find ${PKGROOT} | sed s,${PKGROOT},,| pkgproto > ${PKGROOT}/cm.proto

cat << EOP >> ${PKGROOT}/cm.proto
i checkinstall
i pkginfo
EOP

cat << EOT > $PKGROOT/checkinstall
#!/bin/sh

expected_platform="$platform"
platform=`uname -p`
if [ \${platform} != \${expected_platform} ]; then
        echo "This package must be installed on \${expected_platform}"
        exit
fi
exit 0
EOT

cat << EOT2 > ${PKGROOT}/pkginfo
PKG="EIS${pkgname}"
NAME="nrpe"
VERSION="$nagiosplugins_version"
ARCH="$platform"
CLASSES="none"
CATEGORY="tools"
VENDOR="EIS"
PSTAMP="14Aug2013"
EMAIL="anders.k.lindgren@ericsson.com"
BASEDIR="/"
SUNW_PKG_ALLZONES="false"
SUNW_PKG_HOLLOW="false"
SUNW_PKG_THISZONE="true"
EOT2

   cd ${PKGROOT}
   solvers=$(uname -r)
   solvers=${solvers#5.}
   pkgfile=${pkgname}-${nagiosplugins_version}-sol${solvers}-${platform}
   mkdir /var/tmp/eis 2>/dev/null
   pkgmk -o -r / -d /var/tmp/eis -f cm.proto
   cd /var/tmp/eis
   pkgtrans -s `pwd` /var/tmp/$pkgfile "EIS${pkgname}"
   echo Wrote /var/tmp/$pkgfile
   rm -rf /var/tmp/eis/$pkgname
   rmdir /var/tmp/eis 2>/dev/null

   if [ -n "$PKGROOT" ] ; then
      rm -rf $PKGROOT
   fi
}


#-----------------------------------------------
# Build Package
#-----------------------------------------------

make_pkg () {
   typeset what=$1
   case `uname -s` in
      'SunOS')
         ${what}_pkg
      ;;
      'HP-UX')
         echo To be implemented
         exit 1
      ;;
      'Linux')
         architecture=`uname -i`
         if [ `uname -s` = 'Linux' ] ; then
            DISTVER=`linux_dist`
         fi
         if [ "${DISTVER#debian}" != "$DISTVER" ] ; then
            if [ "$architecture" = x86_64 ] ; then
               architecture=amd64
            fi
	    ${what}_deb
         else if [ "${DISTVER#suse}" != "$DISTVER" -o "${DISTVER#rhel}" != "$DISTVER" ] ; then
            ${what}_rpm
         else
            echo do not know how to package for $DISTVER
             exit 1
         fi ; fi
      ;;
      *)
         echo To be implemented
         exit 1
      ;;
   esac
}

#-----------------------------------------------
# Main
#-----------------------------------------------

if [ -z "$scriptdir" ] ; then
  scriptdir=`pwd`
else
  # handle ../ and ./
  cd $scriptdir
  scriptdir=`pwd`
  cd -
fi

case `uname -s` in
  'SunOS')
    PATH=/usr/sbin:/usr/bin:/usr/sfw/bin:/usr/ccs/bin:/opt/csw/bin
    export PATH
  ;;
esac

test -d "$prefix" || mkdir -p $prefix
test -d "$build" || mkdir -p $build

cd $build
get_source nagiosplugins
build_nagiosplugins
make_pkg nagiosplugins
