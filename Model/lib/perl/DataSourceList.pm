package ApiCommonShared::Model::DataSourceList;

use strict;

sub new {
  my ($class, $dbh) = @_;

  unless(UNIVERSAL::isa($dbh,'DBI::db')) {
    die "Error Connecting to the database";
  }
  my $self = {dbh => $dbh};

  bless($self,$class);

  $self->readDatabase();

  return $self;
}



sub getDbh             { $_[0]->{dbh} }
sub getDataSources     { $_[0]->{dataSources} }
sub getTypes           { $_[0]->{types} }
sub getSubtypes        { $_[0]->{dataSources} }
sub getOrganisms       { $_[0]->{organisms} }

sub readDatabase {
  my ($self) = @_;

  my $dbh = $self->getDbh();

  my $query = $dbh->prepare(<<SQL);
select * from (
select ds.name, ds.version, ds.is_species_scope, ds.type, ds.subtype,tn.name as organism, tn.name_class as org_name_class
from apidb.datasource ds, sres.taxonname tn
where ds.taxon_id = tn.taxon_id (+)
) where org_name_class = 'scientific name' or organism is null
SQL

  $query->execute()
    or die "getting DataSource name/ID pairs";

  my %dataSources;

  my %types;
  my %subtypes;
  my %organisms;

  while (my $hashref = $query->fetchrow_hashref()) {
    my $name = $hashref->{NAME};

    my $type = $hashref->{TYPE};
    my $subtype = $hashref->{SUBTYPE};
    my $organism = $hashref->{ORGANISM};

    $types{$type}++ if($type);
    $subtypes{$subtype}++ if($subtype);
    $organisms{$organism}++ if($organism);

    $dataSources{$name} = $hashref;
  }

  $self->{dataSources} = \%dataSources;

  my @organisms = keys %organisms;
  my @types = keys %types;
  my @subtypes = keys %subtypes;


  $self->{organisms} = \@organisms;
  $self->{types} = \@types;
  $self->{subtypes} = \@subtypes;

  return %dataSources;
}


sub isExistingDataSource {
  my ($self, $name) = @_;

  my $dataSources = $self->getDataSources();

  return defined($dataSources->{$name});
}

sub dataSourceHashByName {
  my ($self, $name) = @_;

  my $dataSources = $self->getDataSources();

  return $dataSources->{$name};
}

sub filter {
  my ($self, $filterField, $filterValue) = @_;

  my $dataSources = $self->getDataSources();

  my @allvalues = values %$dataSources;
  my @filtered;

  foreach my $hashref (@allvalues) {
    my $value = $hashref->{uc($filterField)};

    if($value && $filterValue eq $value) {
      push @filtered, $hashref;
    }
  }

  return \@filtered;
}



1;
