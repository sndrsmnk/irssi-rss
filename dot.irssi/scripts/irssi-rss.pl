# (c) 2004 S. Smeenk <ssmeenk@freshdot.net>
# Released under the GPLv2.
#
use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20011201.0100 ();
use Irssi::Irc;
use Irssi::TextUI;
use Digest::MD5 qw(md5_hex);
use URI::Escape;
use Encode qw(encode_utf8);
use Data::Dumper; $Data::Dumper::Indent = 0;

$VERSION = "0.6";
%IRSSI = (
    authors     => 'Sander Smeenk',
    contact     => 'ssmeenk@freshdot.net',
    name        => 'irssi-rss',
    description => 'Reads stored RSS streams and displays newest news!',
    license     => 'GPLv2',
    url         => 'http://www.freshdot.net/irssi.shtml',
);

my $feedsfile = $ENV{'HOME'} . '/.irssi/irssi-rss/rssfeeder.lst';
my $feedstmp  = $ENV{'HOME'} . '/.irssi/irssi-rss/';
my $apafile   = $ENV{'HOME'} . '/.irssi/irssi-rss/apastate.obj';
my $checkfreq = 10;
my $rssobject = {};
my $statehash = {};
my $autopubannounce = {};

sub _parse_rss {
	if (open FD, "<$feedsfile") {
		while (my $feed = <FD>) {
			chomp $feed;
			my ($feedtag, $feedurl) = $feed =~ /^(.+?)\s(.+?)$/;
			my $filename = $feedstmp . "rssfeeder_" . md5_hex($feedurl);

			if (open FI, "<$filename") {
				my $oldslash = $/; local $/ = undef; my $xml = <FI>;
				close FI; local $/ = $oldslash;

				delete $$rssobject{lc($feedtag)} if exists $$rssobject{lc($feedtag)};
				while ($xml =~ /<(?:entry|item)[^>]*>(.*?)<\/(?:entry|item)>/isg) {
					my $item = $1;
					my ($link, $titel);
					if ($item =~ /<title>(.*?)<\/title>/i) {
						$titel = $1;
						$titel =~ s/&#(x[0-9a-fA-F]+|[0-9]+);/chr($1)/eg;
						while ($titel =~ /&amp;/i) { $titel =~ s/&amp;/\&/gi }
						$titel =~ s/\s\s+/ /;

						# Try and find the link. Use permalinks when possible.
						if ($item =~ /<feedburner:origlink>(.*?)<\/feedburner:origlink>/i) {
							$link = $1;
						} elsif ($item =~ /<guid[^>]*>(.*?)<\/guid>/i) {
							$link = $1;
						} elsif ($item =~ /<link[^>]*>(.*?)<\/link>/i) {
							$link = $1;
						} elsif ($item =~ /<link.+?href="([^"]+)"/i) {
							$link = $1;
						}
						while ($link =~ /&amp;/i) { $link =~ s/&amp;/\&/gi }
					}

					if ($link and $titel) {
						push @{$$rssobject{lc($feedtag)}}, [ $link, $titel ];
					}
				}
			}
		}
	} else {
		msg("Error while reading $feedsfile: $!");
	}
}

sub _rss_item_find {
	my ($tag) = @_;
	if (!$tag) { msg("No tag specified. See /rss help for information."); return; }

	# Remember those days... LTRIM() and RTRIM()...
	$tag =~ s/^\s+//g; $tag =~ s/\s+$//g;
	my ($feedtag, $feeditem) = $tag =~ /^(.+?)-(\d+)$/;

	_parse_rss();

	if (not exists $$rssobject{lc($feedtag)}) {
		msg("Unable to find a feed called $feedtag.");
		return;
	}

	my $item_count = scalar($$rssobject{lc($feedtag)});
	if ($feeditem ge $item_count) {
		msg("There are only $item_count items for feed $feedtag.");
		return;
	}
	
	pubannounce($feedtag, $$rssobject{lc($feedtag)}->[$feeditem][0], $$rssobject{lc($feedtag)}->[$feeditem][1]);
}

