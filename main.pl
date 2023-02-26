#!/usr/bin/perl

use strict;
use warnings;

use lib './lib';

use Netkit::Machine;
use Netkit::Lan;
use Netkit::Lab;
use Netkit::Interface;
use Netkit::Route;
use Netkit::Attachment;
use Netkit::Rule;

sub dnat {
	my %args = @_;
	my $dst = $args{dst};
	my $source = $args{src};
	my @ports = @{ $args{ports} };
	
	foreach my $port (@ports) {
		$source->rule(
			Rule->new (
				chain => 'FORWARD',
				stateful => 1,
				proto => 'tcp',
				dst => $dst,
				dport => $port,
				action => 'ACCEPT',
			)
		);
		
		$source->rule(
			Rule->new (
					table => 'nat',
					chain => 'PREROUTING',
					proto => 'tcp',
					to_dst => $dst,
					dport => $port,
					action => 'DNAT',
			)
		);
	}
}


my $lab = Lab->new (
	name => 'TestLab',
	out_dir => 'res',
	data_dir => 'data',
);


my $ext_www_lan = Lan->new ('ExtWWW');
my $dmz_lan = Lan->new ('Dmz');
my $staff_lan = Lan->new ('Staff');

my $r2 = Machine->new (
	name => 'r2',
	interfaces => [
		Interface->new (
			eth => 0,
			ip => '192.168.0.3/24',
			mac => 'a8:20:66:2d:30:bf',
		),
		Interface->new (
			eth => 1,
			ip => '10.0.0.1/20',
			mac => 'a8:20:66:3e:42:cf',
		),
	],
	routes => [
		Route->new (
			dst => 'default',
			via => '192.168.0.1'
		),
		Route->new (
			dst => '172.16.0.0/24',
			via => '192.168.0.2'
		),
	],
	attachments => [
		Attachment->new (
			lan => $dmz_lan,
			eth => 0
		),
		Attachment->new (
			lan => $staff_lan,
			eth => 1
		),
	],
	rules => [
		Rule->new (
			policy => 'FORWARD DROP',
		),
	],
);

my $gw = Machine->new (
	name => 'gw',
	interfaces => [
		Interface->new (
			eth => 0,
			ip => '80.64.157.254',
		),
		Interface->new (
			eth => 1,
			ip => '192.168.0.1/24',
		),
	],
	routes => [
		Route->new (
			dst => '172.16.0.0/24',
			via => '192.168.0.2'
		),
		Route->new (
			dst => '10.0.0.0/20',
			via => '192.168.0.3'
		),
	],
	attachments => [
		Attachment->new (
			lan => $ext_www_lan,
			eth => 0
		),
		Attachment->new (
			lan => $dmz_lan,
			eth => 1
		),
	],
	rules => [
		Rule->new (
			policy => 'FORWARD DROP',
		)
	],
);

my $staff_1 = Machine->new (
	name => 'Staff-1',
	interfaces => [
		Interface->new (
			eth => 0,
			ip => '10.0.0.5/20',
			mac => 'a8:30:67:3f:42:cf',
		),
	],
	routes => [
		Route->new (
			dst => 'default',
			via => '10.0.0.1'
		),
	],
	attachments => [
		Attachment->new (
			lan => $staff_lan,
			eth => 0,
		),
	],
);

dnat (
	src => $gw,
	dst =>'172.16.0.6',
	ports => [25, 587, 993]
);

$lab->dump($gw, $r2, $staff_1);

for($gw->ips){
	print "$_\n";
}