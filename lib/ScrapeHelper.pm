package ScrapeHelper;
use warnings;
use strict;
#
# Bundle some routines that are helpful for scraping
#

use HTML::TreeBuilder;
use IO::HTML;

# Load a file from disk into a HTML::TreeBuilder object
sub file2tree {
    my $file = shift;

    my $fh = html_file($file);
    return undef if (!$fh);

    my $tree = HTML::TreeBuilder->new;
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

1;
