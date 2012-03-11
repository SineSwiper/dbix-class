use strict;
use warnings;

use Test::More;
use Test::Exception;
use Try::Tiny;
use DBIx::Class::SQLMaker::LimitDialects;
use DBIx::Class::Optional::Dependencies ();
use lib qw(t/lib);
use DBICTest;
use DBIC::SqlMakerTest;

plan skip_all => 'Test needs ' . DBIx::Class::Optional::Dependencies->req_missing_for ('test_rdbms_mssql_odbc')
  unless DBIx::Class::Optional::Dependencies->req_ok_for ('test_rdbms_mssql_odbc');

my ($dsn, $user, $pass) = @ENV{map { "DBICTEST_MSSQL_ODBC_${_}" } qw/DSN USER PASS/};
plan skip_all => 'Set $ENV{DBICTEST_MSSQL_ODBC_DSN}, _USER and _PASS to run this test'
  unless ($dsn && $user);

{
  my $srv_ver = DBICTest::Schema->connect($dsn, $user, $pass)->storage->_server_info->{dbms_version};
  ok ($srv_ver, 'Got a test server version on fresh schema: ' . ($srv_ver||'???') );
}

my $schema;

my %opts = (
  use_mars =>
    { opts => { on_connect_call => 'use_mars' } },
  use_dynamic_cursors =>
    { opts => { on_connect_call => 'use_dynamic_cursors' }, required => 1 },
  use_server_cursors =>
    { opts => { on_connect_call => 'use_server_cursors' } },
  NO_OPTION =>
    { opts => {}, required => 1 },
);

for my $opts_name (keys %opts) {
  SKIP: {
    my $opts = $opts{$opts_name}{opts};
    $schema = DBICTest::Schema->connect($dsn, $user, $pass, $opts);

    try {
      $schema->storage->ensure_connected
    }
    catch {
      if ($opts{$opts_name}{required}) {
        BAIL_OUT "on_connect_call option '$opts_name' is not functional: $_";
      }
      else {
        skip
"on_connect_call option '$opts_name' not functional in this configuration: $_",
1;
      }
    };

# Test populate
    {
      $schema->storage->dbh_do (sub {
        my ($storage, $dbh) = @_;
        eval { $dbh->do("DROP TABLE owners") };
        eval { $dbh->do("DROP TABLE books") };
        $dbh->do(<<'SQL');
CREATE TABLE books (
   id INT IDENTITY (1, 1) NOT NULL,
   source VARCHAR(100),
   owner INT,
   title VARCHAR(10),
   price INT NULL
)

CREATE TABLE owners (
   id INT IDENTITY (1, 1) NOT NULL,
   name VARCHAR(100),
)
SQL
      });

      lives_ok ( sub {
        # start a new connection, make sure rebless works
        my $schema = DBICTest::Schema->connect($dsn, $user, $pass, $opts);
        $schema->populate ('Owners', [
          [qw/id  name  /],
          [qw/1   wiggle/],
          [qw/2   woggle/],
          [qw/3   boggle/],
          [qw/4   fRIOUX/],
          [qw/5   fRUE/],
          [qw/6   fREW/],
          [qw/7   fROOH/],
          [qw/8   fISMBoC/],
          [qw/9   station/],
          [qw/10   mirror/],
          [qw/11   dimly/],
          [qw/12   face_to_face/],
          [qw/13   icarus/],
          [qw/14   dream/],
          [qw/15   dyrstyggyr/],
        ]);
      }, 'populate with PKs supplied ok' );


    }
  }
}

done_testing;

# clean up our mess
END {
  if (my $dbh = eval { $schema->storage->_dbh }) {
    eval { $dbh->do("DROP TABLE $_") }
      for qw/artist artist_guid money_test books owners/;
  }
}
# vim:sw=2 sts=2
