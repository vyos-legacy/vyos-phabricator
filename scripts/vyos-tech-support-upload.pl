#!/usr/bin/perl
#
# Copyright (C) 2017 VyOS maintainers and contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 or later as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use lib "/opt/vyatta/share/perl5/";
use Vyatta::Config;

use warnings;
use strict;
use JSON qw( decode_json );

my $taskid;
my $done = 0;
my $url = "https://phabricator.vyos.net/api";
my $config = new Vyatta::Config();

$config->setLevel('system support');

if(!$config->isEffective("phabricator-token"))
{
    print("phabricator-token does not exist!\n");
    exit(1);
}

print "Enter the phabricator task: ";
while (! $done) {
  $taskid = <STDIN>;
  chomp $taskid;
  if ($taskid eq "") {
    print "Enter the phabricator task: ";
  }else{
    $done = 1;
  }
}

my $token = $config->returnEffectiveValue('phabricator-token');
my $cmd = "curl -sS $url/user.whoami
            -d api.token=$token";
$cmd =~ s/\n/ /g;
my $curl = qx($cmd);
exit 1 if (($? >> 8) != 0);

my $filename = qx(/opt/vyatta/sbin/phabricator-wrapper);
$filename =~ tr/\r\n//d;
$filename =~ s/^[^\/]*\//\//;
$filename =~ s/\ .*//;

my $dcurl = decode_json($curl);
if (!defined  $dcurl->{'error_code'}) {
  my $author = $dcurl->{'result'}{'phid'};

  open my $in,  '<',  $filename      or die "Can't read old file: $!";
  open my $out, '>', "$filename.new" or die "Can't write new file: $!";
  print $out "transactions[2][value]=\n";
  while( <$in> ) {
        s/\&/%26/g;
        print $out $_;
  }
  close $out;

  my $datetime = localtime();
  $cmd = "curl -sS $url/paste.edit
          -d api.token=$token
          -d transactions[0][type]=title
          -d transactions[0][value]=\"$taskid tech-support $datetime\"
          -d transactions[1][type]=subscribers.add
          -d transactions[1][value][0]=$author
          -d transactions[1][value][1]=PHID-PROJ-a45gcy76up6ufhs3eye2
          -d transactions[1][value][2]=PHID-PROJ-fuzyxaylinnhjdiorvzq
          -d transactions[2][type]=text
          --data-binary \@$filename.new";
  $cmd =~ s/\n/ /g;
  my $curl = qx($cmd);
  unlink "$filename.new" or warn "Could not unlink $filename.new: $!";
  exit 1 if (($? >> 8) != 0);
  my $dcurl = decode_json($curl);
  if (defined $dcurl->{'error_code'}) {
    print $dcurl->{'error_info'};
    exit 1
  }
} else {
  print $dcurl->{'error_info'};
  exit 1
}

