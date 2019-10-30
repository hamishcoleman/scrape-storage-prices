package ScrapeExtractStorage;
use warnings;
use strict;
#
# Given the text description string from a vendor of storage,
# Attempt to extract details in a normalised way
#

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Quotekeys = 0;

use POSIX qw(strftime);

# Set the default value for undefined items
sub _default {
    my $data = shift;
    my $key = shift;
    my $val = shift;

    if (!defined($data->{$key})) {
        $data->{$key} = $val;
    }
}

sub set_blank_fields_to_default {
    my $data = shift;

    # Set some default values
    _default($data,'brand','?');
    _default($data,'form','?');
    _default($data,'gig','?');
    _default($data,'interface','?');
    _default($data,'speed','?');
    _default($data,'sgig','?');
}

# Table of regular expressions that can extract data from the comment
my $matchtable = {

    # size
    # (most sizes are have a general regex, below. these are the exceptions)
    ' 120G '          => { gig => '120' },
    ' 1920GB/1.92TB ' => { gig => '1920' },
    ' 200G$'          => { gig => '200' },
    ' 240G '          => { gig => '240' },
    ' 250G '          => { gig => '250' },
    ' 256G '          => { gig => '256' },
    ' 375G$'          => { gig => '375' },
    ' 480G '          => { gig => '480' },
    ' 480GB_ '        => { gig => '480' },
    ' 500G '          => { gig => '500' },
    ' 512G '          => { gig => '512' },
    ' 960G '          => { gig => '960' },
    ' 1000G '         => { gig => '1000' },
    '/120G '          => { gig => '120' },
    '/240G '          => { gig => '240' },
    '/480G '          => { gig => '480' },

    # form factor
    ' 2\.5([^0-9]|$)' => { form => '2.5"' },
    ' 2_5" '          => { form => '2.5"' },
    ' 3\.5([^0-9]|$)' => { form => '3.5"' },
    ' M2( |$)'        => { form => 'M.2' },
    ' M\.2([^0-9]|$)' => { form => 'M.2' },
    ' M\.2280 '       => { form => 'M.2' },
    ' SFF '           => { form => '2.5"' },
    ' mSATA'          => { form => 'mSATA', interface => 'SATA' },
    ' u\.2 '          => { form => 'U.2' }, # Not really a form-factor

    # interface
    ' nvme '              => { interface => 'NVME' },
    ' nvme gen 3x2 '      => { interface => 'NVME', speed => 'PCIe3 x2' },
    ' nvme gen 3x4 '      => { interface => 'NVME', speed => 'PCIe3 x4' },
    ' nvme gen 3.0 x 4$'  => { interface => 'NVME', speed => 'PCIe3 x4' },
    ' pcie 3\.0 '         => { interface => 'NVME', speed => 'PCIe3' },
    ' pcie 3\.1 x4'       => { interface => 'NVME', speed => 'PCIe3.1 x4' },
    ' pcie 3x4 '          => { interface => 'NVME', speed => 'PCIe3 x4' },
    ' pcie g3 x4( |$)'    => { interface => 'NVME', speed => 'PCIe3 x4' },
    ' pcie gen3x4'        => { interface => 'NVME', speed => 'PCIe3 x4' },
    ' pcie nvme gen4'     => { interface => 'NVME', speed => 'PCIe4' },
    ' pcie x4 gen4'       => { interface => 'NVME', speed => 'PCIe4 x4' },
    ' pcie ?$'            => { interface => 'NVME' },
    ' pcie m2( |$)'       => { interface => 'NVME', form => 'M.2' },
    ' sas( |$)'           => { interface => 'SAS' },
    ' sata( |_|$)'        => { interface => 'SATA', speed => 'SATA' },
    ' sata3( |$)'         => { interface => 'SATA', speed => 'SATA3' },
    ' sataiii( |$)'       => { interface => 'SATA', speed => 'SATA3' },
    ' usb ?3\.0 '         => { interface => 'USB', speed => 'USB 3.0' },
    ' usb3\.1 '           => { interface => 'USB', speed => 'USB 3.1' },
    ' type-c drive( |$)'  => { interface => 'USB' },

    # brand
    'adata '        => { brand => 'Adata' },
    'corsair '      => { brand => 'Corsair' },
    'crucial '      => { brand => 'Crucial' },
    'galax '        => { brand => 'Galax' },
    'gigabyte '     => { brand => 'Gigabyte' },
    'hitachi '      => { brand => 'Hitachi' },
    'hp '           => { brand => 'HP' },
    'hpe '          => { brand => 'HP' },
    'intel '        => { brand => 'Intel' },
    'lexar '        => { brand => 'Lexar' },
    'kingston '     => { brand => 'Kingston' },
    'micron '       => { brand => 'Micron' },
    'ocz '          => { brand => 'OCZ' },
    'patriot '      => { brand => 'Patriot' },
    'qnap '         => { brand => 'Qnap' },
    'samsung '      => { brand => 'Samsung' },
    'sandisk '      => { brand => 'SanDisk' },
    'seagate '      => { brand => 'Seagate' },
    'team '         => { brand => 'Team' },
    'toshiba '      => { brand => 'Toshiba' },
    'transcend '    => { brand => 'Transcend' },
    'wd '           => { brand => 'WD' },
};

