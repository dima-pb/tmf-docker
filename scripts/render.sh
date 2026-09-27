#!/bin/sh
# Usage: render.sh [--xml | --xaseco] TEMPLATE OUTPUT
#
# Copies TEMPLATE to OUTPUT and replaces every ${TMF_NAME} with the value of the environment
# variable TMF_NAME (empty if unset). Nothing else is touched, so TM color codes like $f00 stay.
#   --xml     values are escaped for XML (& < > ")
#   --xaseco  for XAseco's XML files: XAseco's parser takes '&' literally (so no escaping), and
#             can't represent '<' or '>' at all, so values containing them are rejected
set -e
mode=plain
case "$1" in
  --xml) mode=xml; shift ;;
  --xaseco) mode=xaseco; shift ;;
esac
[ $# -eq 2 ] || { echo "usage: render.sh [--xml | --xaseco] TEMPLATE OUTPUT" >&2; exit 2; }

MODE="$mode" perl -pe '
  sub value {
    my ($name) = @_;
    my $v = defined $ENV{$name} ? $ENV{$name} : "";
    if ($ENV{MODE} eq "xml") {
      $v =~ s/&/&amp;/g; $v =~ s/</&lt;/g; $v =~ s/>/&gt;/g; $v =~ s/"/&quot;/g;
    } elsif ($ENV{MODE} eq "xaseco" && $v =~ /[<>]/) {
      die "$name must not contain < or > (XAseco cannot read them in $ARGV)\n";
    }
    return $v;
  }
  s/\$\{(TMF_[A-Z0-9_]+)\}/value($1)/ge;
' "$1" > "$2"
