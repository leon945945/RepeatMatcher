#!/usr/bin/perl

=head1 NAME

extendRepeatConsensus.pl

=head1 DESCRIPTION

Iterative program to extend the borders in for a RepeatModeler consensus.

=head1 USAGE

    perl extendRepeatConsensus.pl [PARAM]

    Parameter     Description                                       Default
    -i --in       Consensus Fasta
    -g --genome   Genome Fasta
    -o --out      Output fasta
    -s --size     Step size per iteration                           [       8]
    -e --engine   Alignment engine (rmblast, wublast)               [ wublast]
    -x --matrix   Score matrix                             [14p35g.matrix.4.4]
    -c --score    Minimal score                                     [     200]
    -n --numseqs  Maximal number of sequences to try extending      [     500]
    -m --minseqs  Minimal number of sequences to continue extending [       3]
    -l --minlen   Minimal length of sequences                       [     100]
    -d --div      Divergence level (14,18,20,25)                    [      14]
    -z --maxn     Maximal number of no-bases in extension           [       2]
    -w --win      Extension window                                  [     100]
    --minscore    Cross_match minscore                              [     200]
    --minmatch    Cross_match minmatch                              [       7]
    -t --temp     Temporary file names                              [    temp]
    -a --auto     Run auto mode (non-interactive)
    --no3p        Don't extend to 3'
    --no5p        Don't extend to 5'
    
    -h --help     Print this screen and exit
    -v --verbose  Verbose mode on
    --version     Print version and exit

=head1 EXAMPLES

    perl extendRepeatConsensus.pl -i repeat.fa -g genome.fa -o new_repeat.fa

=head1 AUTHOR

Juan Caballero, Institute for Systems Biology @ 2012

=head1 CONTACT

jcaballero@systemsbiology.org

=head1 LICENSE

This is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with code.  If not, see <http://www.gnu.org/licenses/>.

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use lib './lib';
use NCBIBlastSearchEngine;
use WUBlastSearchEngine;
use SearchEngineI;
use SearchResultCollection;


# Default parameters
my $help     =     undef;         # Print help
my $verbose  =     undef;         # Verbose mode
my $version  =     undef;         # Version call flag
my $in       =     undef;
my $genome   =     undef;
my $out      =     undef;
my $auto     =     undef;
my %conf     = (
    size     => 8,
    engine   => 'wublast',
    numseq   => 500,
    minseq   => 3,
    minlen   => 100,
    div      => 14,
    maxn     => 2,
    win      => 100,
    no3p     => 0,
    no5p     => 0,
    temp     => 'temp',
    minmatch => 7,
    minscore => 200,
    matrix   => '14p35g.matrix.4.4');

# Main variables
my $our_version = 0.1;
my $linup       = './Linup';
my $rmblast     = '/usr/local/rmblast/bin/rmblastn';
my $makeblastdb = '/usr/local/rmblast/bin/makeblastdb';
my $wublast     = '/usr/local/wublast/blastn';
my $xdformat    = '/usr/local/wublast/xdformat';
my $matrix_dir  = './Matrices';
my $cross_match = '/usr/local/bin/cross_match';
my $new         = '';
my %genome      = ();
my %genome_len  = ();
my ($searchResults, $status, $Engine, $matrix);

# Calling options
GetOptions(
    'h|help'            => \$help,
    'v|verbose'         => \$verbose,
    'i|in=s'            => \$in,
    'o|out=s'           => \$out,
    'g|genome=s'        => \$genome,
    'd|divergence:i'    => \$conf{'div'},
    's|size:i'          => \$conf{'size'},
    'l|minlen:i'        => \$conf{'minlen'},
    'e|engine:s'        => \$conf{'engine'},
    't|temp:s'          => \$conf{'temp'},
    'n|numseq:i'        => \$conf{'numseq'},
    'm|minseq:i'        => \$conf{'minseq'},
    'z|maxn:i'          => \$conf{'maxn'},
    'w|win:i'           => \$conf{'win'},
    'minscore:i'        => \$conf{'minscore'},
    'minmatch:i'        => \$conf{'minmatch'},
    'no3p'              => \$conf{'no3p'},
    'no5p'              => \$conf{'no5p'}
) or pod2usage(-verbose => 2);
printVersion()           if  (defined $version);
pod2usage(-verbose => 2) if  (defined $help);
pod2usage(-verbose => 2) if !(defined $in);
pod2usage(-verbose => 2) if !(defined $out);
pod2usage(-verbose => 2) if !(defined $genome);

$matrix = $conf{'matrix'};

if ($conf{'engine'} eq 'wublast') {
    $Engine = WUBlastSearchEngine->new(pathToEngine => $wublast);
    $Engine->setMatrix("$matrix_dir/wublast/nt/$matrix");
}
elsif ($conf{'engine'} eq 'rmblast') {
    $Engine = NCBIBlastSearchEngine->new(pathToEngine => $rmblast);
    $Engine->setMatrix("$matrix_dir/ncbi/nt/$matrix");
}
else { die "search engine not supported: $conf{'engine'}\n"; }

