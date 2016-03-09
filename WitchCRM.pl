#!/usr/bin/env perl

use v5.20;
use DBI;
use JSON;
use Template;
use Math::Currency;
use Getopt::Std;

use Data::Printer;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $version = "0.2";

my $config_file = 'conf.pl';
my $conf;
get_config( $config_file );

# Get command line arguments
$Getopt::Std::STANDARD_HELP_VERSION=1;
my $opts = {};
# l: 1 parameter: <i|c> list all invoices or clients
# c: 1 parameter: client id. List invoices
# p: 1 parameter: invoice number to print
# f: 1 parameter: (proforma) invoice number to print
# a: no parameters: add client
# i: 1 parameter: client id. Add invoice for client
getopts('l:c:p:f:ai:', $opts);

list_invoices()                         if( $opts->{'l'} eq 'i');
list_clients()                          if( $opts->{'l'} eq 'c');
list_clients_invoices( $opts->{'c'} )   if( $opts->{'c'} );
print_invoice( $opts->{'p'}, 0 )        if( $opts->{'p'} );
print_invoice( $opts->{'f'}, 1 )        if( $opts->{'f'} );
add_client()                            if( $opts->{'a'} );
add_invoice( $opts->{'i'} )             if( $opts->{'i'} );

sub HELP_MESSAGE {
    say "Usage:";
    say "$0 -l <i|c>               List all invoices / clients";
    say "$0 -c <client id>         List invoices for client with id";
    say "";
    say "$0 -p <invoice number>    Print invoice";
    say "$0 -f <invoice number>    Print proforma invoice";
    say "";
    say "$0 -a                     Add client";
    say "$0 -i                     Add invoice";
}
sub VERSION_MESSAGE {
    say "WitchCRM v" . $version;
}

sub add_client {
    my $client;

    print "id: ";
    $client->{'id'} = <STDIN>;
    chomp $client->{'id'};
    print "Name: ";
    $client->{'ragsoc'} = <STDIN>;
    chomp $client->{'ragsoc'};
    print "Address: ";
    $client->{'address'} = <STDIN>;
    chomp $client->{'address'};
    print "Zip: ";
    $client->{'zip'} = <STDIN>;
    chomp $client->{'zip'};
    print "City: ";
    $client->{'city'} = <STDIN>;
    chomp $client->{'city'};
    print "Province: ";
    $client->{'prov'} = <STDIN>;
    chomp $client->{'prov'};
    print "Country: ";
    $client->{'country'} = <STDIN>;
    chomp $client->{'country'};

    p $client;

    db_add_invoice(
        $client->{'id'},
        $client->{'ragsoc'},
        $client->{'address'},
        $client->{'zip'},
        $client->{'city'},
        $client->{'prov'},
        $client->{'country'}
    );

    exit(0);
}

sub add_invoice {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    $year += 1900;
    $mon++;
    $mon = "0" . $mon if( $mon < 10 );
    $mday = "0" . $mday if( $mday < 10 );

    my $invoice;

    $invoice->{'id'} = time;
    $invoice->{'client'} = shift;
    $invoice->{'emitted'} = $year . "-" . $mon . "-" . $mday;
    $invoice->{'total'} = 0;

    # Insert invoice rows
    my @rows;
    my $prod;
    my $price;

    while(1) {
        print "Service or product name: ";
        $prod = <STDIN>;
        chomp $prod;
        last if( $prod eq '' );
        print "Price: ";
        $price = <STDIN>;
        chomp $price;
        $invoice->{'total'} += $price;
        push @rows, [$prod, 1, $price];
    }

    $invoice->{'products'} = to_json([@rows]);

    print "Accounted: ";
    $invoice->{'accounted'} = 0;
    $invoice->{'accounted'} = 1 if(<STDIN> =~ '^y|^Y|^s|^S');

    p $invoice;

    db_add_invoice(
        $invoice->{'id'},
        $invoice->{'emitted'},
        $invoice->{'products'},
        $invoice->{'total'},
        $invoice->{'accounted'},
        $invoice->{'client'}
    );

    exit(0);
}

sub list_invoices {
    my $sth = db_list_invoices();
    my @rows;
    while( my $row = $sth->fetchrow_hashref ) {
        push @rows, $row;
    }
    say encode_json(\@rows);
    exit(0);
}

sub list_clients {
    my $sth = db_list_clients();
    my @rows;
    while( my $row = $sth->fetchrow_hashref ) {
        push @rows, $row;
    }
    say encode_json(\@rows);
    exit(0);
}

sub list_clients_invoices {
    my $client = shift;
    my $sth = db_list_clients_invoices( $client );
    my @rows;
    while( my $row = $sth->fetchrow_hashref ) {
        push @rows, $row;
    }
    say encode_json(\@rows);
    exit(0);
}

