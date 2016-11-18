#!/usr/bin/env perl

use v5.24.0;
use strict;
use utf8;
use warnings;

use File::Find;
use File::Spec qw(splitpath);
use Getopt::Long;
use List::MoreUtils qw(any);

use threads;
use threads::shared;


my @EXTENSIONS = qw/flac mp3 ogg wav wma/;

my $can_use_threads = eval 'use threads; 1';
my $dryrun = 0;
my $help = 0;
my $overwrite = 0;
my $processors = 1;

my %files;

GetOptions(
    "dry-run|dryrun" => \$dryrun,
    "help" => \$help,
    "overwrite" => \$overwrite
);


sub help {
	say "Usage: $0 location(s)";
	say " e.g $0 .";
	say "Arguments:";
	say " --dryrun | --dry-run show changes without executing";
    say " --help               show this help text";
	say " --overwrite          overwrite any existing moodbar";
	exit(1);
}

sub main {
	find(\&wanted, @_);
	
	if($can_use_threads) {
		moodbar_threaded();
	}
	else {
		moodbar()
	}
}

sub wanted {
	my $filename = $File::Find::name;
	
	if(-f $filename) {
		my ($ext) = $filename =~ /\.([^.]+)$/;
		
		if(any { $_ eq $ext } @EXTENSIONS) {
			my ($volume, $directories, $moodbarname) = File::Spec->splitpath($filename);
			$moodbarname = $directories . "." . $moodbarname =~ s/$ext/mood/gr;
			
			$files{$filename} = $moodbarname if $overwrite || !-f $moodbarname;
		}
	}
}

sub moodbar {
	foreach my $filename (keys %files) {
		my $moodbarname = $files{$filename};
		
		if($overwrite || !-f $moodbarname) {
			my @syscall = ('/usr/bin/moodbar', '-o', $moodbarname, $filename);
			$dryrun ? say join(' ', @syscall) : system @syscall;
		}
	}
}

sub get_processor_count {
	open my $fh, '<:encoding(UTF-8)', "/proc/cpuinfo" or return 1;
	my @contents = <$fh>;
	my @filtered = grep (/^processor/, @contents);
	return scalar @filtered;
}

sub init_threads {
	my @threads;
	
	my $processors = get_processor_count();
	
	for(my $counter = 0; $counter < $processors; $counter++) {
		push(@threads, $counter);
	}
	
	return @threads;
}

sub moodbar_threaded {
	my @threads = init_threads();
	my @keys :shared;
	push(@keys, keys %files);
	
	foreach my $thread (@threads) {
		$thread = threads->create(
			sub {
				while (@keys) {
					my $filename = pop(@keys);
					my $moodbarname = $files{$filename};
					
					if($overwrite || !-f $moodbarname) {
						my @syscall = ('/usr/bin/moodbar', '-o', $moodbarname, $filename);
						$dryrun ? say join(' ', @syscall) : system @syscall;
					}
				}
				
				threads->exit();
			}
		)
	}
	
	foreach my $thread (@threads) {
		$thread->join();
	}
}

help() if $help;
help() unless @ARGV > 0;
main(@ARGV);


__END__
