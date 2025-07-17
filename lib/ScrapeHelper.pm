package ScrapeHelper;
use warnings;
use strict;
#
# Bundle some routines that are helpful for scraping
#
# Copyright (C) 2025 Hamish Coleman
# SPDX-License-Identifier: GPL-2.0-only

use HTML::TreeBuilder;
use IO::HTML;
use Text::CSV;

$IO::HTML::default_encoding = 'utf8';

# Load a file from disk into a HTML::TreeBuilder object
sub file2tree {
    my $file = shift;

    my $fh = html_file($file);
    return undef if (!$fh);

    my $tree = HTML::TreeBuilder->new;
    $tree->ignore_unknown(0);
    $tree->parse_file($fh);
    $tree->eof;
    $tree->elementify;

    return $tree;
}

# Given a Tree object, use the supplied look_down filter and return the
# text found
sub look_down2text {
    my $node = shift;

    my $found = $node->look_down(@_);
    if (!$found) {
        die("Could not find item");
        return undef;
    }

    return $found->as_trimmed_text();
}

sub outputcsv {
    my $outfilename = shift;
    my $fields = shift;

    my $outfile;
    if ($outfilename eq '-') {
        $outfile = *STDOUT;
        binmode($outfile, ":utf8");
    } else {
        open($outfile, '>:encoding(utf8)', $outfilename);
    }

    my $csv = Text::CSV->new();

    $csv->print($outfile, $fields);
    $outfile->print("\n");

    while (my $row = shift) {
        my @row_fields = map({$row->{$_}} @{$fields});
        $csv->print($outfile, \@row_fields);
        $outfile->print("\n");
    }
}
1;
