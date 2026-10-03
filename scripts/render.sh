#!/bin/sh
# Usage: render.sh [--xml | --toml] TEMPLATE OUTPUT
#
# Copies TEMPLATE to OUTPUT and replaces every ${TMF_NAME} with the value of the environment
# variable TMF_NAME (empty if unset). Nothing else is touched, so TM color codes like $f00 stay.
#   --xml     values are escaped for XML (& < > ")
#   --toml    values are escaped for TOML strings ("${TMF_...}" in quotes: \ and " and line breaks)
set -e
mode=plain
case "$1" in
  --xml) mode=xml; shift ;;
  --toml) mode=toml; shift ;;
esac
[ $# -eq 2 ] || { echo "usage: render.sh [--xml | --toml] TEMPLATE OUTPUT" >&2; exit 2; }

MODE="$mode" perl -pe '
  sub value {
    my ($name) = @_;
    my $v = defined $ENV{$name} ? $ENV{$name} : "";
    if ($ENV{MODE} eq "xml") {
      $v =~ s/&/&amp;/g; $v =~ s/</&lt;/g; $v =~ s/>/&gt;/g; $v =~ s/"/&quot;/g;
    } elsif ($ENV{MODE} eq "toml") {
      $v =~ s/\\/\\\\/g; $v =~ s/"/\\"/g; $v =~ s/\n/\\n/g;
    }
    return $v;
  }
  s/\$\{(TMF_[A-Z0-9_]+)\}/value($1)/ge;
' "$1" > "$2"