sub _rss_check {
	my ($show_all, $tag) = @_;
	if (!$show_all) { $show_all = 0 }

	_parse_rss();

	foreach my $feedtag (keys %$rssobject) {
		next if (defined $tag and $tag !~ /$feedtag/i);
		my $item_count = scalar(@{$$rssobject{lc($feedtag)}});
		for (my $itemno = ($item_count - 1); $itemno >= 0; $itemno--) {
			my ($url, $title) = ($$rssobject{lc($feedtag)}->[$itemno][0], $$rssobject{lc($feedtag)}->[$itemno][1]);
			my $rsstag = md5_hex(encode_utf8($url."-".$title));
			if ( (not exists $$statehash{$rsstag}) || ($show_all)) {
				announce($feedtag, $itemno, $url, $title);
				autopubannounce($feedtag, $url, $title);
				$$statehash{$rsstag}++;
			}
		}
	}
	Irssi::timeout_remove($$statehash{'timer'});
	$$statehash{'timer'} = Irssi::timeout_add($checkfreq * 1000, '_rss_check', '');
}

sub _rss_init {
	_parse_rss();

	foreach my $feedtag (keys %$rssobject) {
		my $item_count = scalar(@{$$rssobject{lc($feedtag)}});
		for (my $itemno = ($item_count - 1); $itemno >= 0; $itemno--) {
			my ($url, $title) = ($$rssobject{lc($feedtag)}->[$itemno][0], $$rssobject{lc($feedtag)}->[$itemno][1]);
			my $rsstag = md5_hex(encode_utf8($url."-".$title));
			$$statehash{$rsstag}++;
		}
	}
}

sub _rss_recent {
	my ($amount) = @_;
	if (!$amount) { $amount = 1 }

	_parse_rss;

	msg(" --- Showing recent $amount item(s) on all feeds:");
	foreach my $feedtag (sort keys %$rssobject) {
		for (my $itemno = 0; $itemno < $amount; $itemno++) {
			if (defined $$rssobject{$feedtag}->[$itemno][0]) {
				announce($feedtag, $itemno, $$rssobject{$feedtag}->[$itemno][0], $$rssobject{$feedtag}->[$itemno][1])
			} else {
				msg(" --- No items in feed '$feedtag'.");
			}
		}
	}
}

sub _rss_set_autoannounce {
	my ($feedtag, $channels) = @_;
	$feedtag = lc($feedtag);

	if ($feedtag eq '_list_tags_') {
		my $didweprintsomething = 0;
		foreach my $feed (keys %$autopubannounce) {
			msg("Announcing $feed to " . $$autopubannounce{$feed});
			$didweprintsomething++;
		}
		msg("No public auto-announces set") if (not $didweprintsomething);
		return;
	}

	if ($channels eq 'undef') {
		msg("No longer announcing $feedtag to " . $$autopubannounce{$feedtag});
		delete $$autopubannounce{$feedtag};
		return;
	}

	my @ourfeeds = keys %$rssobject;

	if (not grep(/$feedtag/, @ourfeeds)) {
		msg("No feed found named $feedtag.");
		msg("I got " . join(", ", @ourfeeds) . ".");
		msg("Use exact name.");
		return;
	}

	if ($channels !~ /^#/) {
		msg("Channel names must start with a #.");
		return;
	}

	msg("Announcing $feedtag news to $channels");
	$$autopubannounce{$feedtag} = $channels;
	save_apa();
}

sub filterURL {
	my ($url) = @_;

	# NU.nl
	# http://www.nu.nl/news/1095854/10/rss/Actievoerders_verzetten_wijzers_klokken_Domtoren.html
	# http://www.nu.nl/news/804610/11/rss/CDA_wil_terug_naar_veertigurige_werkweek_(video).html
	if ($url =~ /www.nu.nl/) {
		$url =~ s'/rss/.*$'/rss/rss.html';
		return $url;
	}

	return $url;
}

