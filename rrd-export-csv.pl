#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# export RRD files into CSV with columns utime,datetime,AVERAGE,MIN,MAX

die "usage: $0 /path/to.rrd" unless @ARGV;

foreach my $rrd ( @ARGV ) { ## XXX not idented

my $out_dir = $ENV{OUT} || '/var/www/csv/'; # FIXME make configurable

# scrientific notation to decimal
sub sn_to_dec {
    my $num = shift;

    if ($num =~ /^([+-]?)(\d*)(\.?)(\d*)[Ee]([-+]?\d+)$/) {
        my ($sign, $int, $period, $dec, $exp) = ($1, $2, $3, $4, $5);

        if ($exp < 0) {
            my $len = 1 - $exp;
            $int = ('0' x ($len - length $int)) . $int if $len > length $int;
            substr $int, $exp, 0, '.';
            return $sign.$int.$dec;

        } elsif ($exp > 0) {
            $dec .= '0' x ($exp - length $dec) if $exp > length $dec;
            substr $dec, $exp, 0, '.' if $exp < length $dec;
            return $sign.$int.$dec;

        } else {
            return $sign.$int.$period.$dec;
        }
    }

    return $num;
}

sub sn_to_dec2 { # cleanup zeros
	my $dec = sn_to_dec $_[0];
	$dec =~ s/\.0+$//;
	$dec =~ s/([1-9])0+$/$1/; # strip traling zeros
	return $dec;
}


my $cf;
my $cf2i;
my $cf_i;

#my @columns = qw(time datetime);
my @columns = qw(datetime);
my $data;
my $ts;

open(my $pipe, '-|', "rrdtool dump $rrd");
while(<$pipe>) {
	chomp;
	if ( m{<cf>(\w+)</cf>} ) {
		$cf = $1;
		if ( ! exists $cf2i->{$cf} ) {
			$cf_i = $cf2i->{$cf} = scalar keys %$cf2i;
			warn "## $cf $cf2i->{$cf}";
			push @columns, $cf;
		} else {
			$cf_i = $cf2i->{$cf};
		}

	} elsif ( m{<!-- (\S+\s\S+\s\S+) / (\d+) --> <row><v>([\d\+\-e\.]+)</v></row>} ) {
		#   <!-- 2021-01-14 14:35:00 CET / 1610631300 --> <row><v>3.748000000e-01</v></row>
		$data->{ $2 }->[ $cf_i  ] ||= sn_to_dec2 $3;
		$ts->{$2} = $1;
	} else {
		warn "IGNORE $_\n";
	}
}


my $csv_file = $rrd;
$csv_file =~ s{^.+/}{};
$csv_file =~ s{.rrd$}{.csv};
$csv_file = "$out_dir/$csv_file";

open(my $out,  '>', $csv_file);
print $out join(',', @columns),"\n";

foreach my $t ( sort keys %$data ) {
	#print $out join(',', $t, $ts->{$t}, @{ $data->{$t} } ),"\n";
	print $out join(',', $ts->{$t}, @{ $data->{$t} } ),"\n";
}
close($out);

print "$csv_file ", -s $csv_file," bytes\n";


} ## XXX end repeat foreach @ARGV

