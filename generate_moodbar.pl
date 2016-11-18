#!/usr/bin/env perl

use v5.24.0;
use strict;
use utf8;
use warnings;

use File::Find;
use File::Spec qw(splitpath);
use List::MoreUtils qw(any);


my @EXTENSIONS = qw/flac mp3 ogg wav wma/;

my $can_use_threads = eval 'use threads; 1';

my $processors = 1;

sub help {
	say "Usage: $0 location(s)";
	say " e.g $0 .";
	exit(1);
}

sub main {
	find(\&wanted, @_);
	
	if($can_use_threads) {
		say get_processor_count();
		# find(\&wanted_threads, @_);
	}
	#else {
		# find(\&wanted, @_);
	#}
}

sub get_processor_count {
	open my $fh, '<:encoding(UTF-8)', "/proc/cpuinfo" or return 1;
	my @contents = <$fh>;
	my @filtered = grep (/^processor/, @contents);
	return scalar @filtered;
}

sub wanted {
	my $filename = $File::Find::name;
	
	if(-f $filename) {
		my ($ext) = $filename =~ /\.([^.]+)$/;
		
		if(any { $_ eq $ext } @EXTENSIONS) {
			my ($volume, $directories, $moodbarname) = File::Spec->splitpath($filename);
			$moodbarname = $directories . "." . $moodbarname =~ s/$ext/mood/gr;
			
			if(!-f $moodbarname) {
				my @syscall = ('/usr/bin/moodbar', '-o', $moodbarname, $filename);
				system @syscall;
			}
		}
	}
}

help() unless @ARGV > 0;
main(@ARGV);


__END__
