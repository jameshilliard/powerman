##*****************************************************************************
## $Id: ac_forkpty.m4,v 1.1.1.1 2003/09/05 16:05:42 achu Exp $
##*****************************************************************************
#  AUTHOR:
#    Albert Chu  <chu11@llnl.gov>
#
#  SYNOPSIS:
#    AC_FORKPTY
#
#  DESCRIPTION:
#    Check for forkpty
#
#  WARNINGS:
#    This macro must be placed after AC_PROG_CC or equivalent.
##*****************************************************************************

AC_DEFUN([AC_FORKPTY],
[
  AC_CHECK_FUNC([forkpty], [ac_have_forkpty=yes], [ac_have_forkpty=no])
  if test "$ac_have_forkpty" = "no"; then
    AC_CHECK_LIB([util], [forkpty], [LIBFORKPTY=-lutil],
        AC_CHECK_LIB([bsd], [forkpty], [LIBFORKPTY=-lbsd]))
    if test -n "$LIBFORKPTY"; then
       ac_have_forkpty=yes
    else
       ac_have_forkpty=no
    fi
  fi

  if test "$ac_have_forkpty" = "yes"; then
    AC_DEFINE([HAVE_FORKPTY], [1], [Define if you have forkpty])
    AC_CHECK_HEADERS( pty.h util.h )
  fi

  AC_SUBST(LIBFORKPTY)
])
