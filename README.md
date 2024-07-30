pr-tracker
==========

Run a web server that displays the path a Nixpkgs pull request will
take through the various release channels..


Usage
-----

This flake exposes a module to get an instance up and running very easily.

See [module](./nix/module.nix) for options.


Development
-----------

The upstream git repository for pr-tracker is available at
<https://git.qyliss.net/pr-tracker/>.

Bugs and patches can be sent to the author,
Alyssa Ross <hi@alyssa.is>.

For information about how to use git to send a patch email, see
<https://git-send-email.io/>.


License
-------

Copyright 2024 Alyssa Ross <hi@alyssa.is>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation; either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program; if not, see
<https://www.gnu.org/licenses>.

Additional permission under GNU AGPL version 3 section 7

If you modify this Program, or any covered work, by linking or
combining it with OpenSSL (or a modified version of that library),
containing parts covered by the terms of the OpenSSL License, or the
Original SSLeay License, the licensors of this Program grant you
additional permission to convey the resulting work.
