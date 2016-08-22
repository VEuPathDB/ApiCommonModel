package ApiCommonShared::Model::DataSourceList;

use strict;

=pod

=head1 Usage

  my $dbh = $self->getQueryHandle($cgi);
  my $dsList = ApiCommonShared::Model::DataSourceList->new($dbh);

  my $distinctSubtypeValues = $dsList->getDistinctValuesByField('subtype');
  my $dataSourceHashRef = $dsList->dataSourceHashByName('CalbSC5314_dbxref_unity_CGD_RSRC');

  my $filteredList = $dsList->filter('organism', 'Candida albicans SC5314');
  my $filteredDistinctSubtypeValues = $filteredList->getDistinctValuesByField('subtype');

=cut


sub new {
  my ($class, $dbh, $dataSources) = @_;

  unless(UNIVERSAL::isa($dbh,'DBI::db')) {
    die "Database handle not provided";
  }

  my $self = {dbh => $dbh};
  bless($self,$class);

  if($dataSources) {
    $self->setDataSources($dataSources);
  }
  else {
    $self->setDataSourcesFromDatabase();
  }

  return $self;
}

sub getDbh             { $_[0]->{dbh} }
sub getDataSources     { $_[0]->{dataSources} }
sub setDataSources     { $_[0]->{dataSources} = $_[1] }

sub getDistinctValuesByField { 
  my ($self, $field) = @_;

  my $datasources = $self->getDataSources();

  my %distinct;
  foreach my $hashref (values %$datasources) {
    my $value = $hashref->{uc($field)};
    $distinct{$value}++ if($value);
  }

  my @rv = keys %distinct;
  return \@rv;
}

sub setDataSourcesFromDatabase {
  my ($self) = @_;

  my $dbh = $self->getDbh();

  my $query = $dbh->prepare(<<SQL);
select * from (
select ds.name, ds.version, ds.data_source_id as id, ds.is_species_scope, ds.type, ds.subtype,tn.name as organism, tn.name_class as org_name_class
from apidb.datasource ds, sres.taxonname tn
where ds.taxon_id = tn.taxon_id (+)
) where org_name_class = 'scientific name' or organism is null
SQL

  $query->execute()
    or die "getting DataSource name/ID pairs";

  my %dataSources;

  while (my $hashref = $query->fetchrow_hashref()) {
    my $name = $hashref->{NAME};

    $dataSources{$name} = $hashref;
  }

  $self->{dataSources} = \%dataSources;

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
  my $dbh = $self->getDbh();

  my @allvalues = values %$dataSources;
  my @filtered;

  my %filtered;

  foreach my $hashref (@allvalues) {
    my $value = $hashref->{uc($filterField)};
    my $name = $hashref->{NAME};

    if($value && $filterValue eq $value) {
      $filtered{$name} = $hashref;
    }
  }

  return ApiCommonShared::Model::DataSourceList->new($dbh, \%filtered);
}

sub getDbDataSourceNames {
  my ($self) = @_;

  my $dataSourcesObj = $self->getDataSources();

  return keys(%$dataSourcesObj);
}

1;
