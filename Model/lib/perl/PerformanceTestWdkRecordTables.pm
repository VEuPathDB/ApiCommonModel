package ApiCommonModel::Model::PerformanceTestWdkRecordTables;

use strict;
use LWP::Simple;
use Data::Dumper;
use JSON qw( decode_json );
use YAML qw(LoadFile);

sub performanceTestRecordTables {
  my ($siteServiceUrl, $idsFile) = @_;

  my $idsMap = LoadFile($filename);
  my $resultMap = {};

  print STDERR "Reading from wdk /record-types endpoint\n";
  my $recordsString = get("https://$siteServiceUrl/record-types?format=expanded");
  my $recordClassesJson = decode_json($recordsString);

  foreach my $recordClass (@$recordClassesJson) {
    my $className = $recordClass->{urlSegment};
    if (!$idsMap->{$className}) {
      print STDERR "can't find IDs for record '$className'\n";
      next;
    }
    foreach my $table (@{$recordClass->{tables}}) {
      my $tableName = $table->{name};
      foreach my $id (@{$idsMap->{$className}}) {
	my ($start, $end, duration) = runTest($id, $classname, $tablename);
	$resultMap->{$className}->{$tableName}->{$id} = [$start, $end, $duration];
      }
    }

  }
  return $resultMap;
}

sub runTest {
  my ($id, $classname, $tablename, $serviceUrl) = @_;

  my $ua = LWP::UserAgent->new;

  my $requestBody = {};
  $requestBody->{tables} = [$tableName];
  $requestBody->{attributes} = [];
  my @pk;
  foreach my $pkPart (@{$id}) {
    push(@pk, {$pkPart, $id->{$pkPart}});
  }
  my $req = HTTP::Request->new(POST => "$serviceUrl/record-types/$classname/records");
  $req->header('content-type' => 'application/json');
  $req->content($requestBody);

  my $resp = $ua->request($req);
  die "HTTP POST error code: " . $resp->code ." $resp->message\n" unless $resp->is_success;
  my $message = $resp->decoded_content;
  print Dumper $message;
}

1;

