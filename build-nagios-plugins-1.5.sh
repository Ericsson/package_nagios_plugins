#!/bin/bash
#@(#)Build EIS Configuration Management

pkgname=op5-nagios-plugins
pkgdescription="op5 nagios plugins"
prefix=/opt/op5
PKGDIR=/tmp/op5
build=$PKGDIR/src
SANDBOX=$PKGDIR/sandbox-nagios-plugins
scriptname=${0##*/}
scriptdir=${0%/*}

packagerel=4
nrpe_user=op5nrpe
nrpe_user_solaris=op5nrpe
nrpe_uid=95118
nrpe_group=nfsnobody
nrpe_group_solaris=nogroup
nrpe_gid=65534
nrpe_home=/opt/op5/data

nagiosplugins_version=1.5
nagiosplugins_source="https://www.nagios-plugins.org/download/nagios-plugins-1.5.tar.gz"

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
   test -f $srcdir.tar.gz || wget -O $srcdir.tar.gz $url
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
               ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --disable-perl-modules --with-nagios-user=$nrpe_user_solaris --with-nagios-group=$nrpe_group_solaris --without-world-permissions --with-openssl=/opt/csw --without-mysql

               make && make install
            ;;
            '5.9')
               PATH=/app/gcc/3.4.6/bin:/usr/ccs/bin:$PATH
               export PATH
               ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --enable-perl-modules --with-nagios-user=$nrpe_user_solaris --with-nagios-group=$nrpe_group_solaris --without-world-permissions --with-openssl=/opt/csw --without-mysql

               make && make install
            ;;
            *)
               PATH=/usr/sfw/bin:/usr/ccs/bin:$PATH
               export PATH
               ./configure --prefix=$prefix/nagios-plugins --enable-extra-opts --enable-perl-modules --with-nagios-user=$nrpe_user_solaris --with-nagios-group=$nrpe_group_solaris --without-world-permissions --enable-ssl --enable-command-args --with-ssl-lib=/usr/sfw/lib --with-ssl-inc=/usr/sfw/include --with-ssl=/usr/sfw --without-mysql
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

%pre
/usr/bin/getent group $nrpe_group > /dev/null || /usr/sbin/groupadd -r -o -g $nrpe_gid $nrpe_group
/usr/bin/getent passwd $nrpe_user > /dev/null || /usr/sbin/useradd -r -u $nrpe_uid -g $nrpe_gid -d $nrpe_home -s /bin/false $nrpe_user

%description
Nagios plugins installed in $prefix

%files
%(cd $SANDBOX; find opt '!' -type d | xargs stat --format "%%%attr(%a,%U,$nrpe_group) %n" | sed s,${prefix#/},$prefix,)

%postun
rm -rf $prefix/nagios-plugins
rm -f $prefix/perl $prefix/plugins
rmdir --ignore-fail-on-non-empty -p $prefix
EOSPEC

   rm -rf $SANDBOX/usr
   rpmbuild --define "_rpmdir $PKGDIR"  --buildroot=$SANDBOX -bb $SPEC
   mv ${PKGDIR}/`uname -i`/${pkgname}-${nagiosplugins_version}-${packagerel}_${DISTVER}.`uname -i`.rpm /var/tmp/ && echo wrote /var/tmp/${pkgname}-${nagiosplugins_version}-${packagerel}_${DISTVER}.`uname -i`.rpm

   rm -rf $SPEC ${PKGDIR}/`uname -i`
}


#-----------------------------------------------
# Build Debian Package (Ubuntu)
#-----------------------------------------------

nagiosplugins_deb () {
   typeset CTRL=$SANDBOX/DEBIAN/control
   typeset PRE=$SANDBOX/DEBIAN/preinst
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

cat << EOSPEC > $PRE
getent group $nrpe_group > /dev/null || groupadd -r -o -g $nrpe_gid $nrpe_group
getent passwd $nrpe_user > /dev/null || useradd -r -u $nrpe_uid -g $nrpe_gid -d $nrpe_home -s /bin/false $nrpe_user
EOSPEC

   chmod 755 $PRE
   cd $SANDBOX/..
   dpkg-deb --build $(basename $SANDBOX)
   mv $(basename $SANDBOX).deb /var/tmp/${pkgname}-${nagiosplugins_version}-${packagerel}${DISTVER#debian}.`uname -i`.deb
}


#-----------------------------------------------
# Build Solaris IPS Package
#-----------------------------------------------

nagiosplugins_ips_pkg () {
   typeset PKGROOT=/var/tmp/${pkgname}
   typeset PROTO=${PKGROOT}.proto
   mkdir $PKGROOT $PROTO 2>/dev/null

   rsync -aR $prefix $PROTO

   # Metadata
cat << EOP >> ${PKGROOT}/${pkgname}.mog
set name=pkg.fmri value=${pkgname}@${nagiosplugins_version}-${packagerel}
set name=pkg.summary value=${pkgname}
set name=pkg.description value="${pkgdescription}"
set name=variant.arch value=\$(ARCH)
set name=info.classification value="org.opensolaris.category.2008:Applications/System Utilities"
group groupname=${nrpe_group_solaris} gid=${nrpe_gid}
user username=${nrpe_user_solaris} uid=${nrpe_uid} group=${nrpe_group_solaris} gcos-field=${nrpe_user_solaris} login-shell=/bin/false home-dir=${nrpe_home}
depend fmri=op5-nrpe type=require
EOP

   # Generate 
   cd $PROTO
   gfind opt/op5 -type d -not -name .                                -printf "dir mode=%m owner=%u group=%g path=%p \n"     >> ${PKGROOT}/${pkgname}.p5m.gen
   gfind opt/op5 -type f -not -name LICENSE -and -not -name MANIFEST -printf "file %p mode=%m owner=%u group=%g path=%p \n" >> ${PKGROOT}/${pkgname}.p5m.gen
   gfind opt/op5 -type l -not -name LICENSE -and -not -name MANIFEST -printf "link path=%h/%f target=%l \n"                 >> ${PKGROOT}/${pkgname}.p5m.gen

   # Content
   pkgmogrify -DARCH=`uname -p` ${PKGROOT}/${pkgname}.p5m.gen ${PKGROOT}/${pkgname}.mog | pkgfmt > ${PKGROOT}/${pkgname}.p5m.mog
   pkgdepend generate -md ${PKGROOT}.proto ${PKGROOT}/${pkgname}.p5m.mog | pkgfmt > ${PKGROOT}/${pkgname}.p5m.dep
   pkgdepend resolve -m ${PKGROOT}/${pkgname}.p5m.dep

   mv $PKGROOT/${pkgname}.p5m.dep.res /var/tmp/
   echo "Note: if you have done any changes in the code please also do: pkglint -c /var/tmp/lint-cache -r http://pkg.oracle.com/solaris/release /var/tmp/${pkgname}.p5m.dep.res"
   echo "Publish to local repo: pkgsend publish -s http://localhost:82 -d $PROTO /var/tmp/${pkgname}.p5m.dep.res"
   echo "Wrote /var/tmp/${pkgname}.p5m.dep.res and Proto $PROTO"

   if [ -n "$PKGROOT" ] ; then
      rm -rf $PKGROOT
   fi
}

#-----------------------------------------------
# Build Solaris SVR4 Package
#-----------------------------------------------

nagiosplugins_svr4_pkg () {
   typeset PKGROOT=/var/tmp/nagios-plugins-pkgroot

   mkdir $PKGROOT
   cd /
   find $prefix | cpio -pmd ${PKGROOT}
   platform=`uname -p`
   find ${PKGROOT} | sed s,${PKGROOT},,| pkgproto > ${PKGROOT}/cm.proto

cat << EOP >> ${PKGROOT}/cm.proto
i checkinstall
i pkginfo
i preinstall
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
PSTAMP="27Nov2013"
BASEDIR="/"
SUNW_PKG_ALLZONES="false"
SUNW_PKG_HOLLOW="false"
SUNW_PKG_THISZONE="true"
EOT2

cat << EOT3 > ${PKGROOT}/preinstall
#!/bin/sh
/usr/bin/getent group $nrpe_group_solaris > /dev/null || /usr/sbin/groupadd -o -g $nrpe_gid $nrpe_group_solaris
/usr/bin/getent passwd $nrpe_user_solaris > /dev/null || /usr/sbin/useradd -o -u $nrpe_uid -g $nrpe_gid -d $nrpe_home $nrpe_user_solaris
EOT3

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
         case `uname -r` in
            '5.11')
               ${what}_ips_pkg
            ;;
            *)
               ${what}_svr4_pkg
            ;;
         esac
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

if [ `uname -s` == 'SunOS' ]; then
  if [ $? != 0 ]; then
    getent passwd $nrpe_user_solaris > /dev/null
    echo "User $nrpe_user_solaris does not exist"
    exit
  fi
  if [ $? != 0 ]; then
    getent group $nrpe_group_solaris > /dev/null
    echo "Group $nrpe_group_solaris does not exist"
    exit
  fi
  PATH=/usr/sbin:/usr/bin:/usr/sfw/bin:/usr/ccs/bin:/opt/csw/bin
  export PATH
else
  getent passwd $nrpe_user > /dev/null
  if [ $? != 0 ]; then
    echo "User $nrpe_user does not exist"
    exit
  fi
  getent group $nrpe_group > /dev/null
  if [ $? != 0 ]; then
    echo "Group $nrpe_group does not exist"
    exit
  fi
fi

test -d "$prefix" || mkdir -p $prefix
test -d "$build" || mkdir -p $build

cd $build
get_source nagiosplugins
build_nagiosplugins
make_pkg nagiosplugins