checkCmd();
checkIndex($conf{'engine'}, $genome);
my $cm_param    = checkDiv($conf{'div'});
my ($lab, $rep) = readFasta($in);
my $iter        = 0;
loadGenome($genome);

###################################
####        M A I N            ####
###################################
while (1) {
    warn "extending repeat, iter: $iter\n" if (defined $verbose);
    $new = extendRepeat($rep);
    my $len_old = length $rep;
    my $len_new = length $new;
    last if ($len_old == $len_new);
    $rep = $new;
    $iter++;
    next if (defined $auto);
    
    my $res;
    print "ITER #$iter\n";
    my ($left, $right) = readBlocks($conf{'temp'}.'ali');
    
    if ($conf{'no5p'} != 0) {
        print "LEFT BLOCK:\n$left\n";
        print "PRESS ANY KEY TO CONTINUE\n";
        $res = <>;
    }
    if ($conf{'no3p'} != 0) {
        print "RIGHT BLOCK:\n$right\n";
        print "PRESS ANY KEY TO CONTINUE\n";
        $res = <>;
    }
    
    print "SELECT: Stop|Continue|Modify\n";
    $res = <>;
    chomp $res;
    last if ($res =~ m/^s/i);
    next if ($res =~ m/^c/i);
    
    print "Changing parameters:\n";
    foreach my $param (keys %conf) {
        print "   $param [", $conf{$param}, "] : ";
        $res = <>; 
        chomp $res; 
        $conf{$param} = $res if (defined $res);
    }
}
printFasta("$lab | extended", $new, $out);

###################################
####   S U B R O U T I N E S   ####
###################################
sub printVersion {
    print "$0 $our_version\n";
    exit 1;
}

sub readFasta {
    my $file = shift @_;
    warn "reading file $file\n" if (defined $verbose);
    my ($name, $seq);
    open F, "$file" or die "cannot open $file\n";
    while (<F>) {
        chomp;
        if (/>/) {
            $name = $_;
        }
        else {
            $seq .= $_;
        }
    }
    close F;
    return $name, $seq;
}

sub printFasta {
    my ($head, $seq, $file) = @_;
    my $col = 80;
    warn "writing file $file\n" if (defined $verbose);
    open  F, ">$file" or die "cannot write $file\n";
    print F "$head\n";
    while ($seq) {
        my $s = substr($seq, 0, $col);
        print F "$s\n";
        substr($seq, 0, $col) = '';
    }
    close F;
}

sub checkIndex {
    my ($engine, $genome) = @_;
    if ($engine eq 'rmblast') {
        unless (-e "$genome.nhr" and -e "$genome.nin" and -e "$genome.nsq") {
            warn "missing indexes for $genome, generating them\n" if (defined $verbose);
            system ("$makeblastdb -in $genome -dbtype nucl");
        }
    }
    elsif ($engine eq 'wublast') {
        unless (-e "$genome.xnd" and -e "$genome.xns" and -e "$genome.xnt") {
            warn "missing indexes for $genome, generating them\n" if (defined $verbose);
            system ("$xdformat -n $genome");
        }
    }
    else {
        die "Engine $engine is not supported\n";
    }
}

sub loadGenome {
    my ($file) = @_;
    warn "reading file $file\n" if (defined $verbose);
    open F, "$file" or die "cannot open $file\n";
    my $name = '';
    while (<F>) {
        chomp;
        if (m/^>/) {
            s/>//;
            s/\s+.*//;
            $name = $_;
        }
        else {
            $genome{$name}     .= $_;
            $genome_len{$name} += length $_;
        }
    }
    close F;
}