sub print_invoice {
    my $id = shift;
    my $proforma = shift;
    my $sth = db_get_invoice_by_id( $id );
    my $row = $sth->fetchrow_hashref;
    my $client = {
        piva    => $row->{'piva'},
        ragsoc  => $row->{'ragsoc'},
        address => $row->{'address'},
        zip     => $row->{'zip'},
        city    => $row->{'city'},
        prov    => $row->{'prov'},
        country => $row->{'country'},
    };
    my $invoice = {
        num     => $row->{'num'},
        emitted => $row->{'emitted'},
        expires => $row->{'expires'},
    };
    my $services = decode_json($row->{'products'});

    # Calculate values
    my $netto = Math::Currency->new("0", "de_DE");
    $netto->format('CURRENCY_SYMBOL', ' &euro;');
    foreach my $s ( @{$services} ) {
        $netto += $s->[2];
    }
    my $lordo =  $netto / 0.8;
    my $ritenuta = $lordo - $netto;

    # Configure template
    my $html_output = './invoices/' . $invoice->{'emitted'} . ' - ' . $invoice->{'num'} . '.html';
    my $pdf_output  = './invoices/' . $invoice->{'emitted'} . ' - ' . $invoice->{'num'} . '.pdf';
    my $tconfig = {
        INCLUDE_PATH => './templates',
        INTERPOLATE  => 1,               # expand "$var" in plain text
        RELATIVE     => 1,
    };
    my $template = Template->new($tconfig);
    $template->process('template.tt',
        {
            dest        => $client,
            invoice     => $invoice,
            services    => $services,
            netto       => $netto,
            lordo       => $lordo,
            ritenuta    => $ritenuta,
            proforma    => $proforma,
        },
        $html_output
    ) || die $template->error(), "\n";
    system('wkhtmltopdf', '-B','0', '-T','0', '-L','0', '-R','0', $html_output, $pdf_output);
    if ($? == -1) {
        print "failed to execute wkhtmltopdf: $!\n";
    }
    elsif ($? & 127) {
        printf "child died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
        printf "child exited with value %d\n", $? >> 8;
    }
    unlink $html_output;
    system('gpg', '-sb', $pdf_output);
    if ($? == -1) {
        print "failed to execute gpg: $!\n";
    }
    elsif ($? & 127) {
        printf "child died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
        printf "child exited with value %d\n", $? >> 8;
    }
}


sub get_config {
    my $config_file = shift;
    open( my $confh, '<', "$config_file" )
        or die "Can't open the configuration file '$config_file'.\n";
    my $config = join "", <$confh>;
    close( $confh );
    eval $config;
}

sub db {
    my $dbh = DBI->connect( $conf->{'db_host'}, $conf->{'db_user'}, $conf->{'db_pass'}, { pg_enable_utf8 => 1 } )
		or die ( ( defined DBI::errstr ) ? DBI::errstr : 'DBI::errstr undefined' );
    return $dbh;
}
sub db_add_client {
    my ($id,$ragsoc,$address,$zip,$city,$prov,$country) = @_;
    my $dbh = db();
    my $sth = $dbh->prepare(
        "INSERT INTO clients (id,ragsoc,address,zip,city,prov,country)
        VALUES(?,?,?,?,?,?,?);"
    );
    $sth->execute();
    return $sth;
}
sub db_add_invoice {
    my ($id,$emitted,$products,$total,$accounted,$client) = @_;
    my $dbh = db();
    my $sth = $dbh->prepare(
        "INSERT INTO invoices (id,emitted,products,total,accounted,client)
        VALUES(?,?,?,?,?,?);"
    );
    $sth->execute($id,$emitted,$products,$total,$accounted,$client);
    return $sth;
}
sub db_list_invoices {
    my $dbh = db();
    my $sth = $dbh->prepare(
        "SELECT i.id AS num, total, emitted, accounted, ragsoc, c.id AS piva
        FROM clients c JOIN invoices i
        ON c.id = i.client"
    );
    $sth->execute();
    return $sth;
}
sub db_list_clients {
    my $dbh = db();
    my $sth = $dbh->prepare(
        "SELECT id,ragsoc FROM clients"
    );
    $sth->execute();
    return $sth;
}
sub db_list_clients_invoices {
    my $client = shift;
    my $dbh = db();
    my $sth = $dbh->prepare(
        "SELECT i.id AS num, total, emitted, accounted, ragsoc, c.id AS piva
        FROM clients c JOIN invoices i
        ON c.id = i.client
        WHERE c.id = ?"
    );
    $sth->execute( $client );
    return $sth;
}
sub db_get_invoice_by_id {
    my $id = shift;
    my $dbh = db();
    my $sth = $dbh->prepare(
        "SELECT *,c.id AS piva, i.id AS num
        FROM clients c JOIN invoices i
        ON c.id = i.client
        WHERE i.id = ?"
    );
    $sth->execute( $id );
    return $sth;
}

