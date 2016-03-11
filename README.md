irssi-rss
=========

This is a little script + daemon to provide RSS streams in irssi. Usage is quite simple, as I will explain below...

This repository consists of the following files:

bin/rssfeeder
-------------
This is the daemon that requests the RSS/XML feeds with some
interval. It will store the data in ~/.irssi/irssi-rss/rssfeeder_<hash>
or irssi-rss.pl to read, parse and display. This little daemon runs in
the background, and by default checks the feeds every five minutes.
Since rssfeeder keeps track of itself, you can put this in cron like so:

    @hourly rssfeeder --cron
    
and it will automatically restart, if it might die for some reason.


.irssi/irssi-rss/rssfeeder.lst
------------------------------
This file contains all the feeds you want to display in irssi. As an
example, slashdot is included. The syntax is fairly simple, a unique
tag, and a direct URL to the RSS feed on a single line is enough. So if
you were to add the Debian Security Advisory RSS feed you'd add the line:

    DSA http://www.debian.org/security/dsa.rdf
    
to this file, and rssfeeder will automatically pick it up after a while.


.irssi/script/irssi-rss.pl
--------------------------
This is the perl script that you will load in irssi to parse the
feeds and maintain a record on what has been announced and what is new
news. By default it checks for new items every 10 seconds.


.irssi/script/autorun/irssi-rss.pl
----------------------------------
This is a symlink, so irssi-rss gets loaded automatically at
startup. You may remove this if you don't want irssi-rss to be loaded at
irssi startup automatically.


Controls within irssi
---------------------

The script binds a new command `/rss` in irssi. You can use this to
review the feeds, or publically announce items you find interessting
enough to share with your IRC friends. By default, `irssi-rss.pl` will
*NOT* announce the news items publically.

A short description of the available options inside irssi:

`/rss list` Will show all news items

`/rss list <feedtag>` Will show all news items for this specific feed-tag.

`/rss reset` Will reset the "statehash". This causes all old items to be announced again, but it will also free the memory claimed by the statehash which, in this version, keeps growing and growing ;)

`/rss say <tag-item#>` Will publically announce the specific news item to the current window. Please ensure yourself that you are announcing the correct item, since positions will change. Newest items are always at the beginning.

`/rss help` Although advertised, will not do anything yet ;)


DEPENDENCIES
------------

rssfeeder, the deamon that retrieves the RSS feeds, depends on:

* `Unix::Syslog`, provided by Debian package libunix-syslog-perl
* `LWP::Simple`, provided by Debian package libwww-perl
* `Digest::MD5`, provided by Debian package perl

irssi-rss.pl, the irssi loadable script, depends on:

* `Digest::MD5`, provided by Debian package perl
* `URI::Escape`, provided by Debian package liburi-perl
* And the modules provided by irssi itself.


ANNOUNCES
---------

By default, news announcements will go to the currently active window.
If you do not like this, you can name a window 'irssi-rss' and this will
cause all announcements to go to that window instead of the current
active window. To select a window for this purpose, go to that specific
window, and type:

	/window name irssi-rss

The next announcements will go to that window, instead of the current
active window.


QUESTIONS, COMMENTS
-------------------

Please direct all questions, comments, improvements and other such
mail to me at the address ssmeenk@freshdot.net.
