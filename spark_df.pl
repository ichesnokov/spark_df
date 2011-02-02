#!/usr/bin/perl
#******************************************************************************#
# Скрипт для получения количества 
#******************************************************************************#
use strict;
use warnings;

# Main work is being done with this module
use WWW::Mechanize;

#******************************************************************************#
# Setting variables
#******************************************************************************#
my $DEBUG       = 0;
my $start_url   = 'https://stat.spark-com.ru/';
my $details_url = 'https://stat.spark-com.ru/account_print_detail/';

my $login = $ENV{SPARK_LOGIN}
    || die "Set your SPARK login - in script or in environment!\n";
my $pass = $ENV{SPARK_PASSWORD}
    || die "Set your SPARK password - in script or in environment!\n";

#******************************************************************************#
# Starting the work
#******************************************************************************#
my $mech = WWW::Mechanize->new();
my $r    = $mech->get($start_url);

# Логинимся
$mech->submit_form(
    #form_name => 'loginForm',
    form_number => 1,
    fields      => {
        login    => $login,
        password => $pass
    },
);

# Переходим на страницу с формой детализации услуг
$mech->get($details_url);

# Заполняем и отправляем форму для получения файла
my ( undef, undef, undef, $mday, $mon, $year ) = localtime;
$mon++;
$year += 1900;

# Doesn't work before 2000 and after 3000
my $today = sprintf( "%02s.%02s.%02s", $mday, $mon, $year - 2000 );
my $firstday = $today;
$firstday =~ s/^\d{2}/01/;

# Submitting form to get details.csv...
my $resp = $mech->submit_form(
    form_number => 1,
    fields      => {
        format     => 'csv',
        start_date => $firstday,
        end_date   => $today
    },
);

my @details   = split /[\r\n]/, $resp->content;
my $sum_day   = 0;
my $sum_night = 0;

#
my $day_start = 8;
my $day_end   = 18;
foreach my $line (@details) {

    my ( $datetime, undef, undef, $type, $traf ) = split /;/, $line;

    # м.б. "Дневной трафик", "Ночной трафик", "Локальный трафик"
    next if
           !defined($type)
        || $type =~ /Локальный/;
    
    next unless $datetime =~ /\d+\.\d+\.\d+ (\d+):\d+/;

    my $hour      = $1;
    my $hour_traf = 0;
    if ( $traf =~ /^(\d+)\.\d+/ ) {
        $hour_traf = $1;
    }
    if ( $hour > $day_start and $hour <= $day_end ) {
        $sum_day += $hour_traf;
    }
    else {
        $sum_night += $hour_traf;
    }
}

printf "+-------------------------------------+\n";
printf "|Statistics from $firstday to $today |\n";
printf "+--------------+----------------------+\n";
printf "|Day traffic:  | %4d Mb (%0.2f Gb)    |\n", $sum_day, $sum_day / 1024;
printf "+--------------+----------------------+\n";
printf "|Night traffic:| %4d Mb (%0.2f Gb)    |\n", $sum_night, $sum_night / 1024;
printf "+--------------+----------------------+\n";
printf "|Total:        | %4d Mb (%0.2f Gb)    |\n", $sum_day + $sum_night, ( $sum_day + $sum_night ) / 1024;
printf "+--------------+----------------------+\n";

#******************************************************************************#
# Ending the work
#******************************************************************************#