# A list of regular expresions to match problem entries
my $table_skip = {
    'Bay Rafter 2.5 Inch to 3.5 Inch Convertor' => 'Not storage',
    'Type-C Black External HDD Enclosure' => 'Not storage',
    'One-Touch NFC for easy connection' => 'Not storage',

    '2.5" PCIe 3.1 x4_ OPTANE_ W/ M.2' => 'Too many matching size buzzwords',
    # TODO - find a way to allow this HDD without making all the regex horrid
};

sub extract1product {
    my $data = shift;

    # Normalise the price field
    $data->{price} =~ s/^\$//;
    $data->{price} =~ s/,//;

    # commas annoy my dodgy not-quite-csv
    $data->{comment} =~ s/,/_/g;

    my $t = $data->{comment};

    my $errors = 0;

    # TODO - ensure price starts with a dollarsign
    $data->{date} = strftime("%Y-%m-%d", gmtime($data->{timestamp}));

    while (my ($re,$entry) = each(%{$table_skip})) {
        if ($t =~ m/$re/i) {
            $data->{speed} = $entry;
            set_blank_fields_to_default($data);
            return $data;
        }
    }

    while (my ($re,$entry) = each(%{$matchtable})) {
        if ($t =~ m/$re/i) {
            # Set metadata
            $entry->{_matches}++;

            while (my ($k,$v) = each(%{$entry})) {
                # Skip metadata
                next if ($k =~ m/^_/);
                if (defined($data->{$k}) && ($data->{$k} ne $v)) {
                    warn("WARN: Duplicate key match");
                    print(" re: $re\n");
                    print(" key: $k\n");
                    print(" data: ",Dumper($data));
                    $errors++;
                } else {
                    $data->{$k} = $v;
                }
            }
        }
    }

    if ($t =~ m/ (\d+) ?rpm( |_|$)/i) {
        $data->{speed} = sprintf("RPM: %5i",$1);
    } elsif ($t =~ m/ ([0-9][0-9.]+)k/i) {
        $data->{speed} = sprintf("RPM: %5i",$1 * 1000);
    }

    if (!defined($data->{gig})) {
             if ($t =~ m/ ([0-9][0-9.]*) ?tb( |_|$)/i) {
            $data->{gig} = $1 * 1000;
        } elsif ($t =~ m/ (\d+) ?gb( |_|$)/i) {
            $data->{gig} = $1;
        }
    }

    # If we are an old hard drive form factor, we are probably SATA
    # TODO - what about IDE?
    if (defined($data->{form}) && !defined($data->{interface})) {
        if ($data->{form} eq '2.5"' || $data->{form} eq '3.5"') {
            $data->{interface} = "SATA?";
        }
    }

    if ($data->{price} && $data->{gig}) {
        $data->{sgig} = sprintf("%.3f",$data->{price} / $data->{gig});
    }

    set_blank_fields_to_default($data);

    if ($errors) {
        die("Errors during normalisation");
    }
    return $data;
}

sub extractproducts {
    my %seen;
    my @products;
    while (my $prod = shift) {
        $seen{$prod->{comment}} ++;
        next if ($seen{$prod->{comment}} > 1);

        push @products, extract1product($prod);
    }
    return @products;
}

# Allow checking how many matches there were
sub matchtable {
    return $matchtable;
}

1;