sub extendRepeat {
    my ($rep)       = @_;
    my @left_seqs   = ();
    my @right_seqs  = ();
    my $left        = '';
    my $right       = '';
    my $cons        = '';
    my $null        = '';
    my $temp        = $conf{'temp'};
    my $matrix      = $conf{'matrix'};
    my $minlen      = $conf{'minlen'};
    my $minscore    = $conf{'minscore'};
    my $minseqs     = $conf{'minseqs'};
    my $numseqs     = $conf{'numseqs'};
    my $maxn        = $conf{'maxn'};
    my $size        = $conf{'size'};
    my $win         = $conf{'win'};
    my $ext         = 'Z' x $size;
    my $hits;
    open  F, ">$temp.fa" or die "cannot write $temp.fa\n";
    print F  ">repeat\n$rep\n";
    close F;

    $Engine->setQuery("$temp.fa");
    $Engine->setSubject($genome);
    ($status, $searchResults) = $Engine->search();
    die "Search returned an error: $status\n" if (defined $status);
    
    $hits = $searchResults->size();

    warn "Found $hits candidate hits\n" if (defined $verbose);
    for ( my $i = 0 ; $i < $hits; $i++ ) {
        my $qName  = $searchResults->get( $i )->getQueryName;
        my $qStart = $searchResults->get( $i )->getQueryStart;
        my $qEnd   = $searchResults->get( $i )->getQueryEnd;
        my $hName  = $searchResults->get( $i )->getSubjName;
        my $hStart = $searchResults->get( $i )->getSubjStart;
        my $hEnd   = $searchResults->get( $i )->getSubjEnd;
        my $dir    = $searchResults->get( $i )->getOrientation;
        my $score  = $searchResults->get( $i )->getScore;
        my $hLen   = $hEnd - $hStart;
        my $seq    = '';
        next if ($score < $minscore);
        next if ($hLen  < $minlen);
        
        if ($conf{'no5p'} != 0) {
            if ($qStart > $win and $hStart < $size) {
                $seq = substr($genome{$hName}, $hStart - $qStart - 1, $hLen + $size);
                $seq = revcomp($seq) if ($dir eq 'C' or $dir eq '-' or $dir eq 'R');    
                push @left_seqs, $seq if (($#left_seqs + 1 ) <= $numseqs);
            }
        }
        
        if ($conf{'no3p'} != 0) {
            if ($qEnd < ($hLen - $win) and ($hEnd + $size) <= $genome_len{$hName}) {
                $seq = substr($genome{$hName}, $hEnd + ($hLen - $qEnd) - 1, $hLen + $size);
                $seq = revcomp($seq) if ($dir eq 'C' or $dir eq '-' or $dir eq 'R');    
                push @right_seqs, $seq if (($#right_seqs + 1 ) <= $numseqs);
            }
        }
    }
    
    my $nleft  = scalar @left_seqs;
    my $nright = scalar @right_seqs;
    
    warn "$nleft in left side, $nright in right side\n" if (defined $verbose); 
      
    if (($#left_seqs + 1)  >= $minseqs) {
        $cons  = createConsensus("$ext$rep", @left_seqs);
        $left  = substr($cons, 0, $size);
        $null  = $left =~ tr/N/N/;
        $left  = '' if ($null >= $maxn);
    }
    if (($#right_seqs + 1) >= $minseqs) {
        $cons  = createConsensus("$rep$ext", @right_seqs);
        $right = substr($cons, (length $cons) - $size, $size);
        $null  = $right =~ tr/N/N/;
        $right = '' if ($null >= $maxn);
    }
    
    warn "extensions: left=$left, right=$right\n" if (defined $verbose);
    return "$left$rep$right";
}

sub createConsensus {
    my $rep = shift @_;
    my $temp = $conf{'temp'};
    open  R, ">$temp.rep.fa" or die "cannot write $temp.rep.fa\n";
    print R  ">rep0\n$rep\n";
    close R;
    
    open  F, ">$temp.repseq.fa" or die "cannot write $temp.repseq.fa\n";
    my $i = 1;
    while (my $seq = shift @_) {
        print F ">rep$i\n$seq\n";
        $i++;
    }
    close F;
    
    system "$cross_match $temp.repseq.fa $temp.rep.fa $cm_param -alignments > $temp.cm_out";
    
    system "$linup $temp.cm_out $matrix_dir/linup/nt/linupmatrix > $temp.ali";
    
    my $con = '';
    open A, "$temp.ali" or die "cannot open file $temp.ali\n";
    while (<A>) {
        chomp;
        next unless (m/^consensus/);
        s/consensus\s+\d+\s+//;
        s/\s+\d+$//;
        s/-//g;
        $con .= $_;
    }
    close A;
    
    return $con;
}

sub readBlocks {
    my $file = shift;
    local $/ = "\n\n";
    open F, "$file" or die "cannot open $file\n";
    my @blocks = <F>;
    close F;
    return $blocks[0], $blocks[-1];
}

sub checkDiv {
    my ($div)    = @_;
    my $par      = '';
    my $minscore = $conf{'minscore'};
    my $minmatch = $conf{'minmatch'};
    if    ($div == 14) { $par = "-M $matrix_dir/crossmatch/14p41g.matrix -gap_init -33 -gap_ext -6 -minscore $minscore -minmatch $minmatch"; }
    elsif ($div == 18) { $par = "-M $matrix_dir/crossmatch/18p41g.matrix -gap_init -30 -gap_ext -6 -minscore $minscore -minmatch $minmatch"; }
    elsif ($div == 20) { $par = "-M $matrix_dir/crossmatch/20p41g.matrix -gap_init -28 -gap_ext -6 -minscore $minscore -minmatch $minmatch"; }
    elsif ($div == 25) { $par = "-M $matrix_dir/crossmatch/25p41g.matrix -gap_init -25 -gap_ext -5 -minscore $minscore -minmatch $minmatch"; }
    else  { die "Wrong divergence value, use [14,18,20,25]\n"; }
    
    warn "div=$div, cm_param=$par\n" if (defined $verbose);
    return $par;
}

sub revcomp{
    my ($s) = @_;
    my $r = reverse $s;
    $r =~ tr/ACGTacgt/TGCAtgca/;
    return $r;
}
