#!/usr/bin/env perl

use warnings;
use strict;
use Module::Build;

my $build=Module::Build->new(
	module_name => 'SuperPhy',
	dist_version => '0.1',
	license => 'perl',
	dist_abstract => 'SuperPhy',
	dist_author => 'Matthew Whiteside, Akiff Manji and Chad Laing',
	requires =>{
		'Module::Build'=>0,
		Carp => 0,
		perl => '5.14.0',
		'CGI::Application'=>0,
		'CGI::Application::Dispatch'=>0,
		'CGI::Application::Plugin::Config::Simple'=>0,
		'CGI::Application::Plugin::Redirect'=>0,
		'CGI::Application::Plugin::Session'=>0,
		'CGI::Application::Plugin::Authentication'=>0,
		'HTML::Template'=>0,
		'Role::Tiny'=>0,
		'Log::Log4perl'=>0,
		'Statistics::R'=>0,
		'Time::HiRes'=>0,
		JSON=>0,
		'Bio::SeqIO'=>0,
		'CGI::Application::Plugin::ValidateRM'=>0,
		'CGI::Application::Plugin::AutoRunmode'=>0,
		'Data::FormValidator::Constraints'=>0,
		'Proc::Daemon'=>0,
		'Data::Dumper'=>0,
		'DateTime'=>0,
		'DateTime::Format::Strptime'=>0,
		'DateTime::Format::Builder'=>0,
		'HTML::FillInForm'=>0,
		'XML::Simple'=>0,
		'Geo::Coder::Google'=>0,
		'Email::Simple'=>0,
		'Email::MIME'=>0,
		'Email::Sender::Simple'=>0,
		'Email::Sender::Transport::SMTP::TLS'=>0,
		'HTML::Template::HashWrapper'=>0,
		'CGI::Application::Plugin::AutoRunmode'=>0,
		'Math::Round'=>0,
		'Digest::MD5'=>0,
		'Geo::Coder::Google'=>0,
		'DBIx::Class::Schema::Loader'=>0,
		'IO::CaptureOutput'=>0,
		'Parallel::ForkManager'=>0,
		'Inline::C'=>0,
		'String::Random'=>0,
<<<<<<< HEAD
		'Switch'=>0,
=======
		Switch=>0,
		'Test::WWW::Mechanize::CGIApp'=>0,
		'DBICx::TestDatabase'=>0,
		'Test::DBIx::Class'=>0,
		'Test::More'=>0,
		'Test::Exception'=>0,
		'Test::Script::Run'=>0,
>>>>>>> master
		'Git::Hook::PostReceive'=>0
	}
);
$build->create_build_script();