sub announce {
	my ($feedtag, $itemno, $url, $title) = @_;
	
	return if $title =~ /^(?:ADV:|Advertentie)/;
	return if $title =~ /Advertentie:/;

	$url = filterURL($url);
	
	msg("[$feedtag-$itemno] $title");
	my $string = "";
	$string .= " " x (length("$feedtag-$itemno")+3);
	$string .= uri_unescape($url);
	msg($string);

}

sub pubannounce {
	my ($feedtag, $url, $title) = @_;
	$url = filterURL($url);
	Irssi::active_win()->command("say [$feedtag] $title - $url");
}

sub autopubannounce {
	my ($feedtag, $url, $title) = @_;

	return unless (defined $$autopubannounce{$feedtag});
	return unless ($$autopubannounce{$feedtag} =~ /^#/);

	my @channels = ();
	if ($$autopubannounce{$feedtag} =~ /,/) {
		@channels = split /,/, $$autopubannounce{$feedtag};
	} else {
		push @channels, $$autopubannounce{$feedtag};
	}

	foreach my $channel (@channels) {
		my $chan = Irssi::channel_find($channel);
		next if not $chan; # not found.
		$chan->{server}->command("MSG $channel [$feedtag] $title - $url");
	}
}

sub msg {
	my ($msg, $lvl) = @_;
	if (!$lvl) { $lvl = MSGLEVEL_CRAP }

	foreach my $window (Irssi::windows()) {
		if ($window->{name} eq 'irssi-rss') {
			$window->print($msg, $lvl);
			return;
		}
	}
	
	Irssi::print("$msg", $lvl);
}

sub save_apa {
	if (open (FD, ">$apafile")) {
		print FD Dumper($autopubannounce);
		close(FD);
	} else {
		msg("Failed to write auto-announce data: $!");
	}
}

sub load_apa {
	return unless -e $apafile;
	if (open (FD, "<$apafile")) {
		local $/ = undef;
		my $blob = <FD>;
		close(FD);
		$autopubannounce = eval 'my ' . $blob;
	} else {
		msg("Failed to read auto-announce data: $!");
	}
}


sub cmd_rss {
	my ($text, $server, $witem) = @_;

	if ($text =~ /^help/) {
		msg("Try these:");
		msg("  /rss list [<feedtag>]");
		msg("     Lists all items, optionally limited to only specified feedtag");
		msg("  /rss say <feedtag>-<itemno>");
		msg("     Publically announce the specified item to the current window");
		msg("  /rss recent [<count>]");
		msg("     Show last <count> entries from all feeds. Default to last item.");
		msg("  /rss apa");
		msg("     List current public announcements");
		msg("       /rss apa <feedtag> <channel>[,<channel>] - set auto announce");
		msg("       /rss apa <feedtag> undef - remove auto announces'");
	}

	if ($text) {
		if ($text =~ /^list(.+?)?$/)          { _rss_check('show_all', $1); return }
		if ($text =~ /^say(.+?)?$/)           { _rss_item_find($1); return }
		if ($text =~ /^recent(.+?)?$/)        { _rss_recent($1); return }
		if ($text =~ /^check$/)               { msg("Checking for new RSS items."); _rss_check(); return } 
		if ($text =~ /^reset$/)               { msg("Resetting RSS statehash. All items will be re-announced."); $statehash = {}; return }
		if ($text =~ /^apa$/)                 { _rss_set_autoannounce('_list_tags_'); return }
		if ($text =~ /^apa ([^\s]+)\s(.+?)$/) { _rss_set_autoannounce($1, $2); return }
	}
	msg("Use /rss help for info");
}

Irssi::command_bind('rss' => 'cmd_rss');
$$statehash{'timer'} = Irssi::timeout_add($checkfreq * 1000, '_rss_check', '');

# Initialize the $$statehash so we don't get flooded by new items at
# startup. User can immediately use /rss recent and other functions.
load_apa();
_rss_init();
msg("irssi-rss version $VERSION loaded.");
